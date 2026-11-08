import Foundation
import Observation

@Observable
final class AppConfig {
    private static let defaults = UserDefaults.standard
    private enum Keys {
        static let mihomoPath = "mihomoPath"
        static let legacyConfigPath = "configPath"
    }

    var mihomoPath: String {
        didSet { Self.defaults.set(mihomoPath, forKey: Keys.mihomoPath) }
    }

    init() {
        self.mihomoPath = Self.defaults.string(forKey: Keys.mihomoPath) ?? ""
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
        defaults.string(forKey: Keys.legacyConfigPath)
    }

    static func clearLegacyConfigPath() {
        defaults.removeObject(forKey: Keys.legacyConfigPath)
    }
}
