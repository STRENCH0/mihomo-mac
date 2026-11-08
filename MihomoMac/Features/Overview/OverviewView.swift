import SwiftUI
import Charts

// MARK: - Main View

struct OverviewView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let isRunning = appState.mihomoProcess.status == .running

        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    RunningStatusCard()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    NetworkStatusCard()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .fixedSize(horizontal: false, vertical: true)

                if isRunning {
                    TrafficStatsCard()
                } else {
                    notRunningPlaceholder
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                ModePickerControl(
                    selectedMode: appState.selectedOutboundMode,
                    isEnabled: isRunning,
                    onSelect: { mode in
                        do {
                            try await appState.setOutboundMode(mode)
                            return true
                        } catch {
                            return false
                        }
                    }
                )
                .frame(width: 200)
            }
        }
    }

    private var notRunningPlaceholder: some View {
        GroupBox {
            VStack(spacing: 8) {
                Image(systemName: "play.slash")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Start mihomo to see traffic data")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        }
    }
}

// MARK: - Card Header

private struct CardHeader: View {
    let icon: String
    let title: String
    var refreshAction: (() -> Void)?

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Spacer()
            if let action = refreshAction {
                Button(action: action) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Stat Value (large colored number + label)

private struct StatValue: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(color)
        }
    }
}

// MARK: - Info Item (small label + value)

private struct InfoItem: View {
    let icon: String
    let label: String
    let value: String
    var statusColor: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let statusColor {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                } else {
                    Image(systemName: icon)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.callout)
                .lineLimit(1)
        }
    }
}

// MARK: - Running Status Card

private struct RunningStatusCard: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(icon: "display", title: "Running Status")

                HStack(spacing: 0) {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        StatValue(
                            icon: "clock",
                            label: "Uptime",
                            value: formatUptime(since: appState.processStartTime),
                            color: .blue
                        )
                    }
                    Spacer()
                    StatValue(
                        icon: "link",
                        label: "Connections",
                        value: "\(appState.webSocket?.connectionCount ?? 0)",
                        color: .green
                    )
                    Spacer()
                    StatValue(
                        icon: "memorychip",
                        label: "Memory",
                        value: formatMemory(appState.webSocket?.memory ?? 0),
                        color: .purple
                    )
                }

                Divider()

                HStack(spacing: 0) {
                    InfoItem(
                        icon: "circle.fill",
                        label: "Status",
                        value: statusText,
                        statusColor: statusColor
                    )
                    Spacer()
                    InfoItem(
                        icon: "cpu",
                        label: "Kernel",
                        value: appState.mihomoVersion ?? "—"
                    )
                    Spacer()
                    InfoItem(
                        icon: "laptopcomputer",
                        label: "System",
                        value: systemVersion
                    )
                    Spacer()
                    InfoItem(
                        icon: "info.circle",
                        label: "Version",
                        value: appVersion
                    )
                }
            }
            .padding(8)
        }
    }

    private var statusText: String {
        switch appState.mihomoProcess.status {
        case .running: "Connected"
        case .stopped: "Stopped"
        case .starting: "Starting..."
        case .error(let msg): "Error: \(msg)"
        case .failed: "Failed"
        }
    }

    private var statusColor: Color {
        switch appState.mihomoProcess.status {
        case .running: .green
        case .stopped: .gray
        case .starting: .yellow
        case .error, .failed: .red
        }
    }

    private var systemVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion)"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private func formatUptime(since start: Date?) -> String {
        guard let start else { return "—" }
        let interval = Int(Date().timeIntervalSince(start))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        let seconds = interval % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    private func formatMemory(_ bytes: Int64) -> String {
        if bytes == 0 { return "—" }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }
}

// MARK: - Network Status Card

private struct NetworkStatusCard: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let monitor = appState.networkMonitor

        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(icon: "globe", title: "Network Status")

                HStack(spacing: 0) {
                    StatValue(
                        icon: "globe",
                        label: "Internet",
                        value: latencyString(monitor.internetLatency),
                        color: .green
                    )
                    Spacer()
                    StatValue(
                        icon: "server.rack",
                        label: "DNS",
                        value: latencyString(monitor.dnsLatency),
                        color: .yellow
                    )
                    Spacer()
                    StatValue(
                        icon: "wifi.router",
                        label: "Router",
                        value: latencyString(monitor.routerLatency),
                        color: .purple
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxHeight: .infinity)
    }

    private func latencyString(_ ms: Int?) -> String {
        guard let ms else { return "—" }
        return "\(ms) ms"
    }


}

// MARK: - Traffic Stats Card

private struct TrafficStatsCard: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let ws = appState.webSocket
        let history = ws?.trafficHistory ?? []

        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(icon: "arrow.up.arrow.down", title: "Traffic Stats")

                HStack(spacing: 0) {
                    StatValue(
                        icon: "arrow.up",
                        label: "Upload Speed",
                        value: TrafficFormatter.formatBytes(ws?.currentUp ?? 0),
                        color: .blue
                    )
                    Spacer()
                    StatValue(
                        icon: "arrow.down",
                        label: "Download Speed",
                        value: TrafficFormatter.formatBytes(ws?.currentDown ?? 0),
                        color: .green
                    )
                }

                if !history.isEmpty {
                    Chart(history) { snapshot in
                        LineMark(
                            x: .value("Time", snapshot.timestamp),
                            y: .value("Speed", Double(snapshot.down) / 1024)
                        )
                        .foregroundStyle(by: .value("Direction", "Download"))
                        .interpolationMethod(.monotone)

                        LineMark(
                            x: .value("Time", snapshot.timestamp),
                            y: .value("Speed", Double(snapshot.up) / 1024)
                        )
                        .foregroundStyle(by: .value("Direction", "Upload"))
                        .interpolationMethod(.monotone)
                    }
                    .chartForegroundStyleScale([
                        "Download": Color.green,
                        "Upload": Color.blue,
                    ])
                    .chartYAxisLabel("KB/s")
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .second, count: 15)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.minute().second())
                        }
                    }
                    .chartLegend(.visible)
                    .frame(minHeight: 150)
                }

                Divider()

                HStack(spacing: 0) {
                    InfoItem(
                        icon: "arrow.up.circle",
                        label: "Upload",
                        value: TrafficFormatter.formatTotalBytes(ws?.uploadTotal ?? 0)
                    )
                    Spacer()
                    InfoItem(
                        icon: "arrow.down.circle",
                        label: "Download",
                        value: TrafficFormatter.formatTotalBytes(ws?.downloadTotal ?? 0)
                    )
                }
            }
            .padding(8)
        }
    }
}

#Preview {
    OverviewView()
        .environment(AppState())
}
