enum ConfigStatus: Equatable {
    case idle
    case loaded
    case error(String)
}

/// Represents the lifecycle state of the mihomo process.
/// - `error`: A transient failure with a message (e.g., failed to start, unexpected exit). May be followed by a restart.
/// - `failed`: Terminal state — the process exceeded the maximum restart count.
enum ProcessStatus: Equatable {
    case stopped
    case starting
    case running
    case error(String)
    case failed
}
