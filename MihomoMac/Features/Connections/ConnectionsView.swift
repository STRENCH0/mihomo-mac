import SwiftUI

struct ConnectionsView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var showCloseAllConfirmation = false
    @State private var selectedConnectionID: String?

    private var webSocket: MihomoWebSocket? {
        appState.webSocket
    }

    private var filteredConnections: [Connection] {
        guard let connections = webSocket?.connections else { return [] }
        guard !searchText.isEmpty else { return connections }
        return connections.filter { conn in
            conn.displayHost.localizedCaseInsensitiveContains(searchText) ||
            conn.displayProcess.localizedCaseInsensitiveContains(searchText) ||
            conn.rule.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let ws = webSocket, appState.mihomoProcess.status == .running {
                connectionTable(ws: ws)

                Divider()
                statusBar(ws: ws)
            } else {
                ContentUnavailableView(
                    "No Connections",
                    systemImage: "link",
                    description: Text("Start mihomo to see active connections")
                )
            }
        }
        .searchable(text: $searchText, prompt: "Search by host, process, or rule")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showCloseAllConfirmation = true
                } label: {
                    Label("Close All", systemImage: "xmark.circle")
                }
                .disabled(webSocket?.connections.isEmpty ?? true)
                .confirmationDialog(
                    "Close all connections?",
                    isPresented: $showCloseAllConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Close All", role: .destructive) {
                        Task {
                            try? await appState.closeAllConnections()
                        }
                    }
                }
            }
        }
    }

    private func statusBar(ws: MihomoWebSocket) -> some View {
        HStack(spacing: 16) {
            Text("\(ws.connections.count) connections")
            Spacer()
            Text("↓ \(TrafficFormatter.formatTotalBytes(ws.downloadTotal))")
            Text("↑ \(TrafficFormatter.formatTotalBytes(ws.uploadTotal))")
        }
        .font(.callout.monospacedDigit())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func connectionTable(ws: MihomoWebSocket) -> some View {
        Table(filteredConnections, selection: $selectedConnectionID) {
            TableColumn("Process") { conn in
                Text(conn.displayProcess)
                    .lineLimit(1)
            }
            .width(min: 80, ideal: 120)

            TableColumn("Host") { conn in
                Text(conn.displayHost)
                    .lineLimit(1)
            }
            .width(min: 120, ideal: 200)

            TableColumn("Type") { conn in
                Text(conn.displayType)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 100)

            TableColumn("Rule") { conn in
                Text(conn.rule)
                    .lineLimit(1)
            }
            .width(min: 60, ideal: 80)

            TableColumn("Chains") { conn in
                Text(conn.chainDescription)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 140)

            TableColumn("DL") { conn in
                Text(TrafficFormatter.formatTotalBytes(conn.download))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .width(min: 60, ideal: 80)

            TableColumn("UL") { conn in
                Text(TrafficFormatter.formatTotalBytes(conn.upload))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .width(min: 60, ideal: 80)

            TableColumn("Time") { conn in
                Text(conn.start, style: .relative)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 80)
        }
        .contextMenu(forSelectionType: String.self) { selection in
            if let id = selection.first,
               let conn = filteredConnections.first(where: { $0.id == id }) {
                Button("Close Connection") {
                    Task {
                        try? await appState.closeConnection(id: id)
                    }
                }
                Button("Copy Host") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(conn.displayHost, forType: .string)
                }
            }
        } primaryAction: { _ in }
    }
}

#Preview {
    ConnectionsView()
        .environment(AppState())
}
