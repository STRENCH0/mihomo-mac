import SwiftUI
import AppKit

struct ConfigsView: View {
    @Environment(AppState.self) private var appState

    private struct EditingSession: Identifiable {
        let profileID: UUID
        let initialContent: String

        var id: UUID { profileID }
    }

    @State private var showCreateAlert = false
    @State private var newConfigName = ""
    @State private var createError: String?

    @State private var showRenameAlert = false
    @State private var renamingProfileID: UUID?
    @State private var renameText = ""
    @State private var renameError: String?

    @State private var showDeleteConfirm = false
    @State private var deletingProfileID: UUID?

    @State private var editingSession: EditingSession?
    @State private var editorOpenError: String?

    @State private var showDuplicateAlert = false
    @State private var duplicatingProfileID: UUID?
    @State private var duplicateName = ""
    @State private var duplicateError: String?

    private var configManager: ConfigManager { appState.configManager }

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 12)],
                spacing: 12
            ) {
                ForEach(configManager.profiles) { profile in
                    ConfigCardView(
                        profile: profile,
                        isActive: profile.id == configManager.activeProfileID,
                        onActivate: { configManager.setActive(id: profile.id) },
                        onEdit: {
                            openEditor(for: profile)
                        },
                        onRename: {
                            renamingProfileID = profile.id
                            renameText = profile.name
                            renameError = nil
                            showRenameAlert = true
                        },
                        onDuplicate: {
                            duplicatingProfileID = profile.id
                            duplicateName = "\(profile.name) Copy"
                            duplicateError = nil
                            showDuplicateAlert = true
                        },
                        onDelete: {
                            deletingProfileID = profile.id
                            showDeleteConfirm = true
                        },
                        canDelete: configManager.profiles.count > 1
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Configs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    NSWorkspace.shared.open(configManager.configsDirURL)
                } label: {
                    Image(systemName: "folder")
                }
                .help("Open configs folder in Finder")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newConfigName = ""
                    createError = nil
                    showCreateAlert = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New Config", isPresented: $showCreateAlert) {
            TextField("Config name", text: $newConfigName)
            Button("Create") { performCreate() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let err = createError {
                Text(err)
            }
        }
        .alert("Rename Config", isPresented: $showRenameAlert) {
            TextField("New name", text: $renameText)
            Button("Rename") { performRename() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let err = renameError {
                Text(err)
            }
        }
        .alert("Duplicate Config", isPresented: $showDuplicateAlert) {
            TextField("New name", text: $duplicateName)
            Button("Duplicate") { performDuplicate() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let err = duplicateError {
                Text(err)
            }
        }
        .confirmationDialog(
            "Delete Config",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the config file.")
        }
        .sheet(item: $editingSession) { session in
            ConfigEditorSheet(profileID: session.profileID, initialContent: session.initialContent)
                .environment(appState)
        }
        .alert("Open Config Error", isPresented: Binding(
            get: { editorOpenError != nil },
            set: { isPresented in
                if !isPresented {
                    editorOpenError = nil
                }
            }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(editorOpenError ?? "Unknown error occurred while opening the config")
        }
    }

    // MARK: - Actions

    private func performCreate() {
        let name = newConfigName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            createError = "Name cannot be empty"
            showCreateAlert = true
            return
        }
        do {
            _ = try configManager.createProfile(name: name)
        } catch {
            createError = error.localizedDescription
            showCreateAlert = true
        }
    }

    private func performRename() {
        guard let id = renamingProfileID else { return }
        let name = renameText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            renameError = "Name cannot be empty"
            showRenameAlert = true
            return
        }
        do {
            try configManager.renameProfile(id: id, newName: name)
        } catch {
            renameError = error.localizedDescription
            showRenameAlert = true
        }
    }

    private func performDuplicate() {
        guard let id = duplicatingProfileID else { return }
        let name = duplicateName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            duplicateError = "Name cannot be empty"
            showDuplicateAlert = true
            return
        }
        do {
            _ = try configManager.duplicateProfile(id: id, newName: name)
        } catch {
            duplicateError = error.localizedDescription
            showDuplicateAlert = true
        }
    }

    private func performDelete() {
        guard let id = deletingProfileID else { return }
        try? configManager.deleteProfile(id: id)
    }

    private func openEditor(for profile: ConfigProfile) {
        do {
            editingSession = EditingSession(
                profileID: profile.id,
                initialContent: try configManager.readContent(id: profile.id)
            )
        } catch {
            editorOpenError = error.localizedDescription
        }
    }
}

#Preview {
    ConfigsView()
        .environment(AppState())
}
