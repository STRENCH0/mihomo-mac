import Foundation

struct ProxiesResponse: Codable {
    let proxies: [String: ProxyData]

    var hasUnresolvedMembers: Bool {
        proxies.values.contains { proxy in
            proxy.all?.contains { proxies[$0] == nil } == true
        }
    }

    func including(_ response: ProxyProvidersResponse) -> ProxiesResponse {
        var combined = proxies
        for providerName in response.providers.keys.sorted() {
            for var proxy in response.providers[providerName]?.proxies ?? [] {
                guard !proxy.name.isEmpty, combined[proxy.name] == nil else { continue }
                proxy.providerName = providerName
                combined[proxy.name] = proxy
            }
        }
        return ProxiesResponse(proxies: combined)
    }
}

struct ProxyProvidersResponse: Decodable {
    let providers: [String: ProxyProviderData]
}

struct ProxyProviderData: Decodable {
    let proxies: [ProxyData]?
}

struct ProxyData: Codable, Identifiable {
    var id: String { name }

    let name: String
    let type: String
    let now: String?
    let all: [String]?
    let history: [ProxyHistory]
    let icon: String?
    let udp: Bool?
    let xudp: Bool?
    let hidden: Bool?
    var providerName: String?

    enum CodingKeys: String, CodingKey {
        case name, type, now, all, history, icon, udp, xudp, hidden
    }

    private static let groupTypes: Set<String> = [
        "Selector", "URLTest", "Fallback", "LoadBalance", "Relay",
    ]

    var isGroup: Bool {
        Self.groupTypes.contains(type)
    }

    var isSelectable: Bool {
        type == "Selector" || type == "Fallback"
    }

    var lastDelay: Int? {
        history.last?.delay
    }

    var alive: Bool {
        guard let delay = lastDelay else { return false }
        return delay > 0
    }

    func members(in proxies: [String: ProxyData]) -> [ProxyData] {
        (all ?? []).map { name in
            proxies[name] ?? ProxyData(name: name, type: "Unknown")
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = (try? container.decode(String.self, forKey: .name)) ?? ""
        self.type = try container.decode(String.self, forKey: .type)
        self.now = try container.decodeIfPresent(String.self, forKey: .now)
        self.all = try container.decodeIfPresent([String].self, forKey: .all)
        self.history = (try? container.decode([ProxyHistory].self, forKey: .history)) ?? []
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon)
        self.udp = try container.decodeIfPresent(Bool.self, forKey: .udp)
        self.xudp = try container.decodeIfPresent(Bool.self, forKey: .xudp)
        self.hidden = try container.decodeIfPresent(Bool.self, forKey: .hidden)
        self.providerName = nil
    }

    init(
        name: String,
        type: String,
        now: String? = nil,
        all: [String]? = nil,
        history: [ProxyHistory] = [],
        icon: String? = nil,
        udp: Bool? = nil,
        xudp: Bool? = nil,
        hidden: Bool? = nil,
        providerName: String? = nil
    ) {
        self.name = name
        self.type = type
        self.now = now
        self.all = all
        self.history = history
        self.icon = icon
        self.udp = udp
        self.xudp = xudp
        self.hidden = hidden
        self.providerName = providerName
    }
}

struct ProxyHistory: Codable {
    let time: String
    let delay: Int
}

struct DelayTestResponse: Codable {
    let delay: Int
    let meanDelay: Int?
}

struct SelectProxyRequest: Codable {
    let name: String
}
