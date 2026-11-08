import Foundation

@MainActor
@Observable
final class SystemProxy {
    private(set) var isEnabled: Bool = false
    private(set) var lastError: String?

    private nonisolated static let networksetupPath = "/usr/sbin/networksetup"
    private nonisolated static let relevantKeywords = ["Wi-Fi", "Ethernet", "USB"]

    // MARK: - Public

    func enable(httpPort: Int, socksPort: Int) async {
        do {
            let output = try await run(["-listallnetworkservices"])
            let services = Self.parseNetworkServices(output)
            let commands = Self.proxyEnableCommands(services: services, httpPort: httpPort, socksPort: socksPort)
            for args in commands {
                try await run(args)
            }
            isEnabled = true
            lastError = nil
        } catch {
            let message = "Failed to enable system proxy: \(error.localizedDescription)"
            print("[SystemProxy] \(message)")
            lastError = message
        }
    }

    func disable() async {
        do {
            let output = try await run(["-listallnetworkservices"])
            let services = Self.parseNetworkServices(output)
            let commands = Self.proxyDisableCommands(services: services)
            for args in commands {
                try await run(args)
            }
            isEnabled = false
            lastError = nil
        } catch {
            let message = "Failed to disable system proxy: \(error.localizedDescription)"
            print("[SystemProxy] \(message)")
            lastError = message
        }
    }

    nonisolated func disableSync() {
        do {
            let output = try runSync(["-listallnetworkservices"])
            let services = Self.parseNetworkServices(output)
            let commands = Self.proxyDisableCommands(services: services)
            for args in commands {
                _ = try runSync(args)
            }
        } catch {
            print("[SystemProxy] Failed to disable system proxy (sync): \(error.localizedDescription)")
        }
    }

    // MARK: - Testable Static Helpers

    nonisolated static func parseNetworkServices(_ output: String) -> [String] {
        output
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                guard !line.isEmpty, !line.hasPrefix("*") else { return false }
                // Skip the header line from networksetup
                guard !line.contains("denotes that a network service is disabled") else { return false }
                return relevantKeywords.contains { line.contains($0) }
            }
    }

    nonisolated static func proxyEnableCommands(services: [String], httpPort: Int, socksPort: Int) -> [[String]] {
        var commands: [[String]] = []
        for service in services {
            commands.append(["-setwebproxy", service, "127.0.0.1", "\(httpPort)"])
            commands.append(["-setsecurewebproxy", service, "127.0.0.1", "\(httpPort)"])
            commands.append(["-setwebproxystate", service, "on"])
            commands.append(["-setsecurewebproxystate", service, "on"])
            if socksPort > 0 {
                commands.append(["-setsocksfirewallproxy", service, "127.0.0.1", "\(socksPort)"])
                commands.append(["-setsocksfirewallproxystate", service, "on"])
            }
        }
        return commands
    }

    nonisolated static func proxyDisableCommands(services: [String]) -> [[String]] {
        var commands: [[String]] = []
        for service in services {
            commands.append(["-setwebproxystate", service, "off"])
            commands.append(["-setsecurewebproxystate", service, "off"])
            commands.append(["-setsocksfirewallproxystate", service, "off"])
        }
        return commands
    }

    // MARK: - Private Helpers

    @discardableResult
    private func run(_ arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: Self.networksetupPath)
            process.arguments = arguments

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if process.terminationStatus != 0 {
                    continuation.resume(throwing: SystemProxyError.commandFailed(
                        args: arguments,
                        exitCode: process.terminationStatus,
                        output: output.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                } else {
                    continuation.resume(returning: output)
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    @discardableResult
    private nonisolated func runSync(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Self.networksetupPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw SystemProxyError.commandFailed(
                args: arguments,
                exitCode: process.terminationStatus,
                output: output.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return output
    }
}

private enum SystemProxyError: LocalizedError {
    case commandFailed(args: [String], exitCode: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case let .commandFailed(args, exitCode, output):
            "networksetup \(args.joined(separator: " ")) failed (exit \(exitCode)): \(output)"
        }
    }
}
