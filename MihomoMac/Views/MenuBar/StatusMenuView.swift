import SwiftUI

struct StatusMenuContent: View {
    @Bindable var appState: AppState
    let openDashboard: () -> Void

    private var isRunning: Bool {
        appState.mihomoProcess.status == .running
    }

    var body: some View {
        // Header
        Button {
            // no-op, just displays status
        } label: {
            Text("Mihomo — \(statusText)")
        }
        .disabled(true)

        Divider()

        // Start / Stop
        Button(isRunning ? "Stop Mihomo" : "Start Mihomo") {
            if isRunning {
                appState.stopMihomo()
            } else {
                appState.startMihomo()
            }
        }
        .disabled(!appState.appConfig.isConfigured && !isRunning)

        if isRunning {
            Divider()

            // Traffic
            let up = TrafficFormatter.formatBytes(appState.webSocket?.currentUp ?? 0)
            let down = TrafficFormatter.formatBytes(appState.webSocket?.currentDown ?? 0)
            Button {} label: {
                Text("↑ \(up)  ↓ \(down)")
            }
            .disabled(true)

            Divider()

            // System Proxy
            Toggle("System Proxy", isOn: Binding(
                get: { appState.systemProxy.isEnabled },
                set: { enabled in
                    Task { await appState.setSystemProxyEnabled(enabled) }
                }
            ))

            // Outbound Mode
            Menu("Outbound Mode — \(appState.selectedOutboundMode?.title ?? "Rule")") {
                ForEach(OutboundMode.allCases) { mode in
                    Button {
                        Task { try? await appState.setOutboundMode(mode) }
                    } label: {
                        if appState.selectedOutboundMode == mode {
                            Text("✓ \(mode.title)")
                        } else {
                            Text("   \(mode.title)")
                        }
                    }
                }
            }

            // Proxy Groups
            if !appState.proxyGroups.isEmpty {
                Divider()

                ForEach(appState.proxyGroups) { group in
                    Menu("\(group.name)    \(group.now ?? "—")") {
                        Button {
                            Task { await appState.testGroupDelays(groupName: group.name) }
                        } label: {
                            Label("Speed Test", systemImage: "bolt.fill")
                        }

                        Divider()

                        let members = group.all ?? []
                        ForEach(members.prefix(30), id: \.self) { member in
                            Button {
                                Task { try? await appState.selectProxy(group: group.name, name: member) }
                            } label: {
                                let isCurrent = member == group.now
                                let delayText = delayLabel(for: member)
                                if isCurrent {
                                    Text("✓ \(member)\(delayText)")
                                } else {
                                    Text("   \(member)\(delayText)")
                                }
                            }
                        }

                        if members.count > 30 {
                            Divider()
                            Button("Show All in Dashboard...") { openDashboard() }
                        }
                    }
                }
            }
        }

        Divider()

        Button("Open Dashboard...") {
            openDashboard()
        }
        .keyboardShortcut("D", modifiers: [.command, .shift])

        Button("Quit Mihomo") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("Q")
    }

    private var statusText: String {
        switch appState.mihomoProcess.status {
        case .running: "Running"
        case .starting: "Starting..."
        case .stopped: "Stopped"
        case .error: "Error"
        case .failed: "Failed"
        }
    }

    private func delayLabel(for member: String) -> String {
        guard let delay = appState.proxyDelays[member] else { return "" }
        if delay == 0 { return "    Timeout" }
        return "    \(delay) ms"
    }
}
