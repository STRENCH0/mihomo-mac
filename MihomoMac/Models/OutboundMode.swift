import Foundation

enum OutboundMode: String, CaseIterable, Identifiable {
    case direct
    case rule
    case global

    var id: Self { self }
    var title: String { rawValue.capitalized }
}
