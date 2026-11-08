import AppKit
import SwiftUI
import Combine

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem
    private let appState: AppState
    private let openDashboard: () -> Void

    init(appState: AppState, openDashboard: @escaping () -> Void) {
        self.appState = appState
        self.openDashboard = openDashboard
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = statusBarIcon(filled: false)
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func updateIcon() {
        statusItem.button?.image = statusBarIcon(filled: appState.systemProxy.isEnabled)
    }

    private func statusBarIcon(filled: Bool) -> NSImage? {
        let name = filled ? "StatusBarCatFilled" : "StatusBarCatOutline"
        guard let image = NSImage(named: name) else { return nil }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }

    // MARK: - NSMenuDelegate

    nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
        MainActor.assumeIsolated {
            rebuildMenu(menu)
        }
    }

    // MARK: - Menu Building

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let isRunning = appState.mihomoProcess.status == .running

        // Header
        addHeaderItem(to: menu, isRunning: isRunning)
        menu.addItem(.separator())

        // Start / Stop
        let startStop = NSMenuItem(
            title: isRunning ? "Stop Mihomo" : "Start Mihomo",
            action: #selector(toggleProcess),
            keyEquivalent: ""
        )
        startStop.target = self
        startStop.image = NSImage(systemSymbolName: isRunning ? "stop.fill" : "play.fill", accessibilityDescription: nil)
        startStop.isEnabled = appState.appConfig.isConfigured || isRunning
        menu.addItem(startStop)

        if isRunning {
            menu.addItem(.separator())

            // Traffic
            addTrafficItem(to: menu)
            menu.addItem(.separator())

            // System Proxy
            let proxyItem = NSMenuItem(
                title: "System Proxy",
                action: #selector(toggleSystemProxy),
                keyEquivalent: ""
            )
            proxyItem.target = self
            proxyItem.state = appState.systemProxy.isEnabled ? .on : .off
            proxyItem.image = NSImage(systemSymbolName: "network", accessibilityDescription: nil)
            menu.addItem(proxyItem)

            // Copy Proxy Export
            let copyExportItem = NSMenuItem(
                title: "Copy Proxy Export",
                action: #selector(copyProxyExport),
                keyEquivalent: ""
            )
            copyExportItem.target = self
            copyExportItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
            copyExportItem.isEnabled = appState.proxyHTTPPort > 0
            menu.addItem(copyExportItem)

            // Outbound Mode
            let modeMenu = NSMenu()
            for mode in OutboundMode.allCases {
                let modeItem = NSMenuItem(
                    title: mode.title,
                    action: #selector(selectMode(_:)),
                    keyEquivalent: ""
                )
                modeItem.target = self
                modeItem.representedObject = mode.rawValue
                modeItem.state = appState.selectedOutboundMode == mode ? .on : .off
                modeMenu.addItem(modeItem)
            }
            let modeParent = NSMenuItem(
                title: "Outbound Mode",
                action: nil,
                keyEquivalent: ""
            )
            modeParent.submenu = modeMenu
            modeParent.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: nil)
            menu.addItem(modeParent)

            // Config switcher
            addConfigMenuItem(to: menu)

            // Proxy Groups
            if !appState.proxyGroups.isEmpty {
                menu.addItem(.separator())
                for group in appState.proxyGroups {
                    addProxyGroupItem(to: menu, group: group)
                }
            }
        }

        menu.addItem(.separator())

        // Open Dashboard
        let dashboard = NSMenuItem(
            title: "Open Dashboard...",
            action: #selector(openDashboardAction),
            keyEquivalent: "D"
        )
        dashboard.keyEquivalentModifierMask = [.command, .shift]
        dashboard.target = self
        menu.addItem(dashboard)

        // Quit
        let quit = NSMenuItem(
            title: "Quit Mihomo",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - Header

    private func addHeaderItem(to menu: NSMenu, isRunning: Bool) {
        let item = NSMenuItem()
        let headerView = NSHostingView(rootView: StatusBarHeaderView(
            statusText: statusText,
            statusColor: statusColor,
            version: appState.mihomoVersion
        ))
        headerView.frame = NSRect(x: 0, y: 0, width: 280, height: 36)
        item.view = headerView
        menu.addItem(item)
    }

    // MARK: - Traffic

    private func addTrafficItem(to menu: NSMenu) {
        let item = NSMenuItem()
        let up = TrafficFormatter.formatBytes(appState.webSocket?.currentUp ?? 0)
        let down = TrafficFormatter.formatBytes(appState.webSocket?.currentDown ?? 0)
        let trafficView = NSHostingView(rootView: StatusBarTrafficView(upText: up, downText: down))
        trafficView.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        item.view = trafficView
        menu.addItem(item)
    }

    // MARK: - Proxy Groups

    private func addProxyGroupItem(to menu: NSMenu, group: ProxyData) {
        let submenu = NSMenu()

        // Speed Test
        let speedTest = NSMenuItem(
            title: "Speed Test",
            action: #selector(speedTestGroup(_:)),
            keyEquivalent: ""
        )
        speedTest.target = self
        speedTest.representedObject = group.name
        speedTest.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)
        submenu.addItem(speedTest)
        submenu.addItem(.separator())

        // Members
        let members = group.all ?? []
        for member in members.prefix(30) {
            let memberItem = NSMenuItem()
            let isCurrent = member == group.now
            let delay = appState.proxyDelays[member]

            let memberView = ClickableMenuItemView(
                rootView: ProxyMemberView(
                    name: member,
                    isCurrent: isCurrent,
                    delay: delay
                ),
                frame: NSRect(x: 0, y: 0, width: 260, height: 22)
            )
            memberItem.view = memberView
            memberItem.representedObject = ProxySelection(group: group.name, member: member)
            memberItem.target = self
            memberItem.action = #selector(selectProxy(_:))
            submenu.addItem(memberItem)
        }

        if members.count > 30 {
            submenu.addItem(.separator())
            let showAll = NSMenuItem(
                title: "Show All in Dashboard...",
                action: #selector(openDashboardAction),
                keyEquivalent: ""
            )
            showAll.target = self
            submenu.addItem(showAll)
        }

        let groupItem = NSMenuItem(title: group.name, action: nil, keyEquivalent: "")
        groupItem.submenu = submenu
        groupItem.image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)

        // Load custom icon from URL if available
        if let iconURLString = group.icon, let iconURL = URL(string: iconURLString) {
            loadIcon(from: iconURL) { image in
                groupItem.image = image
            }
        }

        // Show current selection as attributed title
        let title = NSMutableAttributedString(string: "\(group.name)")
        title.append(NSAttributedString(
            string: "  \(group.now ?? "—")",
            attributes: [.foregroundColor: NSColor.secondaryLabelColor]
        ))
        groupItem.attributedTitle = title

        menu.addItem(groupItem)
    }

    // MARK: - Config Menu

    private func addConfigMenuItem(to menu: NSMenu) {
        let configMenu = NSMenu()
        let profiles = appState.configManager.profiles
        let activeID = appState.configManager.activeProfileID

        for profile in profiles {
            let item = NSMenuItem(
                title: profile.name,
                action: #selector(selectConfig(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = profile.id.uuidString
            item.state = profile.id == activeID ? .on : .off
            configMenu.addItem(item)
        }

        let activeProfileName = profiles.first(where: { $0.id == activeID })?.name ?? "—"
        let parent = NSMenuItem(title: "Config: \(activeProfileName)", action: nil, keyEquivalent: "")
        parent.submenu = configMenu
        parent.image = NSImage(systemSymbolName: "doc.badge.gearshape", accessibilityDescription: nil)
        menu.addItem(parent)
    }

    // MARK: - Actions

    @objc private func toggleProcess() {
        if appState.mihomoProcess.status == .running {
            appState.stopMihomo()
        } else {
            appState.startMihomo()
        }
    }

    @objc private func toggleSystemProxy() {
        let enabled = !appState.systemProxy.isEnabled
        Task { await appState.setSystemProxyEnabled(enabled) }
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = OutboundMode(rawValue: raw) else { return }
        Task { try? await appState.setOutboundMode(mode) }
    }

    @objc private func selectProxy(_ sender: NSMenuItem) {
        guard let selection = sender.representedObject as? ProxySelection else { return }
        Task { try? await appState.selectProxy(group: selection.group, name: selection.member) }
    }

    @objc private func speedTestGroup(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        Task { await appState.testGroupDelays(groupName: name) }
    }

    @objc private func selectConfig(_ sender: NSMenuItem) {
        guard let uuidString = sender.representedObject as? String,
              let id = UUID(uuidString: uuidString) else { return }
        appState.configManager.setActive(id: id)
    }

    @objc private func copyProxyExport() {
        let httpPort = appState.proxyHTTPPort
        let socksPort = appState.proxySocksPort

        guard httpPort > 0 || socksPort > 0 else { return }

        var exports: [String] = []

        if httpPort > 0 {
            let httpProxy = "http://127.0.0.1:\(httpPort)"
            exports.append("export http_proxy=\(httpProxy)")
            exports.append("export https_proxy=\(httpProxy)")
            exports.append("export HTTP_PROXY=\(httpProxy)")
            exports.append("export HTTPS_PROXY=\(httpProxy)")
        }

        if socksPort > 0 {
            let socksProxy = "socks5://127.0.0.1:\(socksPort)"
            exports.append("export all_proxy=\(socksProxy)")
            exports.append("export ALL_PROXY=\(socksProxy)")
        }

        let exportString = exports.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(exportString, forType: .string)
    }

    @objc private func openDashboardAction() {
        openDashboard()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Helpers

    // MARK: - Icon Loading

    private static var iconCache: [URL: NSImage] = [:]

    private func loadIcon(from url: URL, completion: @escaping (NSImage) -> Void) {
        if let cached = Self.iconCache[url] {
            completion(cached)
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = NSImage(data: data) else { return }
            let sized = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
                image.draw(in: rect)
                return true
            }
            DispatchQueue.main.async {
                Self.iconCache[url] = sized
                completion(sized)
            }
        }.resume()
    }

    private var statusText: String {
        switch appState.mihomoProcess.status {
        case .running: "Running"
        case .starting: "Starting..."
        case .stopped: "Stopped"
        case .error: "Error"
        case .failed: "Failed"
        }
    }

    private var statusColor: NSColor {
        switch appState.mihomoProcess.status {
        case .running: .systemGreen
        case .starting: .systemOrange
        case .stopped: .systemGray
        case .error, .failed: .systemRed
        }
    }
}

