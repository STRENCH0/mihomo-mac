import XCTest
@testable import MihomoMac

final class ConfigParserTests: XCTestCase {

    func testParseValidConfig() throws {
        let yaml = """
        external-controller: 127.0.0.1:9090
        secret: test-secret
        mixed-port: 7890
        port: 7891
        socks-port: 7892
        mode: rule
        """
        let config = try ConfigParser.parse(yaml: yaml)
        XCTAssertEqual(config.externalController, "127.0.0.1:9090")
        XCTAssertEqual(config.secret, "test-secret")
        XCTAssertEqual(config.mixedPort, 7890)
        XCTAssertEqual(config.port, 7891)
        XCTAssertEqual(config.socksPort, 7892)
        XCTAssertEqual(config.mode, "rule")
    }

    func testParseMinimalConfig() throws {
        let yaml = """
        mixed-port: 7890
        """
        let config = try ConfigParser.parse(yaml: yaml)
        XCTAssertEqual(config.externalController, "127.0.0.1:9090")
        XCTAssertEqual(config.secret, "")
        XCTAssertEqual(config.mixedPort, 7890)
        XCTAssertEqual(config.mode, "rule")
    }

    func testParseEmptyConfig() throws {
        let yaml = ""
        let config = try ConfigParser.parse(yaml: yaml)
        XCTAssertEqual(config.externalController, "127.0.0.1:9090")
        XCTAssertEqual(config.mixedPort, 7890)
    }

    func testParseInvalidYAML() {
        let yaml = "{{invalid yaml"
        XCTAssertThrowsError(try ConfigParser.parse(yaml: yaml)) { error in
            XCTAssertTrue(error is ConfigParserError)
        }
    }

    func testParseFileURL() throws {
        let yaml = """
        external-controller: 0.0.0.0:9090
        secret: my-secret
        mixed-port: 1234
        mode: global
        """
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-config.yaml")
        try yaml.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let config = try ConfigParser.parse(fileURL: tempURL)
        XCTAssertEqual(config.externalController, "0.0.0.0:9090")
        XCTAssertEqual(config.secret, "my-secret")
        XCTAssertEqual(config.mixedPort, 1234)
        XCTAssertEqual(config.mode, "global")
    }
}
