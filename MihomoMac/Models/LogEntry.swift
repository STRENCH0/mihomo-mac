import Foundation
import SwiftUI

struct LogEntry: Codable, Identifiable {
    let id: UUID
    let type: String
    let payload: String
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case type, payload
    }

    init(type: String, payload: String) {
        self.id = UUID()
        self.type = type
        self.payload = payload
        self.timestamp = Date()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.payload = try container.decode(String.self, forKey: .payload)
        self.id = UUID()
        self.timestamp = Date()
    }

    var levelColor: Color {
        switch type {
        case "error": .red
        case "warning": .orange
        case "info": .blue
        case "debug": .secondary
        default: .primary
        }
    }
}

enum LogLevel: String, CaseIterable, Identifiable {
    case debug, info, warning, error

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}
