import SwiftUI

struct ConfigCardView: View {
    let profile: ConfigProfile
    let isActive: Bool
    let onActivate: () -> Void
    let onEdit: () -> Void
    let onRename: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let canDelete: Bool

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(profile.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if isActive {
                    Text("Active")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
            }
            Text("Updated \(Self.dateFormatter.string(from: profile.updatedAt))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isActive ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
                .stroke(isActive ? Color.accentColor.opacity(0.4) : Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onEdit() }
        .onTapGesture(count: 1) { onActivate() }
        .contextMenu {
            Button("Edit") { onEdit() }
            Button("Rename") { onRename() }
            Button("Duplicate") { onDuplicate() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
                .disabled(!canDelete)
        }
    }
}
