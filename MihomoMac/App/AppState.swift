import Foundation
import SwiftUI
import ServiceManagement

@MainActor
@Observable
final class AppState {
    let appConfig = AppConfig()
    let configManager = ConfigManager()
    var mihomoConfig: MihomoConfig?
    var configStatus: ConfigStatus = .idle
    let mihomoProcess = MihomoProcess()
    let systemProxy = SystemProxy()
    let wifiMonitor = WiFiMonitor()
    private var pendingProxyState: Bool?
    private var proxyChangeTask: Task<Void, Never>?
    var mihomoAPI: MihomoAPI?
    var webSocket: MihomoWebSocket?
    var mihomoVersion: String?
    var currentMode: String?
    var processStartTime: Date?
    var proxyGroups: [ProxyData] = []
    var allProxies: [String: ProxyData] = [:]
    var proxyDelays: [String: Int] = [:]
    let networkMonitor = NetworkMonitor()
    private(set) var launchAtLoginStatus = SMAppService.mainApp.status
    private(set) var launchAtLoginError: String?

    init() {
        // Ensure configs dir exists before migration so the copy target is valid
        let configsDir = configManager.configsDirURL
        try? FileManager.default.createDirectory(at: configsDir, withIntermediateDirectories: true)

        runMigrationIfNeeded()
        configManager.loadProfiles()
        configManager.onActiveProfileChanged = { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.switchConfig()
            }
        }
        wifiMonitor.onSSIDChanged = { [weak self] ssid in
            self?.applyWiFiRule(for: ssid)
        }
        mihomoProcess.onRunningChanged = { [weak self] running in
            guard let self else { return }
            if running {
                wifiMonitor.refreshForKernelStart()
            } else if systemProxy.isEnabled || proxyChangeTask != nil || systemProxy.lastError != nil {
                queueProxyChange(false)
            }
        }
        if appConfig.wifiRulesEnabled {
            wifiMonitor.start()
        }
    }

    var proxyHTTPPort: Int {
        guard let config = mihomoConfig else { return 0 }
        return config.mixedPort > 0 ? config.mixedPort : config.port
    }

    var proxySocksPort: Int {
        guard let config = mihomoConfig else { return 0 }
        return config.mixedPort > 0 ? config.mixedPort : config.socksPort
    }

    var selectedOutboundMode: OutboundMode? {
        currentMode.flatMap(OutboundMode.init(rawValue:))
    }

    var canControlSystemProxy: Bool {
        mihomoProcess.isRunning && proxyHTTPPort > 0
    }

    var canToggleSystemProxy: Bool {
        mihomoProcess.isRunning
    }

    var isConfigured: Bool {
        appConfig.mihomoURL != nil && configManager.activeProfile != nil
    }

    var isLaunchAtLoginEnabled: Bool {
        launchAtLoginStatus == .enabled || launchAtLoginStatus == .requiresApproval
    }

    var launchAtLoginRequiresApproval: Bool {
        launchAtLoginStatus == .requiresApproval
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginStatus = SMAppService.mainApp.status
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        refreshLaunchAtLoginStatus()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func setOutboundMode(_ mode: OutboundMode) async throws {
        try await changeMode(mode.rawValue)
    }

    func setSystemProxyEnabled(_ enabled: Bool) async {
        guard !enabled || mihomoProcess.canEnableProxy else { return }
        await queueProxyChange(enabled).value
    }

    @discardableResult
    private func queueProxyChange(_ enabled: Bool) -> Task<Void, Never> {
        pendingProxyState = enabled
        if let proxyChangeTask { return proxyChangeTask }
        let task = Task {
            while let next = pendingProxyState {
                pendingProxyState = nil
                if next {
                    await systemProxy.enable(httpPort: proxyHTTPPort, socksPort: proxySocksPort)
                } else {
                    await systemProxy.disable()
                }
            }
            proxyChangeTask = nil
        }
        proxyChangeTask = task
        return task
    }

    var statusMenuSnapshot: StatusMenuSnapshot {
        StatusMenuSnapshot.build(
            processStatus: mihomoProcess.status,
            version: mihomoVersion,
            selectedMode: selectedOutboundMode,
            systemProxyEnabled: systemProxy.isEnabled,
            upText: TrafficFormatter.formatBytes(webSocket?.currentUp ?? 0),
            downText: TrafficFormatter.formatBytes(webSocket?.currentDown ?? 0),
            proxyGroups: proxyGroups,
            configProfiles: configManager.profiles,
            activeConfigID: configManager.activeProfileID
        )
    }

    // MARK: - Wi-Fi rules

    func setWiFiRulesEnabled(_ enabled: Bool) {
        appConfig.wifiRulesEnabled = enabled
        if enabled {
            wifiMonitor.start()
        } else {
            wifiMonitor.stop()
        }
    }

    func setWiFiRule(for ssid: String, enabled: Bool?) {
        guard !ssid.isEmpty, ssid.utf8.count <= 32 else { return }
        appConfig.wifiProxyRules[ssid] = enabled
        if ssid == wifiMonitor.ssid { applyWiFiRule(for: ssid) }
    }

    func setOtherWiFiProxyState(_ enabled: Bool?) {
        appConfig.otherWiFiProxyState = enabled
        if let ssid = wifiMonitor.ssid, appConfig.wifiProxyRules[ssid] == nil {
            applyWiFiRule(for: ssid)
        }
    }

    private func applyWiFiRule(for ssid: String?) {
        guard mihomoProcess.canEnableProxy, let enabled = appConfig.wifiProxyState(for: ssid),
              !enabled || canControlSystemProxy else { return }
        queueProxyChange(enabled)
    }

    // MARK: - Config

    func loadConfig() {
        let configURL = configManager.activeConfigFileURL

        do {
            let config = try ConfigParser.parse(fileURL: configURL)
            mihomoConfig = config
            configStatus = .loaded
            guard let apiBaseURL = config.apiBaseURL else {
                configStatus = .error("Invalid API base URL from config")
                return
            }

            let needsRecreate = mihomoAPI?.baseURL != apiBaseURL ||
                                mihomoAPI?.secret != config.secret
            if needsRecreate {
                webSocket?.disconnect()
                mihomoAPI = MihomoAPI(baseURL: apiBaseURL, secret: config.secret)
                webSocket = MihomoWebSocket(baseURL: apiBaseURL, secret: config.secret)
            }
        } catch {
            mihomoConfig = nil
            configStatus = .error(error.localizedDescription)
            mihomoAPI = nil
            webSocket = nil
        }
    }

    // MARK: - Process

    func startMihomo() {
        guard let mihomoURL = appConfig.mihomoURL else {
            mihomoProcess.status = .error("Mihomo binary path not set")
            return
        }

        if configStatus != .loaded {
            loadConfig()
        }

        guard case .loaded = configStatus else {
            mihomoProcess.status = .error("Config not loaded")
            return
        }

        mihomoProcess.start(
            executableURL: mihomoURL,
            configFileURL: configManager.activeConfigFileURL,
            configDirURL: configManager.configsDirURL
        )
        Task {
            await waitForAPI()
        }
    }

    func stopMihomo() {
        webSocket?.disconnect()
        networkMonitor.stop()
        mihomoProcess.stop()
        mihomoVersion = nil
        currentMode = nil
        processStartTime = nil
        proxyGroups = []
        allProxies = [:]
        proxyDelays = [:]
    }

    // MARK: - Config switching

    func switchConfig() async {
        let wasRunning = mihomoProcess.isRunning
        if wasRunning {
            stopMihomo()
            // Brief pause so process terminates cleanly
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        loadConfig()
        if wasRunning {
            startMihomo()
        }
    }

    // MARK: - Mode

    func changeMode(_ mode: String) async throws {
        try await mihomoAPI?.patchMode(mode)
        currentMode = mode
    }

    // MARK: - Connections

    func closeAllConnections() async throws {
        try await mihomoAPI?.closeAllConnections()
    }

    func closeConnection(id: String) async throws {
        try await mihomoAPI?.closeConnection(id: id)
    }

    // MARK: - Proxies

    func fetchProxies() async {
        guard let api = mihomoAPI else { return }
        do {
            let response = try await api.getProxies()
            var proxiesMap: [String: ProxyData] = [:]
            for (key, data) in response.proxies {
                proxiesMap[key] = ProxyData(
                    name: key,
                    type: data.type,
                    now: data.now,
                    all: data.all,
                    history: data.history,
                    icon: data.icon,
                    udp: data.udp,
                    xudp: data.xudp,
                    hidden: data.hidden,
                    providerName: data.providerName
                )
            }
            allProxies = proxiesMap

            let globalAll = proxiesMap["GLOBAL"]?.all ?? []
            let orderedGroups: [ProxyData] = globalAll.compactMap { name in
                guard let proxy = proxiesMap[name],
                      proxy.isGroup,
                      proxy.hidden != true,
                      name != "GLOBAL" else { return nil }
                return proxy
            }
            proxyGroups = orderedGroups.isEmpty
                ? proxiesMap.values.filter { $0.isGroup && $0.hidden != true && $0.name != "GLOBAL" }
                    .sorted { $0.name < $1.name }
                : orderedGroups

            for (name, proxy) in proxiesMap {
                if let delay = proxy.lastDelay {
                    proxyDelays[name] = delay
                }
            }
        } catch {
            // Silently fail — proxies are non-critical
        }
    }

    func selectProxy(group: String, name: String) async throws {
        try await mihomoAPI?.selectProxy(group: group, name: name)
        await fetchProxies()
    }

    func testDelay(name: String) async {
        guard let api = mihomoAPI else { return }
        do {
            let response = try await api.testDelay(name: name, providerName: allProxies[name]?.providerName)
            proxyDelays[name] = response.delay
        } catch {
            print("[testDelay] \(name): \(error)")
            proxyDelays[name] = 0
        }
    }

    func testGroupDelays(groupName: String) async {
        guard let group = allProxies[groupName],
              let members = group.all else { return }
        await withTaskGroup(of: Void.self) { taskGroup in
            for member in members {
                guard let proxy = allProxies[member], !proxy.isGroup else { continue }
                taskGroup.addTask { @MainActor in
                    await self.testDelay(name: member)
                }
            }
        }
    }

    // MARK: - API polling

    private func waitForAPI() async {
        guard let api = mihomoAPI else { return }

        for _ in 0..<10 {
            if !mihomoProcess.isRunning {
                let lastOutput = mihomoProcess.processOutput.suffix(5).joined(separator: "\n")
                let detail = lastOutput.isEmpty ? "no output" : lastOutput
                mihomoProcess.status = .error("Process terminated before API became available.\n\(detail)")
                return
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000)
            do {
                let version = try await api.getVersion()
                self.mihomoVersion = version.version
                self.mihomoProcess.status = .running
                if let configs = try? await api.getConfigs() {
                    self.currentMode = configs.mode
                }
                self.processStartTime = Date()
                self.webSocket?.connectTraffic()
                self.webSocket?.connectConnections()
                self.webSocket?.connectMemory()
                self.webSocket?.connectLogs()
                await self.fetchProxies()
                self.networkMonitor.start()
                return
            } catch {
                continue
            }
        }

        if !mihomoProcess.isRunning {
            let lastOutput = mihomoProcess.processOutput.suffix(5).joined(separator: "\n")
            let detail = lastOutput.isEmpty ? "no output" : lastOutput
            mihomoProcess.status = .error("Process terminated before API became available.\n\(detail)")
        } else {
            mihomoProcess.status = .error("mihomo API not reachable after 10s")
        }
    }

    // MARK: - Migration

    private func runMigrationIfNeeded() {
        guard let legacyPath = AppConfig.legacyConfigPath, !legacyPath.isEmpty else { return }

        let configsDir = configManager.configsDirURL
        let migratedURL = AppConfig.migrateConfigPath(
            legacyPath: legacyPath,
            configsDir: configsDir
        )
        AppConfig.clearLegacyConfigPath()

        if migratedURL != nil {
            // Register the migrated file as a profile so loadProfiles() picks it up.
            // Write a metadata.json with a single "migrated" profile pointing to migrated.yaml.
            let now = Date()
            let profile = ConfigProfile(
                id: UUID(),
                name: "migrated",
                filename: "migrated.yaml",
                createdAt: now,
                updatedAt: now
            )
            let metadataURL = configsDir.appendingPathComponent("metadata.json")
            if let data = try? JSONEncoder().encode([profile]) {
                try? data.write(to: metadataURL, options: .atomic)
                // Also persist the active profile ID so it's selected after loadProfiles()
                UserDefaults.standard.set(profile.id.uuidString, forKey: "activeProfileID")
            }
            print("[AppState] Migration: imported '\(legacyPath)' as 'migrated' profile")
        } else {
            print("[AppState] Migration: could not copy legacy config at '\(legacyPath)'")
        }
    }
}
