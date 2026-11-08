import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case connections = "Connections"
    case logs = "Logs"
    case proxies = "Proxies"
    case configs = "Configs"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: "chart.bar"
        case .connections: "link"
        case .logs: "doc.text"
        case .proxies: "shield"
        case .configs: "doc.badge.gearshape"
        case .settings: "gearshape"
        }
    }
}

struct ContentView: View {
    @State private var selectedItem: NavigationItem? = .overview

    var body: some View {
        NavigationSplitView {
            List(NavigationItem.allCases, selection: $selectedItem) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch selectedItem {
            case .overview:
                OverviewView()
            case .connections:
                ConnectionsView()
            case .logs:
                LogsView()
            case .proxies:
                ProxiesView()
            case .configs:
                ConfigsView()
            case .settings:
                SettingsView()
            case nil:
                Text("Select an item")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
}
