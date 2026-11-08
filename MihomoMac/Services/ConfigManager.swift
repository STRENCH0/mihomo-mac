import Foundation
import Yams

@Observable
@MainActor
final class ConfigManager {

    // MARK: - Public state

    private(set) var profiles: [ConfigProfile] = []
    private(set) var activeProfileID: UUID = UUID()

    // MARK: - Callbacks

    var onActiveProfileChanged: ((UUID) -> Void)?

    // MARK: - Paths

    var configsDirURL: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("MihomoMac/configs/mihomo", isDirectory: true)
    }

    private var metadataURL: URL {
        configsDirURL.appendingPathComponent("metadata.json")
    }

    var activeProfile: ConfigProfile? {
        profiles.first { $0.id == activeProfileID }
    }

    var activeConfigFileURL: URL {
        guard let profile = activeProfile else {
            return configsDirURL.appendingPathComponent("default.yaml")
        }
        return configsDirURL.appendingPathComponent(profile.filename)
    }

    // MARK: - Lifecycle

    func loadProfiles() {
        do {
            try FileManager.default.createDirectory(
                at: configsDirURL,
                withIntermediateDirectories: true
            )
        } catch {
            print("[ConfigManager] Failed to create configs dir: \(error)")
        }

        if let data = try? Data(contentsOf: metadataURL),
           let loaded = try? JSONDecoder().decode([ConfigProfile].self, from: data),
           !loaded.isEmpty {
            profiles = loaded
            let savedID = UserDefaults.standard.string(forKey: "activeProfileID")
                .flatMap { UUID(uuidString: $0) }
            if let id = savedID, profiles.contains(where: { $0.id == id }) {
                activeProfileID = id
            } else {
                activeProfileID = profiles[0].id
            }
        } else {
            createDefaultProfile()
        }
    }

    // MARK: - CRUD

    func createProfile(name: String) throws -> ConfigProfile {
        guard !profiles.contains(where: { $0.name == name }) else {
            throw ConfigError.nameAlreadyExists(name: name)
        }
        let existingFilenames = profiles.map(\.filename)
        let filename = Self.generateFilename(from: name, existing: existingFilenames)
        let now = Date()
        let profile = ConfigProfile(id: UUID(), name: name, filename: filename, createdAt: now, updatedAt: now)
        let fileURL = configsDirURL.appendingPathComponent(filename)
        do {
            try Self.defaultConfigContent.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw ConfigError.fileWriteError(path: fileURL.path, underlying: error)
        }
        profiles.append(profile)
        do {
            try saveMetadata()
        } catch {
            profiles.removeLast()
            throw error
        }
        return profile
    }

    func deleteProfile(id: UUID) throws {
        guard profiles.count > 1 else {
            throw ConfigError.lastProfileCannotBeDeleted
        }
        guard let index = profiles.firstIndex(where: { $0.id == id }) else {
            throw ConfigError.profileNotFound(id: id)
        }
        let profile = profiles[index]
        let fileURL = configsDirURL.appendingPathComponent(profile.filename)
        try? FileManager.default.removeItem(at: fileURL)
        profiles.remove(at: index)
        if activeProfileID == id {
            activeProfileID = profiles[0].id
            persistActiveProfileID()
            onActiveProfileChanged?(activeProfileID)
        }
        try saveMetadata()
    }

    func renameProfile(id: UUID, newName: String) throws {
        guard !profiles.contains(where: { $0.name == newName && $0.id != id }) else {
            throw ConfigError.nameAlreadyExists(name: newName)
        }
        guard let index = profiles.firstIndex(where: { $0.id == id }) else {
            throw ConfigError.profileNotFound(id: id)
        }
        profiles[index].name = newName
        profiles[index].updatedAt = Date()
        try saveMetadata()
    }

    func duplicateProfile(id: UUID, newName: String) throws -> ConfigProfile {
        guard profiles.contains(where: { $0.id == id }) else {
            throw ConfigError.profileNotFound(id: id)
        }
        guard !profiles.contains(where: { $0.name == newName }) else {
            throw ConfigError.nameAlreadyExists(name: newName)
        }
        let content = try readContent(id: id)
        let existingFilenames = profiles.map(\.filename)
        let filename = Self.generateFilename(from: newName, existing: existingFilenames)
        let now = Date()
        let newProfile = ConfigProfile(id: UUID(), name: newName, filename: filename, createdAt: now, updatedAt: now)
        let fileURL = configsDirURL.appendingPathComponent(filename)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw ConfigError.fileWriteError(path: fileURL.path, underlying: error)
        }
        profiles.append(newProfile)
        do {
            try saveMetadata()
        } catch {
            profiles.removeLast()
            throw error
        }
        return newProfile
    }

    // MARK: - Content

    func readContent(id: UUID) throws -> String {
        guard let profile = profiles.first(where: { $0.id == id }) else {
            throw ConfigError.profileNotFound(id: id)
        }
        let fileURL = configsDirURL.appendingPathComponent(profile.filename)
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw ConfigError.fileReadError(path: fileURL.path, underlying: error)
        }
    }

    func saveContent(id: UUID, content: String) throws {
        try validateContent(content)
        guard let index = profiles.firstIndex(where: { $0.id == id }) else {
            throw ConfigError.profileNotFound(id: id)
        }
        let fileURL = configsDirURL.appendingPathComponent(profiles[index].filename)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw ConfigError.fileWriteError(path: fileURL.path, underlying: error)
        }
        profiles[index].updatedAt = Date()
        try saveMetadata()
    }

    // MARK: - Active profile

    func setActive(id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeProfileID = id
        persistActiveProfileID()
        onActiveProfileChanged?(id)
    }

    // MARK: - Static helpers

    nonisolated static func generateFilename(from name: String, existing: [String]) -> String {
        let base = name
            .lowercased()
            .components(separatedBy: .whitespaces)
            .joined(separator: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
            .joined()
        let stem = base.isEmpty ? "unnamed" : base
        var candidate = "\(stem).yaml"
        var counter = 2
        while existing.contains(candidate) {
            candidate = "\(stem)-\(counter).yaml"
            counter += 1
        }
        return candidate
    }

    static let defaultConfigContent: String = {
        var lines: [String] = []
        lines.append("mixed-port: 7890")
        lines.append(#"external-controller: "0.0.0.0:9090""#)
        return lines.joined(separator: "\n")
    }()

    // MARK: - Private

    private func createDefaultProfile() {
        let now = Date()
        let profile = ConfigProfile(
            id: UUID(),
            name: "default",
            filename: "default.yaml",
            createdAt: now,
            updatedAt: now
        )
        let fileURL = configsDirURL.appendingPathComponent("default.yaml")
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? Self.defaultConfigContent.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        profiles = [profile]
        activeProfileID = profile.id
        persistActiveProfileID()
        try? saveMetadata()
    }

    private func saveMetadata() throws {
        do {
            let data = try JSONEncoder().encode(profiles)
            try data.write(to: metadataURL, options: .atomic)
        } catch {
            throw ConfigError.fileWriteError(path: metadataURL.path, underlying: error)
        }
    }

    private func persistActiveProfileID() {
        UserDefaults.standard.set(activeProfileID.uuidString, forKey: "activeProfileID")
    }

    func validateContent(_ content: String) throws {
        let parsed: Any?
        do {
            parsed = try Yams.load(yaml: content)
        } catch {
            throw ConfigError.invalidYAML(description: error.localizedDescription)
        }
        let dict = parsed as? [String: Any] ?? [:]
        let externalController = dict["external-controller"] as? String ?? ""
        if externalController.isEmpty {
            throw ConfigError.missingExternalController
        }
    }
}
