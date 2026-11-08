import Foundation

struct MihomoConfig {
    let externalController: String
    let secret: String
    let mixedPort: Int
    let port: Int
    let socksPort: Int
    let mode: String

    static let defaultExternalController = "127.0.0.1:9090"
    static let defaultMixedPort = 7890

    var apiBaseURL: URL? {
        let host = externalController.replacingOccurrences(of: "0.0.0.0", with: "127.0.0.1")
        return URL(string: "http://\(host)")
    }
}
