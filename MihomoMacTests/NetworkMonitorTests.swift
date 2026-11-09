import Testing
import Foundation
@testable import MihomoMac

@Suite("DNS latency probe")
@MainActor
struct DNSLatencyProbeTests {
    @Test("Resolves a local address")
    func resolvesLocalAddress() async {
        let latency = await DNSLatencyProbe.measure(hostname: "127.0.0.1")

        #expect(latency != nil)
        #expect((latency ?? -1) >= 0)
    }

    @Test("Finishes within the DNS timeout")
    func finishesWithinTimeout() async {
        let clock = ContinuousClock()
        let start = clock.now

        let latency = await DNSLatencyProbe.measure(
            hostname: "\(UUID().uuidString).invalid.",
            timeout: .milliseconds(20)
        )

        #expect(latency == nil)
        #expect(start.duration(to: clock.now) < .seconds(2))
    }

    @Test("Cancellation finishes a pending probe")
    func cancelsPendingProbe() async {
        let clock = ContinuousClock()
        let start = clock.now
        let probe = Task {
            await DNSLatencyProbe.measure(hostname: "\(UUID().uuidString).invalid.", timeout: .seconds(30))
        }
        try? await Task.sleep(for: .milliseconds(10))

        probe.cancel()
        let latency = await probe.value

        #expect(latency == nil)
        #expect(start.duration(to: clock.now) < .seconds(2))
    }

    @Test("An already cancelled probe returns no latency")
    func skipsCancelledProbe() async {
        let probe = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await DNSLatencyProbe.measure(hostname: "127.0.0.1")
        }

        let latency = await probe.value

        #expect(latency == nil)
    }
}

@Suite("Network monitor")
@MainActor
struct NetworkMonitorTests {
    @Test("Stopping clears state and cancels a queued refresh")
    func stopsQueuedRefresh() async {
        let monitor = NetworkMonitor()
        monitor.internetLatency = 10
        monitor.dnsLatency = 20
        monitor.routerLatency = 30
        monitor.refresh()
        #expect(monitor.isProbing)

        monitor.stop()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(!monitor.isProbing)
        #expect(monitor.internetLatency == nil)
        #expect(monitor.dnsLatency == nil)
        #expect(monitor.routerLatency == nil)
    }
}
