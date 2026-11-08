import Foundation

struct StatusMenuSnapshot: Equatable {
    struct Group: Equatable, Identifiable {
        let id: String
        let title: String
        let currentSelection: String?
        let visibleMembers: [String]
        let showsOverflowAction: Bool
    }

    struct ConfigItem: Equatable, Identifiable {
        let id: UUID
        let name: String
        let isActive: Bool
    }

    let statusTitle: String
    let versionText: String?
    let controlsEnabled: Bool
    let selectedMode: OutboundMode?
    let systemProxyEnabled: Bool
    let upText: String
    let downText: String
    let groups: [Group]
    let configs: [ConfigItem]
    let activeConfigName: String

    static func build(
        processStatus: ProcessStatus,
        version: String?,
        selectedMode: OutboundMode?,
        systemProxyEnabled: Bool,
        upText: String,
        downText: String,
        proxyGroups: [ProxyData],
        configProfiles: [ConfigProfile],
        activeConfigID: UUID
    ) -> Self {
        let statusTitle: String
        switch processStatus {
        case .running: statusTitle = "Running"
        case .starting: statusTitle = "Starting..."
        case .stopped: statusTitle = "Stopped"
        case .error(let msg): statusTitle = "Error: \(msg)"
        case .failed: statusTitle = "Failed"
        }

        let configItems = configProfiles.map { profile in
            ConfigItem(id: profile.id, name: profile.name, isActive: profile.id == activeConfigID)
        }
        let activeConfigName = configProfiles.first(where: { $0.id == activeConfigID })?.name ?? "—"

        return Self(
            statusTitle: statusTitle,
            versionText: version,
            controlsEnabled: processStatus == .running,
            selectedMode: selectedMode,
            systemProxyEnabled: systemProxyEnabled,
            upText: upText,
            downText: downText,
            groups: proxyGroups.map { group in
                let members = group.all ?? []
                let current = group.now
                var visible = Array(members.prefix(20))
                if let current, !visible.contains(current), members.contains(current) {
                    visible[visible.count - 1] = current
                }
                return Group(
                    id: group.name,
                    title: group.name,
                    currentSelection: current,
                    visibleMembers: visible,
                    showsOverflowAction: members.count > 20
                )
            },
            configs: configItems,
            activeConfigName: activeConfigName
        )
    }
}
