import XCTest
@testable import MihomoMac

final class SystemProxyTests: XCTestCase {

    // MARK: - parseNetworkServices

    func testParseTypicalOutput() {
        let output = """
        An asterisk (*) denotes that a network service is disabled.
        Wi-Fi
        Ethernet
        Bluetooth PAN
        Thunderbolt Bridge
        """
        let services = SystemProxy.parseNetworkServices(output)
        XCTAssertEqual(services, ["Wi-Fi", "Ethernet"])
    }

    func testParseWithDisabledServices() {
        let output = """
        An asterisk (*) denotes that a network service is disabled.
        *Wi-Fi
        Ethernet
        USB 10/100/1000 LAN
        """
        let services = SystemProxy.parseNetworkServices(output)
        XCTAssertEqual(services, ["Ethernet", "USB 10/100/1000 LAN"])
    }

    func testParseEmptyOutput() {
        let services = SystemProxy.parseNetworkServices("")
        XCTAssertTrue(services.isEmpty)
    }

    func testParseNoRelevantServices() {
        let output = """
        An asterisk (*) denotes that a network service is disabled.
        Bluetooth PAN
        Thunderbolt Bridge
        """
        let services = SystemProxy.parseNetworkServices(output)
        XCTAssertTrue(services.isEmpty)
    }

    func testParseWithWhitespace() {
        let output = """
        An asterisk (*) denotes that a network service is disabled.
          Wi-Fi\u{20}\u{20}
          Ethernet\u{20}\u{20}
        """
        let services = SystemProxy.parseNetworkServices(output)
        XCTAssertEqual(services, ["Wi-Fi", "Ethernet"])
    }

    // MARK: - proxyEnableCommands

    func testEnableCommandsWithHTTPAndSOCKS() {
        let commands = SystemProxy.proxyEnableCommands(
            services: ["Wi-Fi"],
            httpPort: 7890,
            socksPort: 7891
        )
        let expected: [[String]] = [
            ["-setwebproxy", "Wi-Fi", "127.0.0.1", "7890"],
            ["-setsecurewebproxy", "Wi-Fi", "127.0.0.1", "7890"],
            ["-setwebproxystate", "Wi-Fi", "on"],
            ["-setsecurewebproxystate", "Wi-Fi", "on"],
            ["-setsocksfirewallproxy", "Wi-Fi", "127.0.0.1", "7891"],
            ["-setsocksfirewallproxystate", "Wi-Fi", "on"],
        ]
        XCTAssertEqual(commands, expected)
    }

    func testEnableCommandsWithoutSOCKS() {
        let commands = SystemProxy.proxyEnableCommands(
            services: ["Wi-Fi"],
            httpPort: 7890,
            socksPort: 0
        )
        let expected: [[String]] = [
            ["-setwebproxy", "Wi-Fi", "127.0.0.1", "7890"],
            ["-setsecurewebproxy", "Wi-Fi", "127.0.0.1", "7890"],
            ["-setwebproxystate", "Wi-Fi", "on"],
            ["-setsecurewebproxystate", "Wi-Fi", "on"],
        ]
        XCTAssertEqual(commands, expected)
    }

    func testEnableCommandsMultipleServices() {
        let commands = SystemProxy.proxyEnableCommands(
            services: ["Wi-Fi", "Ethernet"],
            httpPort: 7890,
            socksPort: 0
        )
        XCTAssertEqual(commands.count, 8) // 4 commands per service
        XCTAssertEqual(commands[0][1], "Wi-Fi")
        XCTAssertEqual(commands[4][1], "Ethernet")
    }

    func testEnableCommandsNoServices() {
        let commands = SystemProxy.proxyEnableCommands(
            services: [],
            httpPort: 7890,
            socksPort: 7891
        )
        XCTAssertTrue(commands.isEmpty)
    }

    // MARK: - proxyDisableCommands

    func testDisableCommands() {
        let commands = SystemProxy.proxyDisableCommands(services: ["Wi-Fi"])
        let expected: [[String]] = [
            ["-setwebproxystate", "Wi-Fi", "off"],
            ["-setsecurewebproxystate", "Wi-Fi", "off"],
            ["-setsocksfirewallproxystate", "Wi-Fi", "off"],
        ]
        XCTAssertEqual(commands, expected)
    }

    func testDisableCommandsMultipleServices() {
        let commands = SystemProxy.proxyDisableCommands(services: ["Wi-Fi", "Ethernet"])
        XCTAssertEqual(commands.count, 6) // 3 commands per service
    }

    func testDisableCommandsNoServices() {
        let commands = SystemProxy.proxyDisableCommands(services: [])
        XCTAssertTrue(commands.isEmpty)
    }

    // MARK: - Port selection logic

    func testMixedPortTakesPriority() {
        let config = MihomoConfig(
            externalController: "127.0.0.1:9090",
            secret: "",
            mixedPort: 7890,
            port: 8080,
            socksPort: 1080,
            mode: "rule"
        )
        let httpPort = config.mixedPort > 0 ? config.mixedPort : config.port
        let socksPort = config.mixedPort > 0 ? config.mixedPort : config.socksPort
        XCTAssertEqual(httpPort, 7890)
        XCTAssertEqual(socksPort, 7890)
    }

    func testFallbackToIndividualPorts() {
        let config = MihomoConfig(
            externalController: "127.0.0.1:9090",
            secret: "",
            mixedPort: 0,
            port: 8080,
            socksPort: 1080,
            mode: "rule"
        )
        let httpPort = config.mixedPort > 0 ? config.mixedPort : config.port
        let socksPort = config.mixedPort > 0 ? config.mixedPort : config.socksPort
        XCTAssertEqual(httpPort, 8080)
        XCTAssertEqual(socksPort, 1080)
    }
}
