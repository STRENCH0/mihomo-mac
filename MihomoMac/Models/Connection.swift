import Foundation

struct ConnectionsSnapshot: Codable {
    let downloadTotal: Int64
    let uploadTotal: Int64
    let connections: [Connection]?
}

struct MemorySnapshot: Codable {
    let inuse: Int64
    let oslimit: Int64?
}

struct Connection: Codable, Identifiable {
    let id: String
    let metadata: ConnectionMetadata
    let upload: Int64
    let download: Int64
    let start: Date
    let chains: [String]
    let rule: String
    let rulePayload: String

    var chainDescription: String {
        chains.joined(separator: " → ")
    }

    var displayHost: String {
        metadata.host.isEmpty ? metadata.destinationIP : metadata.host
    }

    var displayProcess: String {
        if !metadata.process.isEmpty { return metadata.process }
        if !metadata.processPath.isEmpty {
            return (metadata.processPath as NSString).lastPathComponent
        }
        return "Unknown"
    }

    var displayType: String {
        "\(metadata.network.uppercased()) / \(metadata.type)"
    }
}

struct ConnectionMetadata: Codable {
    let network: String
    let type: String
    let sourceIP: String
    let destinationIP: String
    let sourcePort: String
    let destinationPort: String
    let host: String
    let process: String
    let processPath: String
}
