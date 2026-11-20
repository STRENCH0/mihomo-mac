import Foundation
import Observation

@Observable
final class AppConfig {
    private let defaults: UserDefaults
    private enum Keys {
        static let mihomoPath = "mihomoPath"
        static let legacyConfigPath = "configPath"
        static let wifiRulesEnabled = "wifiRulesEnabled"
        static let wifiProxyRules = "wifiProxyRules"
        static let otherWiFiProxyState = "otherWiFiProxyState"
    }

    var mihomoPath: String {
        didSet { defaults.set(mihomoPath, forKey: Keys.mihomoPath) }
    }

    var wifiRulesEnabled: Bool {
        didSet { defaults.set(wifiRulesEnabled, forKey: Keys.wifiRulesEnabled) }
    }

    var wifiProxyRules: [String: Bool] {
        didSet { defaults.set(wifiProxyRules, forKey: Keys.wifiProxyRules) }
    }

    var otherWiFiProxyState: Bool? {
        didSet { defaults.set(otherWiFiProxyState, forKey: Keys.otherWiFiProxyState) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mihomoPath = defaults.string(forKey: Keys.mihomoPath) ?? ""
        wifiRulesEnabled = defaults.bool(forKey: Keys.wifiRulesEnabled)
        wifiProxyRules = defaults.dictionary(forKey: Keys.wifiProxyRules) as? [String: Bool] ?? [:]
        otherWiFiProxyState = defaults.object(forKey: Keys.otherWiFiProxyState) as? Bool
    }

    func wifiProxyState(for ssid: String?) -> Bool? {
        guard wifiRulesEnabled, let ssid, !ssid.isEmpty else { return nil }
        return wifiProxyRules[ssid] ?? otherWiFiProxyState
    }

    var mihomoURL: URL? {
        mihomoPath.isEmpty ? nil : URL(fileURLWithPath: mihomoPath)
    }

    var isConfigured: Bool {
        mihomoURL != nil
    }

    // MARK: - Migration

    /// Copies the legacy config file to `configsDir/migrated.yaml`.
    /// Returns the destination URL on success, nil if the source file is missing or unreadable.
    /// Callers must clear the UserDefaults key separately after calling this.
    static func migrateConfigPath(legacyPath: String, configsDir: URL) -> URL? {
        guard !legacyPath.isEmpty,
              FileManager.default.fileExists(atPath: legacyPath) else {
            return nil
        }
        let destination = configsDir.appendingPathComponent("migrated.yaml")
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(
                at: URL(fileURLWithPath: legacyPath),
                to: destination
            )
            return destination
        } catch {
            print("[AppConfig] Migration copy failed: \(error)")
            return nil
        }
    }

    static var legacyConfigPath: String? {
        UserDefaults.standard.string(forKey: Keys.legacyConfigPath)
    }

    static func clearLegacyConfigPath() {
        UserDefaults.standard.removeObject(forKey: Keys.legacyConfigPath)
    }
}
