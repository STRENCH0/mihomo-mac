import Testing
import Foundation
@testable import MihomoMac

@Suite("TrafficSnapshot")
struct TrafficSnapshotTests {
    @Test("Decodes from mihomo JSON")
    func decodesFromJSON() throws {
        let json = #"{"up": 12345, "down": 67890}"#
        let data = json.data(using: .utf8)!
        let snapshot = try JSONDecoder().decode(TrafficSnapshot.self, from: data)

        #expect(snapshot.up == 12345)
        #expect(snapshot.down == 67890)
    }

    @Test("Decodes zero traffic")
    func decodesZeroTraffic() throws {
        let json = #"{"up": 0, "down": 0}"#
        let data = json.data(using: .utf8)!
        let snapshot = try JSONDecoder().decode(TrafficSnapshot.self, from: data)

        #expect(snapshot.up == 0)
        #expect(snapshot.down == 0)
    }

    @Test("Sets timestamp on decode")
    func setsTimestampOnDecode() throws {
        let before = Date()
        let json = #"{"up": 100, "down": 200}"#
        let data = json.data(using: .utf8)!
        let snapshot = try JSONDecoder().decode(TrafficSnapshot.self, from: data)
        let after = Date()

        #expect(snapshot.timestamp >= before)
        #expect(snapshot.timestamp <= after)
    }

    @Test("Each decoded snapshot has unique ID")
    func uniqueIDs() throws {
        let json = #"{"up": 1, "down": 2}"#
        let data = json.data(using: .utf8)!
        let s1 = try JSONDecoder().decode(TrafficSnapshot.self, from: data)
        let s2 = try JSONDecoder().decode(TrafficSnapshot.self, from: data)

        #expect(s1.id != s2.id)
    }
}

@Suite("TrafficFormatter")
struct TrafficFormatterTests {
    @Test("Formats zero bytes")
    func formatsZero() {
        #expect(TrafficFormatter.formatBytes(0) == "0 B/s")
    }

    @Test("Formats bytes")
    func formatsBytes() {
        #expect(TrafficFormatter.formatBytes(500) == "500 B/s")
        #expect(TrafficFormatter.formatBytes(1023) == "1023 B/s")
    }

    @Test("Formats kilobytes")
    func formatsKB() {
        #expect(TrafficFormatter.formatBytes(1024) == "1.0 KB/s")
        #expect(TrafficFormatter.formatBytes(1536) == "1.5 KB/s")
        #expect(TrafficFormatter.formatBytes(10240) == "10.0 KB/s")
    }

    @Test("Formats megabytes")
    func formatsMB() {
        #expect(TrafficFormatter.formatBytes(1_048_576) == "1.00 MB/s")
        #expect(TrafficFormatter.formatBytes(5_242_880) == "5.00 MB/s")
    }

    @Test("Formats gigabytes")
    func formatsGB() {
        #expect(TrafficFormatter.formatBytes(1_073_741_824) == "1.00 GB/s")
    }

    @Test("formatBytesShort returns correct unit")
    func formatBytesShort() {
        let (value, unit) = TrafficFormatter.formatBytesShort(1_048_576)
        #expect(value == 1.0)
        #expect(unit == "MB/s")
    }
}
