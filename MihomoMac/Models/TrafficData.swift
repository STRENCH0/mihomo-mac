import Foundation

struct TrafficSnapshot: Codable, Identifiable {
    var id = UUID()
    let timestamp: Date
    let up: Int64
    let down: Int64

    enum CodingKeys: String, CodingKey {
        case up, down
    }

    init(timestamp: Date = Date(), up: Int64, down: Int64) {
        self.timestamp = timestamp
        self.up = up
        self.down = down
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.up = try container.decode(Int64.self, forKey: .up)
        self.down = try container.decode(Int64.self, forKey: .down)
        self.timestamp = Date()
    }
}

enum TrafficFormatter {
    static func formatBytes(_ bytes: Int64) -> String {
        let absBytes = abs(Double(bytes))
        switch absBytes {
        case 0..<1024:
            return "\(bytes) B/s"
        case 1024..<1_048_576:
            return String(format: "%.1f KB/s", Double(bytes) / 1024)
        case 1_048_576..<1_073_741_824:
            return String(format: "%.2f MB/s", Double(bytes) / 1_048_576)
        default:
            return String(format: "%.2f GB/s", Double(bytes) / 1_073_741_824)
        }
    }

    static func formatTotalBytes(_ bytes: Int64) -> String {
        let absBytes = abs(Double(bytes))
        switch absBytes {
        case 0..<1024:
            return "\(bytes) B"
        case 1024..<1_048_576:
            return String(format: "%.1f KB", Double(bytes) / 1024)
        case 1_048_576..<1_073_741_824:
            return String(format: "%.2f MB", Double(bytes) / 1_048_576)
        default:
            return String(format: "%.2f GB", Double(bytes) / 1_073_741_824)
        }
    }

    static func formatBytesShort(_ bytes: Int64) -> (value: Double, unit: String) {
        let absBytes = abs(Double(bytes))
        switch absBytes {
        case 0..<1024:
            return (Double(bytes), "B/s")
        case 1024..<1_048_576:
            return (Double(bytes) / 1024, "KB/s")
        case 1_048_576..<1_073_741_824:
            return (Double(bytes) / 1_048_576, "MB/s")
        default:
            return (Double(bytes) / 1_073_741_824, "GB/s")
        }
    }
}
