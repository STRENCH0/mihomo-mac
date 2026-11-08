import Foundation

struct VersionResponse: Codable {
    let meta: Bool?
    let premium: Bool?
    let version: String
}

struct ConfigsResponse: Codable {
    let port: Int?
    let socksPort: Int?
    let mixedPort: Int?
    let mode: String?
    let logLevel: String?

    enum CodingKeys: String, CodingKey {
        case port
        case socksPort = "socks-port"
        case mixedPort = "mixed-port"
        case mode
        case logLevel = "log-level"
    }
}

struct ModeUpdateRequest: Codable {
    let mode: String
}
