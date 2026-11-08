import SwiftUI

struct LogsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedLevel: LogLevel?
    @State private var searchText = ""
    @State private var autoScroll = true

    private var webSocket: MihomoWebSocket? {
        appState.webSocket
    }

    private var filteredLogs: [LogEntry] {
        guard let entries = webSocket?.logEntries else { return [] }
        return entries.filter { entry in
            (selectedLevel == nil || entry.type == selectedLevel?.rawValue) &&
            (searchText.isEmpty || entry.payload.localizedCaseInsensitiveContains(searchText))
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        Group {
            if webSocket != nil, appState.mihomoProcess.status == .running {
                logList
            } else {
                ContentUnavailableView(
                    "No Logs",
                    systemImage: "doc.text",
                    description: Text("Start mihomo to see logs")
                )
            }
        }
        .searchable(text: $searchText, prompt: "Search logs")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Picker("Level", selection: $selectedLevel) {
                    Text("All").tag(LogLevel?.none)
                    ForEach(LogLevel.allCases) { level in
                        Text(level.displayName).tag(LogLevel?.some(level))
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)

                Toggle(isOn: $autoScroll) {
                    Label("Auto-scroll", systemImage: "arrow.down.to.line")
                }
                .toggleStyle(.button)

                Button {
                    webSocket?.clearLogs()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(webSocket?.logEntries.isEmpty ?? true)
            }
        }
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            List(filteredLogs) { entry in
                logRow(entry)
                    .id(entry.id)
            }
            .listStyle(.plain)
            .onChange(of: filteredLogs.count) {
                if autoScroll, let lastID = filteredLogs.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func logRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(entry.levelColor)
                .frame(width: 8, height: 8)
                .padding(.top, 4)

            Text(Self.timeFormatter.string(from: entry.timestamp))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            Text(entry.type.uppercased())
                .font(.caption.monospaced().bold())
                .foregroundStyle(entry.levelColor)
                .frame(width: 55, alignment: .leading)

            Text(entry.payload)
                .font(.caption.monospaced())
                .lineLimit(3)
                .textSelection(.enabled)
        }
        .padding(.vertical, 1)
    }
}

#Preview {
    LogsView()
        .environment(AppState())
}
