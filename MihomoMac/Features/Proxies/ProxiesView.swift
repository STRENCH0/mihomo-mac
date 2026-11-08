import SwiftUI

struct ProxiesView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var testingProxies: Set<String> = []
    @State private var testingGroups: Set<String> = []
    @State private var expandedGroups: Set<String> = []

    private var isRunning: Bool {
        appState.mihomoProcess.status == .running
    }

    private var filteredGroups: [ProxyData] {
        guard !searchText.isEmpty else { return appState.proxyGroups }
        return appState.proxyGroups.filter { group in
            if group.name.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            guard let members = group.all else { return false }
            return members.contains { name in
                name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        Group {
            if isRunning {
                proxyList
            } else {
                ContentUnavailableView(
                    "No Proxies",
                    systemImage: "shield",
                    description: Text("Start mihomo to see proxy groups")
                )
            }
        }
        .searchable(text: $searchText, prompt: "Search proxies")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    Task {
                        await testAllDelays()
                    }
                } label: {
                    Label("Test All", systemImage: "bolt.horizontal")
                }
                .disabled(!isRunning || !testingGroups.isEmpty)

                Button {
                    Task {
                        await appState.fetchProxies()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(!isRunning)
            }
        }
        .onAppear {
            if expandedGroups.isEmpty {
                expandedGroups = Set(appState.proxyGroups.prefix(3).map(\.name))
            }
        }
    }

    private var proxyList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredGroups) { group in
                    ProxyGroupCard(
                        group: group,
                        appState: appState,
                        searchText: searchText,
                        testingProxies: $testingProxies,
                        testingGroups: $testingGroups,
                        expandedGroups: $expandedGroups
                    )
                }
            }
            .padding()
        }
    }

    private func testAllDelays() async {
        let groups = appState.proxyGroups
        for group in groups {
            testingGroups.insert(group.name)
        }
        await withTaskGroup(of: Void.self) { taskGroup in
            for group in groups {
                taskGroup.addTask { @MainActor in
                    await appState.testGroupDelays(groupName: group.name)
                    testingGroups.remove(group.name)
                }
            }
        }
    }
}

// MARK: - Proxy Group Card

private struct ProxyGroupCard: View {
    let group: ProxyData
    let appState: AppState
    let searchText: String
    @Binding var testingProxies: Set<String>
    @Binding var testingGroups: Set<String>
    @Binding var expandedGroups: Set<String>

    private var isExpanded: Bool {
        expandedGroups.contains(group.name)
    }

    private var members: [ProxyData] {
        let proxies = group.members(in: appState.allProxies)
        if searchText.isEmpty { return proxies }
        if group.name.localizedCaseInsensitiveContains(searchText) { return proxies }
        return proxies.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var memberCount: Int {
        group.all?.count ?? 0
    }

    private var currentNowDelay: Int? {
        guard let now = group.now else { return nil }
        return appState.proxyDelays[now]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            groupHeader
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedGroups.remove(group.name)
                        } else {
                            expandedGroups.insert(group.name)
                        }
                    }
                }

            if isExpanded && !members.isEmpty {
                Divider()
                    .padding(.horizontal, 12)

                proxyGrid
                    .padding(12)
            }
        }
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Group Header

    private var groupHeader: some View {
        HStack(spacing: 8) {
            groupIcon

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(group.name)
                        .font(.headline)

                    Text(group.type)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))

                    Text("\(memberCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                }

                if let now = group.now {
                    HStack(spacing: 4) {
                        Image(systemName: "eye")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(now)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if testingGroups.contains(group.name) {
                ProgressView()
                    .controlSize(.small)
            } else if let delay = currentNowDelay, delay > 0 {
                DelayBadge(delay: delay)
            } else {
                Button {
                    Task {
                        testingGroups.insert(group.name)
                        await appState.testGroupDelays(groupName: group.name)
                        testingGroups.remove(group.name)
                    }
                } label: {
                    Text("Test")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private var groupIcon: some View {
        if let iconURL = group.icon, let url = URL(string: iconURL) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: groupIconName)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 32, height: 32)
        } else {
            Image(systemName: groupIconName)
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
        }
    }

    private var groupIconName: String {
        switch group.type {
        case "Selector": return "hand.tap"
        case "URLTest": return "bolt.horizontal"
        case "Fallback": return "arrow.triangle.branch"
        case "LoadBalance": return "scale.3d"
        case "Relay": return "arrow.right.arrow.left"
        default: return "shield"
        }
    }

    // MARK: - Proxy Grid

    private let gridColumns = [
        GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 8),
    ]

    private var proxyGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(members) { proxy in
                ProxyCard(
                    proxy: proxy,
                    isSelected: proxy.name == group.now,
                    delay: appState.proxyDelays[proxy.name],
                    isTesting: testingProxies.contains(proxy.name),
                    isSelectable: group.isSelectable
                )
                .onTapGesture {
                    guard group.isSelectable, proxy.name != group.now else { return }
                    Task {
                        try? await appState.selectProxy(group: group.name, name: proxy.name)
                    }
                }
                .contextMenu {
                    Button("Test Delay") {
                        Task {
                            testingProxies.insert(proxy.name)
                            await appState.testDelay(name: proxy.name)
                            testingProxies.remove(proxy.name)
                        }
                    }
                    Button("Copy Name") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(proxy.name, forType: .string)
                    }
                }
            }
        }
    }
}

// MARK: - Proxy Card

private struct ProxyCard: View {
    let proxy: ProxyData
    let isSelected: Bool
    let delay: Int?
    let isTesting: Bool
    let isSelectable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(proxy.name)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .lineLimit(1)
                .truncationMode(.tail)

            HStack {
                Text(proxy.type)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                if isTesting {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    DelayBadge(delay: delay)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected ? AnyShapeStyle(.tint.opacity(0.2)) : AnyShapeStyle(.quaternary.opacity(0.5)),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.tint.opacity(0.4), lineWidth: 1)
            }
        }
        .opacity(isSelectable ? 1.0 : 0.85)
    }
}

// MARK: - Delay Badge

private struct DelayBadge: View {
    let delay: Int?

    private var displayText: String {
        guard let delay else { return "" }
        if delay == 0 { return "Timeout" }
        return "\(delay) ms"
    }

    private var badgeColor: Color {
        guard let delay, delay > 0 else {
            if delay == 0 { return .secondary }
            return .clear
        }
        switch delay {
        case ..<200: return .green
        case 200..<500: return .yellow
        case 500..<1000: return .orange
        default: return .red
        }
    }

    var body: some View {
        if let delay {
            Text(displayText)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(delay > 0 ? badgeColor : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    (delay > 0 ? badgeColor.opacity(0.15) : Color.secondary.opacity(0.1)),
                    in: RoundedRectangle(cornerRadius: 4)
                )
        }
    }
}

#Preview {
    ProxiesView()
        .environment(AppState())
}
