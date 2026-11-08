import Foundation
import Network

@MainActor
@Observable
final class NetworkMonitor {
    var internetLatency: Int?
    var dnsLatency: Int?
    var routerLatency: Int?
    var isProbing = false

    private var refreshTask: Task<Void, Never>?

    func start() {
        refresh()
        startAutoRefresh()
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        internetLatency = nil
        dnsLatency = nil
        routerLatency = nil
    }

    func refresh() {
        Task {
            isProbing = true
            async let internet = probeInternetLatency()
            async let dns = probeDNSLatency()
            async let router = probeRouterLatency()

            internetLatency = await internet
            dnsLatency = await dns
            routerLatency = await router
            isProbing = false
        }
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { break }
                refresh()
            }
        }
    }

    // MARK: - Latency probes

    private func probeInternetLatency() async -> Int? {
        await measureHTTPLatency(urlString: "http://cp.cloudflare.com/generate_204")
    }

    private func probeDNSLatency() async -> Int? {
        let start = CFAbsoluteTimeGetCurrent()
        let host = CFHostCreateWithName(nil, "google.com" as CFString).takeRetainedValue()
        CFHostStartInfoResolution(host, .addresses, nil)
        var resolved = DarwinBoolean(false)
        _ = CFHostGetAddressing(host, &resolved)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        return resolved.boolValue ? Int(elapsed * 1000) : nil
    }

    private func probeRouterLatency() async -> Int? {
        guard let gateway = getDefaultGateway() else { return nil }
        return await measureHTTPLatency(urlString: "http://\(gateway)", timeout: 3)
    }

    private func measureHTTPLatency(urlString: String, timeout: TimeInterval = 10) async -> Int? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            if let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) {
                return Int(elapsed * 1000)
            }
            return nil
        } catch {
            return nil
        }
    }

    private func getDefaultGateway() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        task.arguments = ["-rn"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            if parts.count >= 2 && parts[0] == "default" {
                let gw = String(parts[1])
                if gw.contains(".") { return gw }
            }
        }
        return nil
    }
}
