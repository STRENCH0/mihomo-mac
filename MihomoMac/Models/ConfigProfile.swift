import Foundation

struct ConfigProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var filename: String
    let createdAt: Date
    var updatedAt: Date
}

enum ConfigError: LocalizedError {
    case invalidYAML(description: String)
    case missingExternalController
    case lastProfileCannotBeDeleted
    case profileNotFound(id: UUID)
    case fileReadError(path: String, underlying: Error)
    case fileWriteError(path: String, underlying: Error)
    case nameAlreadyExists(name: String)

    var errorDescription: String? {
        switch self {
        case .invalidYAML(let description):
            return "Invalid YAML: \(description)"
        case .missingExternalController:
            return "Config must contain a non-empty 'external-controller' field"
        case .lastProfileCannotBeDeleted:
            return "Cannot delete the last config profile"
        case .profileNotFound(let id):
            return "Config profile not found: \(id)"
        case .fileReadError(let path, let underlying):
            return "Cannot read file '\(path)': \(underlying.localizedDescription)"
        case .fileWriteError(let path, let underlying):
            return "Cannot write file '\(path)': \(underlying.localizedDescription)"
        case .nameAlreadyExists(let name):
            return "A config named '\(name)' already exists"
        }
    }
}
