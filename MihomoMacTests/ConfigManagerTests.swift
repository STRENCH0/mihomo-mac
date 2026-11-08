import Testing
import Foundation
@testable import MihomoMac

@Suite("ConfigProfile")
struct ConfigProfileTests {

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let id = UUID()
        let created = Date(timeIntervalSince1970: 1000)
        let updated = Date(timeIntervalSince1970: 2000)
        let profile = ConfigProfile(
            id: id,
            name: "Work Proxy",
            filename: "work-proxy.yaml",
            createdAt: created,
            updatedAt: updated
        )
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(ConfigProfile.self, from: data)
        #expect(decoded.id == id)
        #expect(decoded.name == "Work Proxy")
        #expect(decoded.filename == "work-proxy.yaml")
        #expect(decoded.createdAt == created)
        #expect(decoded.updatedAt == updated)
    }
}

@Suite("ConfigManager filename generation")
struct ConfigManagerFilenameTests {

    @Test("Simple name lowercased with dashes")
    func simpleNameToFilename() {
        let name = ConfigManager.generateFilename(from: "My Config", existing: [])
        #expect(name == "my-config.yaml")
    }

    @Test("Non-ASCII and special chars stripped")
    func specialCharsStripped() {
        let name = ConfigManager.generateFilename(from: "Work Proxy!", existing: [])
        #expect(name == "work-proxy.yaml")
    }

    @Test("Collision adds numeric suffix")
    func collisionAddsNumericSuffix() {
        let name = ConfigManager.generateFilename(
            from: "Work Proxy",
            existing: ["work-proxy.yaml"]
        )
        #expect(name == "work-proxy-2.yaml")
    }

    @Test("Multiple collisions increment suffix")
    func multipleCollisionsIncrement() {
        let name = ConfigManager.generateFilename(
            from: "Work Proxy",
            existing: ["work-proxy.yaml", "work-proxy-2.yaml"]
        )
        #expect(name == "work-proxy-3.yaml")
    }

    @Test("Empty or all-stripped name falls back to unnamed")
    func emptyNameFallback() {
        let name = ConfigManager.generateFilename(from: "!@#", existing: [])
        #expect(name == "unnamed.yaml")
    }
}

@Suite("ConfigManager validation")
@MainActor
struct ConfigManagerValidationTests {

    @Test("Valid YAML with external-controller passes validateContent")
    func validYAMLPasses() throws {
        let manager = ConfigManager()
        let yaml = "mixed-port: 7890\nexternal-controller: \"127.0.0.1:9090\"\n"
        try manager.validateContent(yaml)
    }

    @Test("YAML missing external-controller throws missingExternalController")
    func missingExternalControllerThrows() throws {
        let manager = ConfigManager()
        let yaml = "mixed-port: 7890\n"
        #expect {
            try manager.validateContent(yaml)
        } throws: { error in
            if case ConfigError.missingExternalController = error { return true }
            return false
        }
    }

    @Test("Invalid YAML throws invalidYAML")
    func invalidYAMLThrows() throws {
        let manager = ConfigManager()
        let yaml = "{{not valid yaml"
        #expect {
            try manager.validateContent(yaml)
        } throws: { error in
            if case ConfigError.invalidYAML = error { return true }
            return false
        }
    }

    @Test("ConfigError descriptions are non-empty")
    func errorDescriptionsNonEmpty() {
        let errors: [ConfigError] = [
            .invalidYAML(description: "bad"),
            .missingExternalController,
            .lastProfileCannotBeDeleted,
            .profileNotFound(id: UUID()),
            .fileReadError(path: "/tmp/x", underlying: NSError(domain: "test", code: 1)),
            .fileWriteError(path: "/tmp/x", underlying: NSError(domain: "test", code: 1)),
            .nameAlreadyExists(name: "foo"),
        ]
        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }
}
