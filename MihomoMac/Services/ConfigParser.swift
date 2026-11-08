import Foundation
import Yams

enum ConfigParserError: LocalizedError {
    case invalidYAML(String)
    case fileReadError(String)

    var errorDescription: String? {
        switch self {
        case .invalidYAML(let detail):
            return "Invalid YAML: \(detail)"
        case .fileReadError(let detail):
            return "Cannot read config file: \(detail)"
        }
    }
}

enum ConfigParser {

    static func parse(fileURL: URL) throws -> MihomoConfig {
        let content: String
        do {
            content = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw ConfigParserError.fileReadError(error.localizedDescription)
        }
        return try parse(yaml: content)
    }

    static func parse(yaml: String) throws -> MihomoConfig {
        let dict: [String: Any]
        do {
            let parsed = try Yams.load(yaml: yaml)
            dict = parsed as? [String: Any] ?? [:]
        } catch {
            throw ConfigParserError.invalidYAML(error.localizedDescription)
        }

        return MihomoConfig(
            externalController: dict["external-controller"] as? String
                ?? MihomoConfig.defaultExternalController,
            secret: dict["secret"] as? String ?? "",
            mixedPort: dict["mixed-port"] as? Int
                ?? MihomoConfig.defaultMixedPort,
            port: dict["port"] as? Int ?? 0,
            socksPort: dict["socks-port"] as? Int ?? 0,
            mode: dict["mode"] as? String ?? "rule"
        )
    }
}
