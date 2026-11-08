import Foundation

final class MihomoAPI: Sendable {
    let baseURL: URL
    let secret: String
    private let session: URLSession

    init(baseURL: URL, secret: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.secret = secret
        self.session = session
    }

    func buildRequest<T: Encodable>(
        path: String,
        method: String,
        body: T
    ) throws -> URLRequest {
        var request = try buildRequest(path: path, method: method)
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    func buildRequest(
        path: String,
        method: String
    ) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw MihomoAPIError.invalidURL(path)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if !secret.isEmpty {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // MARK: - REST endpoints

    func getVersion() async throws -> VersionResponse {
        try await get("/version")
    }

    func getConfigs() async throws -> ConfigsResponse {
        try await get("/configs")
    }

    func patchMode(_ mode: String) async throws {
        let body = ModeUpdateRequest(mode: mode)
        let request = try buildRequest(path: "/configs", method: "PATCH", body: body)
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    func closeAllConnections() async throws {
        let request = try buildRequest(path: "/connections", method: "DELETE")
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    func closeConnection(id: String) async throws {
        let request = try buildRequest(path: "/connections/\(id)", method: "DELETE")
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Proxies

    func getProxies() async throws -> ProxiesResponse {
        let response: ProxiesResponse = try await get("/proxies")
        guard response.hasUnresolvedMembers else { return response }
        do {
            let providers: ProxyProvidersResponse = try await get("/providers/proxies")
            return response.including(providers)
        } catch {
            print("[MihomoAPI] Failed to load proxy providers: \(error.localizedDescription)")
            return response
        }
    }

    func selectProxy(group: String, name: String) async throws {
        guard let encodedGroup = group.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw MihomoAPIError.invalidURL("/proxies/\(group)")
        }
        let body = SelectProxyRequest(name: name)
        let request = try buildRequest(path: "/proxies/\(encodedGroup)", method: "PUT", body: body)
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    func testDelay(
        name: String,
        providerName: String? = nil,
        url: String = "http://cp.cloudflare.com/generate_204",
        timeout: Int = 10000
    ) async throws -> DelayTestResponse {
        let request = try buildDelayRequest(name: name, providerName: providerName, url: url, timeout: timeout)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(DelayTestResponse.self, from: data)
    }

    func buildDelayRequest(
        name: String,
        providerName: String? = nil,
        url: String = "http://cp.cloudflare.com/generate_204",
        timeout: Int = 10000
    ) throws -> URLRequest {
        let pathCharacters = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
        guard let encodedName = name.addingPercentEncoding(withAllowedCharacters: pathCharacters),
              let encodedURL = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw MihomoAPIError.invalidURL("/proxies/\(name)/delay")
        }
        let path: String
        if let providerName {
            guard let encodedProvider = providerName.addingPercentEncoding(withAllowedCharacters: pathCharacters) else {
                throw MihomoAPIError.invalidURL("/providers/proxies/\(providerName)")
            }
            path = "/providers/proxies/\(encodedProvider)/\(encodedName)/healthcheck"
        } else {
            path = "/proxies/\(encodedName)/delay"
        }
        return try buildRequest(path: "\(path)?timeout=\(timeout)&url=\(encodedURL)", method: "GET")
    }

    // MARK: - Private helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try buildRequest(path: path, method: "GET")
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw MihomoAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw MihomoAPIError.httpError(http.statusCode)
        }
    }
}

enum MihomoAPIError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let path):
            return "Invalid API URL: \(path)"
        case .invalidResponse:
            return "Invalid response from mihomo API"
        case .httpError(let code):
            return "HTTP error \(code)"
        }
    }
}
