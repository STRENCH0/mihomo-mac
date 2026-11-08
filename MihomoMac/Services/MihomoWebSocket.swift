import Foundation

@MainActor
@Observable
final class MihomoWebSocket {
    // MARK: - Traffic state

    var trafficHistory: [TrafficSnapshot] = []
    var currentUp: Int64 = 0
    var currentDown: Int64 = 0

    // MARK: - Connections state

    var connections: [Connection] = []
    var downloadTotal: Int64 = 0
    var uploadTotal: Int64 = 0
    var memory: Int64 = 0
    var connectionCount: Int = 0

    // MARK: - Logs state

    var logEntries: [LogEntry] = []

    // MARK: - Private

    private let baseURL: URL
    private let secret: String

    private var trafficTask: URLSessionWebSocketTask?
    private var connectionsTask: URLSessionWebSocketTask?
    private var memoryTask: URLSessionWebSocketTask?
    private var logsTask: URLSessionWebSocketTask?

    private var trafficReconnectCount = 0
    private var connectionsReconnectCount = 0
    private var memoryReconnectCount = 0
    private var logsReconnectCount = 0

    private var isTrafficConnecting = false
    private var isConnectionsConnecting = false
    private var isMemoryConnecting = false
    private var isLogsConnecting = false

    private static let maxHistory = 60
    private static let maxLogEntries = 1000
    private static let baseReconnectDelay: UInt64 = 1_000_000_000 // 1s
    private static let maxReconnectDelay: UInt64 = 30_000_000_000 // 30s

    init(baseURL: URL, secret: String) {
        self.baseURL = baseURL
        self.secret = secret
    }

    // MARK: - Public connect/disconnect

    func connectTraffic() {
        guard !isTrafficConnecting, trafficTask == nil else { return }
        isTrafficConnecting = true
        trafficReconnectCount = 0
        openConnection(path: "/traffic", stream: .traffic)
    }

    func connectConnections() {
        guard !isConnectionsConnecting, connectionsTask == nil else { return }
        isConnectionsConnecting = true
        connectionsReconnectCount = 0
        openConnection(path: "/connections", stream: .connections)
    }

    func connectMemory() {
        guard !isMemoryConnecting, memoryTask == nil else { return }
        isMemoryConnecting = true
        memoryReconnectCount = 0
        openConnection(path: "/memory", stream: .memory)
    }

    func connectLogs() {
        guard !isLogsConnecting, logsTask == nil else { return }
        isLogsConnecting = true
        logsReconnectCount = 0
        openConnection(path: "/logs", stream: .logs)
    }

    func disconnect() {
        trafficTask?.cancel(with: .goingAway, reason: nil)
        trafficTask = nil
        isTrafficConnecting = false
        trafficReconnectCount = 0

        connectionsTask?.cancel(with: .goingAway, reason: nil)
        connectionsTask = nil
        isConnectionsConnecting = false
        connectionsReconnectCount = 0

        memoryTask?.cancel(with: .goingAway, reason: nil)
        memoryTask = nil
        isMemoryConnecting = false
        memoryReconnectCount = 0

        logsTask?.cancel(with: .goingAway, reason: nil)
        logsTask = nil
        isLogsConnecting = false
        logsReconnectCount = 0

        currentUp = 0
        currentDown = 0
        memory = 0
        connectionCount = 0
        connections = []
        downloadTotal = 0
        uploadTotal = 0
    }

    func clearLogs() {
        logEntries.removeAll()
    }

    // MARK: - Generic connection setup

    private enum Stream {
        case traffic, connections, memory, logs
    }

    private func openConnection(path: String, stream: Stream) {
        guard let wsURL = buildWebSocketURL(path: path) else {
            setConnecting(false, for: stream)
            return
        }

        var request = URLRequest(url: wsURL)
        if !secret.isEmpty {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }

        let task = URLSession.shared.webSocketTask(with: request)
        setTask(task, for: stream)
        task.resume()
        setConnecting(false, for: stream)
        receiveMessage(for: stream)
    }

    // MARK: - Receive loops

    private func receiveMessage(for stream: Stream) {
        guard let task = getTask(for: stream) else { return }

        task.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }

