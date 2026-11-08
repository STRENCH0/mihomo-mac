import SwiftUI

struct StatusHeaderSection: View {
    let snapshot: StatusMenuSnapshot

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(snapshot.controlsEnabled ? .green : .gray)
                        .frame(width: 8, height: 8)
                    Text("Mihomo")
                        .font(.headline)
                }
                if let version = snapshot.versionText {
                    Text(version)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(snapshot.statusTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct TrafficRow: View {
    let snapshot: StatusMenuSnapshot

    var body: some View {
        HStack {
            Label(snapshot.upText, systemImage: "arrow.up")
            Spacer()
            Label(snapshot.downText, systemImage: "arrow.down")
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }
}

struct QuickControlsSection: View {
    @Bindable var appState: AppState
    let snapshot: StatusMenuSnapshot

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Mode")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            ModePickerControl(
                selectedMode: snapshot.selectedMode,
                isEnabled: snapshot.controlsEnabled,
                onSelect: { mode in
                    do {
                        try await appState.setOutboundMode(mode)
                        return true
                    } catch {
                        return false
                    }
                }
            )
            .frame(width: 276)

            Toggle("System Proxy", isOn: Binding(
                get: { snapshot.systemProxyEnabled },
                set: { enabled in
                    Task { await appState.setSystemProxyEnabled(enabled) }
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(!appState.canToggleSystemProxy)
        }
    }
}

struct ProxyGroupsSection: View {
    @Bindable var appState: AppState
    let snapshot: StatusMenuSnapshot
    let openDashboard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Proxy Groups")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(snapshot.groups) { group in
                Menu {
                    ForEach(group.visibleMembers, id: \.self) { member in
                        Button {
                            Task {
                                try? await appState.selectProxy(group: group.id, name: member)
                            }
                        } label: {
                            HStack {
                                Text(member)
                                if member == group.currentSelection {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    if group.showsOverflowAction {
                        Divider()
                        Button("Show All in Dashboard...") {
                            openDashboard()
                        }
                    }
                } label: {
                    HStack {
                        Text(group.title)
                            .lineLimit(1)
                        Spacer()
                        Text(group.currentSelection ?? "—")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .font(.caption)
                }
                .menuStyle(.borderlessButton)
            }
        }
    }
}

struct FooterSection: View {
    let openDashboard: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Button {
                openDashboard()
            } label: {
                HStack {
                    Text("Open Dashboard")
                    Spacer()
                    Text("Cmd+Shift+D")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            Button {
                NSApp.terminate(nil)
            } label: {
                HStack {
                    Text("Quit Mihomo")
                    Spacer()
                    Text("Cmd+Q")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }
}
