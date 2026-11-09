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
    private var probeTask: Task<Void, Never>?

    func start() {
        refresh()
        startAutoRefresh()
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        probeTask?.cancel()
        probeTask = nil
        isProbing = false
        internetLatency = nil
        dnsLatency = nil
        routerLatency = nil
    }

    func refresh() {
        guard !isProbing else { return }
        isProbing = true
        probeTask = Task {
            guard !Task.isCancelled else { return }
            async let internet = Self.probeInternetLatency()
            async let dns = DNSLatencyProbe.measure(hostname: "google.com")
            async let router = Self.probeRouterLatency()

            let latencies = await (internet, dns, router)
            guard !Task.isCancelled else { return }
            internetLatency = latencies.0
            dnsLatency = latencies.1
            routerLatency = latencies.2
            isProbing = false
            probeTask = nil
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

    private nonisolated static func probeInternetLatency() async -> Int? {
        await measureHTTPLatency(urlString: "http://cp.cloudflare.com/generate_204")
    }

    private nonisolated static func probeRouterLatency() async -> Int? {
        guard let gateway = getDefaultGateway() else { return nil }
        return await measureHTTPLatency(urlString: "http://\(gateway)", timeout: 3)
    }

    private nonisolated static func measureHTTPLatency(urlString: String, timeout: TimeInterval = 10) async -> Int? {
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

    private nonisolated static func getDefaultGateway() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        task.arguments = ["-rn"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return nil }
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

@MainActor
@Observable
final class DNSLatencyProbe {
    private let host: CFHost
    private let timeout: Duration
    private var continuation: CheckedContinuation<Int?, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var startedAt = CFAbsoluteTimeGetCurrent()

    private init(hostname: String, timeout: Duration) {
        host = CFHostCreateWithName(nil, hostname as CFString).takeRetainedValue()
        self.timeout = timeout
    }

    static func measure(hostname: String, timeout: Duration = .seconds(5)) async -> Int? {
        guard !Task.isCancelled, timeout > .zero else { return nil }
        let probe = DNSLatencyProbe(hostname: hostname, timeout: timeout)
        return await probe.resolve()
    }

    private func resolve() async -> Int? {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(returning: nil)
                    return
                }
                self.continuation = continuation
                startedAt = CFAbsoluteTimeGetCurrent()
                var context = CFHostClientContext(
                    version: 0,
                    info: Unmanaged.passUnretained(self).toOpaque(),
                    retain: nil,
                    release: nil,
                    copyDescription: nil
                )
                let hasClient = CFHostSetClient(host, { host, _, error, info in
                    guard let info else { return }
                    let probe = Unmanaged<DNSLatencyProbe>.fromOpaque(info).takeUnretainedValue()
                    MainActor.assumeIsolated {
                        var resolved = DarwinBoolean(false)
                        let addresses = CFHostGetAddressing(host, &resolved)?.takeUnretainedValue()
                        let hasAddresses = addresses.map { CFArrayGetCount($0) > 0 } ?? false
                        probe.finish(isResolved: (error?.pointee.error ?? 0) == 0 && resolved.boolValue && hasAddresses)
                    }
                }, &context)
                guard hasClient else {
                    finish()
                    return
                }
                CFHostScheduleWithRunLoop(host, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
                guard CFHostStartInfoResolution(host, .addresses, nil) else {
                    finish()
                    return
                }
                timeoutTask = Task {
                    do {
                        try await Task.sleep(for: timeout)
                        finish()
                    } catch {}
                }
            }
        } onCancel: {
            Task { @MainActor in
                self.finish()
            }
        }
    }

    private func finish(isResolved: Bool = false) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        CFHostSetClient(host, nil, nil)
        CFHostCancelInfoResolution(host, .addresses)
        CFHostUnscheduleFromRunLoop(host, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let latency = isResolved ? Int((CFAbsoluteTimeGetCurrent() - startedAt) * 1000) : nil
        continuation.resume(returning: latency)
    }
}
