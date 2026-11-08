import XCTest
import Testing
@testable import MihomoMac

final class MihomoAPITests: XCTestCase {

    func testRequestBuildsCorrectURL() throws {
        let api = MihomoAPI(
            baseURL: URL(string: "http://127.0.0.1:9090")!,
            secret: "test-secret"
        )
        let request = try api.buildRequest(
            path: "/version",
            method: "GET"
        )
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:9090/version")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer test-secret"
        )
    }

    func testRequestWithoutSecret() throws {
        let api = MihomoAPI(
            baseURL: URL(string: "http://127.0.0.1:9090")!,
            secret: ""
        )
        let request = try api.buildRequest(
            path: "/version",
            method: "GET"
        )
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testRequestWithBody() throws {
        let api = MihomoAPI(
            baseURL: URL(string: "http://127.0.0.1:9090")!,
            secret: ""
        )
        let body = ModeUpdateRequest(mode: "global")
        let request = try api.buildRequest(
            path: "/configs",
            method: "PATCH",
            body: body
        )
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Content-Type"),
            "application/json"
        )
        let decoded = try JSONDecoder().decode(
            ModeUpdateRequest.self,
            from: request.httpBody!
        )
        XCTAssertEqual(decoded.mode, "global")
    }
}

@Suite("Proxy Providers")
struct ProxyProviderTests {
    @Test("Keeps all twelve group members when only one top-level proxy is available")
    func unresolvedMembersRemainVisible() {
        let names = (1...12).map { "Node \($0)" }
        let group = ProxyData(name: "Demo", type: "Fallback", all: names)
        let proxies = [names[0]: ProxyData(name: names[0], type: "WireGuard")]

        let members = group.members(in: proxies)

        #expect(members.map(\.name) == names)
        #expect(members.first?.type == "WireGuard")
        #expect(members.last?.type == "Unknown")
    }

    @Test("Loads the missing members from proxy providers in group order")
    func includesProviderMembers() throws {
        let names = (1...12).map { "Node \($0)" }
        let group = ProxyData(name: "Demo", type: "Fallback", all: names)
        let response = ProxiesResponse(proxies: [
            "Demo": group,
            names[0]: ProxyData(name: names[0], type: "WireGuard"),
        ])
        let json: [String: Any] = ["providers": ["Demo provider": ["proxies": names.dropFirst().map {
            ["name": $0, "type": "Shadowsocks", "history": []] as [String: Any]
        }]]]
        let providers = try JSONDecoder().decode(
            ProxyProvidersResponse.self,
            from: JSONSerialization.data(withJSONObject: json)
        )

        let combined = response.including(providers)

        #expect(response.hasUnresolvedMembers)
        #expect(!combined.hasUnresolvedMembers)
        #expect(group.members(in: combined.proxies).map(\.name) == names)
        #expect(combined.proxies[names[1]]?.providerName == "Demo provider")
    }

    @Test("Keeps top-level proxies when a provider contains the same name")
    func preservesTopLevelProxy() {
        let response = ProxiesResponse(proxies: ["Node": ProxyData(name: "Node", type: "Direct")])
        let providers = ProxyProvidersResponse(providers: [
            "Demo": ProxyProviderData(proxies: [ProxyData(name: "Node", type: "Shadowsocks")]),
        ])

        let proxy = response.including(providers).proxies["Node"]

        #expect(proxy?.type == "Direct")
        #expect(proxy?.providerName == nil)
    }

    @Test("Accepts a provider that has not loaded its proxies yet")
    func emptyProvider() throws {
        let data = Data(#"{"providers":{"Demo":{"proxies":null}}}"#.utf8)
        let providers = try JSONDecoder().decode(ProxyProvidersResponse.self, from: data)

        #expect(ProxiesResponse(proxies: [:]).including(providers).proxies.isEmpty)
    }

    @Test("Chooses the provider deterministically when names overlap")
    func duplicateProviderNames() {
        let providers = ProxyProvidersResponse(providers: [
            "Provider B": ProxyProviderData(proxies: [ProxyData(name: "Node", type: "Trojan")]),
            "Provider A": ProxyProviderData(proxies: [ProxyData(name: "Node", type: "Shadowsocks")]),
        ])

        let proxy = ProxiesResponse(proxies: [:]).including(providers).proxies["Node"]

        #expect(proxy?.providerName == "Provider A")
        #expect(proxy?.type == "Shadowsocks")
    }

    @Test("Tests provider proxies through the provider healthcheck route")
    func providerDelayRequest() throws {
        let api = MihomoAPI(baseURL: URL(string: "http://127.0.0.1:9090")!, secret: "example-secret")

        let request = try api.buildDelayRequest(name: "Node/01", providerName: "Demo/provider")

        #expect(request.url?.absoluteString.hasPrefix(
            "http://127.0.0.1:9090/providers/proxies/Demo%2Fprovider/Node%2F01/healthcheck?"
        ) == true)
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer example-secret")
    }

    @Test("Keeps the regular delay route for top-level proxies")
    func topLevelDelayRequest() throws {
        let api = MihomoAPI(baseURL: URL(string: "http://127.0.0.1:9090")!, secret: "")

        let request = try api.buildDelayRequest(name: "Node")

        #expect(request.url?.absoluteString.hasPrefix("http://127.0.0.1:9090/proxies/Node/delay?") == true)
    }
}
