import Testing
import Foundation
@testable import MihomoMac

@Suite("AppConfig migration")
struct AppConfigMigrationTests {

    @Test("migrateConfigPath copies existing file to migrated.yaml")
    func migratesCopiesFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sourceFile = tempDir.appendingPathComponent("old-config.yaml")
        let content = "mixed-port: 7890\nexternal-controller: \"127.0.0.1:9090\"\n"
        try content.write(to: sourceFile, atomically: true, encoding: .utf8)

        let destDir = tempDir.appendingPathComponent("configs")
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let result = AppConfig.migrateConfigPath(
            legacyPath: sourceFile.path,
            configsDir: destDir
        )

        #expect(result != nil)
        let destFile = destDir.appendingPathComponent("migrated.yaml")
        #expect(FileManager.default.fileExists(atPath: destFile.path))
        let read = try String(contentsOf: destFile, encoding: .utf8)
        #expect(read == content)
    }

    @Test("migrateConfigPath returns nil when file missing")
    func returnsNilWhenFileMissing() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let result = AppConfig.migrateConfigPath(
            legacyPath: "/nonexistent/path.yaml",
            configsDir: tempDir
        )
        #expect(result == nil)
    }
}