                switch result {
                case .success(let message):
                    self.handleMessage(message, for: stream)
                    self.resetReconnectCount(for: stream)
                    self.receiveMessage(for: stream)

                case .failure:
                    self.setTask(nil, for: stream)
                    self.attemptReconnect(for: stream)
                }
            }
        }
    }

    // MARK: - Message handling

    private func handleMessage(_ message: URLSessionWebSocketTask.Message, for stream: Stream) {
        guard let data = extractData(from: message) else { return }

        switch stream {
        case .traffic:
            handleTrafficData(data)
        case .connections:
            handleConnectionsData(data)
        case .memory:
            handleMemoryData(data)
        case .logs:
            handleLogsData(data)
        }
    }

    private func handleTrafficData(_ data: Data) {
        guard let snapshot = try? JSONDecoder().decode(TrafficSnapshot.self, from: data) else { return }

        currentUp = snapshot.up
        currentDown = snapshot.down
        trafficHistory.append(snapshot)
        if trafficHistory.count > Self.maxHistory {
            trafficHistory.removeFirst(trafficHistory.count - Self.maxHistory)
        }
    }

    private func handleConnectionsData(_ data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(ConnectionsSnapshot.self, from: data) else { return }

        connections = snapshot.connections ?? []
        downloadTotal = snapshot.downloadTotal
        uploadTotal = snapshot.uploadTotal
        connectionCount = snapshot.connections?.count ?? 0
    }

    private func handleMemoryData(_ data: Data) {
        guard let snapshot = try? JSONDecoder().decode(MemorySnapshot.self, from: data) else { return }
        memory = snapshot.inuse
    }

    private func handleLogsData(_ data: Data) {
        guard let entry = try? JSONDecoder().decode(LogEntry.self, from: data) else { return }

        logEntries.append(entry)
        if logEntries.count > Self.maxLogEntries {
            logEntries.removeFirst(logEntries.count - Self.maxLogEntries)
        }
    }

    // MARK: - Reconnect

    private func attemptReconnect(for stream: Stream) {
        incrementReconnectCount(for: stream)
        let count = getReconnectCount(for: stream)

        let path: String
        switch stream {
        case .traffic: path = "/traffic"
        case .connections: path = "/connections"
        case .memory: path = "/memory"
        case .logs: path = "/logs"
        }

        let backoff = min(
            Self.baseReconnectDelay * UInt64(1 << min(count - 1, 4)),
            Self.maxReconnectDelay
        )

        Task {
            try? await Task.sleep(nanoseconds: backoff)
            guard self.getTask(for: stream) == nil else { return }
            self.openConnection(path: path, stream: stream)
        }
    }

    // MARK: - Helpers

    private func extractData(from message: URLSessionWebSocketTask.Message) -> Data? {
        switch message {
        case .string(let text):
            return text.data(using: .utf8)
        case .data(let data):
            return data
        @unknown default:
            return nil
        }
    }

    private func buildWebSocketURL(path: String) -> URL? {
        var components = URLComponents()
        components.scheme = "ws"
        components.host = baseURL.host
        components.port = baseURL.port
        components.path = path
        if !secret.isEmpty {
            components.queryItems = [URLQueryItem(name: "token", value: secret)]
        }
        return components.url
    }

    // MARK: - Per-stream state accessors

    private func getTask(for stream: Stream) -> URLSessionWebSocketTask? {
        switch stream {
        case .traffic: trafficTask
        case .connections: connectionsTask
        case .memory: memoryTask
        case .logs: logsTask
        }
    }

    private func setTask(_ task: URLSessionWebSocketTask?, for stream: Stream) {
        switch stream {
        case .traffic: trafficTask = task
        case .connections: connectionsTask = task
        case .memory: memoryTask = task
        case .logs: logsTask = task
        }
    }

    private func setConnecting(_ value: Bool, for stream: Stream) {
        switch stream {
        case .traffic: isTrafficConnecting = value
        case .connections: isConnectionsConnecting = value
        case .memory: isMemoryConnecting = value
        case .logs: isLogsConnecting = value
        }
    }

    private func getReconnectCount(for stream: Stream) -> Int {
        switch stream {
        case .traffic: trafficReconnectCount
        case .connections: connectionsReconnectCount
        case .memory: memoryReconnectCount
        case .logs: logsReconnectCount
        }
    }

    private func resetReconnectCount(for stream: Stream) {
        switch stream {
        case .traffic: trafficReconnectCount = 0
        case .connections: connectionsReconnectCount = 0
        case .memory: memoryReconnectCount = 0
        case .logs: logsReconnectCount = 0
        }
    }

    private func incrementReconnectCount(for stream: Stream) {
        switch stream {
        case .traffic: trafficReconnectCount += 1
        case .connections: connectionsReconnectCount += 1
        case .memory: memoryReconnectCount += 1
        case .logs: logsReconnectCount += 1
        }
    }
}