// MARK: - Helper types

private struct ProxySelection {
    let group: String
    let member: String
}

private final class ClickableMenuItemView: NSView {
    private let hostingView: NSView
    private var trackingArea: NSTrackingArea?
    private var isHighlighted = false {
        didSet { needsDisplay = true }
    }

    init(rootView: some View, frame: NSRect) {
        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        hosting.autoresizingMask = [.width, .height]
        self.hostingView = hosting
        super.init(frame: frame)
        addSubview(hosting)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self
        )
        addTrackingArea(trackingArea!)
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHighlighted {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill()
        }
    }

    override func mouseEntered(with event: NSEvent) {
        isHighlighted = true
    }

    override func mouseExited(with event: NSEvent) {
        isHighlighted = false
    }

    override func mouseUp(with event: NSEvent) {
        guard let menuItem = enclosingMenuItem,
              let action = menuItem.action,
              let target = menuItem.target else { return }
        NSApp.sendAction(action, to: target, from: menuItem)
        menuItem.menu?.cancelTracking()
    }
}

// MARK: - SwiftUI Views for NSHostingView

private struct StatusBarHeaderView: View {
    let statusText: String
    let statusColor: NSColor
    let version: String?

    var body: some View {
        HStack(spacing: 8) {
            Image("StatusBarCatFilled")
                .resizable()
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text("Mihomo")
                    .font(.system(.body, weight: .semibold))
                if let version {
                    Text(version)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(nsColor: statusColor))
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }
}

private struct StatusBarTrafficView: View {
    let upText: String
    let downText: String

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .foregroundStyle(.blue)
                Text(upText)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "arrow.down")
                    .foregroundStyle(.green)
                Text(downText)
            }
        }
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
    }
}

private struct ProxyMemberView: View {
    let name: String
    let isCurrent: Bool
    let delay: Int?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.caption2.weight(.bold))
                .opacity(isCurrent ? 1 : 0)
                .frame(width: 12)

            Text(name)
                .lineLimit(1)

            Spacer()

            if let delay {
                if delay == 0 {
                    Text("Timeout")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.red.opacity(0.2))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                } else {
                    Text("\(delay) ms")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(delayColor.opacity(0.2))
                        .foregroundStyle(delayColor)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 1)
    }

    private var delayColor: Color {
        guard let delay, delay > 0 else { return .red }
        if delay < 100 { return .green }
        if delay < 300 { return .yellow }
        return .orange
    }
}
