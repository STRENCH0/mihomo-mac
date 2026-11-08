import SwiftUI
import CodeEditSourceEditor
import CodeEditLanguages

enum ConfigEditorTheme {
    static func make(for colorScheme: ColorScheme) -> EditorTheme {
        switch colorScheme {
        case .dark:
            EditorTheme(
                text: .init(color: color(0xFFFFFF)),
                insertionPoint: color(0x007AFF),
                invisibles: .init(color: color(0x53606E)),
                background: color(0x161B24),
                lineHighlight: color(0x1D2430),
                selection: color(0x3A4A63),
                keywords: .init(color: color(0xFF7AB2), bold: true),
                commands: .init(color: color(0x78C2B3)),
                types: .init(color: color(0x6BDFFF)),
                attributes: .init(color: color(0xCC9768)),
                variables: .init(color: color(0x4EB0CC)),
                values: .init(color: color(0xB281EB)),
                numbers: .init(color: color(0xD9C97C)),
                strings: .init(color: color(0xFF8170)),
                characters: .init(color: color(0xD9C97C)),
                comments: .init(color: color(0x7F8C98))
            )
        default:
            EditorTheme(
                text: .init(color: color(0x000000)),
                insertionPoint: color(0x000000),
                invisibles: .init(color: color(0xD6D6D6)),
                background: color(0xFFFFFF),
                lineHighlight: color(0xECF5FF),
                selection: color(0xB2D7FF),
                keywords: .init(color: color(0x9B2393), bold: true),
                commands: .init(color: color(0x326D74)),
                types: .init(color: color(0x0B4F79)),
                attributes: .init(color: color(0x815F03)),
                variables: .init(color: color(0x0F68A0)),
                values: .init(color: color(0x6C36A9)),
                numbers: .init(color: color(0x1C00CF)),
                strings: .init(color: color(0xC41A16)),
                characters: .init(color: color(0x1C00CF)),
                comments: .init(color: color(0x267507))
            )
        }
    }

    private static func color(_ hex: Int) -> NSColor {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}

struct ConfigEditorSheet: View {
    let profileID: UUID
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var content: String
    @State private var hasChanges: Bool = false
    @State private var isSaving: Bool = false
    @State private var saveError: String?
    @State private var showSaveError: Bool = false
    @State private var showUnsavedChangesAlert: Bool = false

    @State private var editorState = SourceEditorState()

    private var configManager: ConfigManager { appState.configManager }

    init(profileID: UUID, initialContent: String) {
        self.profileID = profileID
        _content = State(initialValue: initialContent)
    }

    private var editorConfiguration: SourceEditorConfiguration {
        SourceEditorConfiguration(
            appearance: .init(
                theme: ConfigEditorTheme.make(for: colorScheme),
                font: .monospacedSystemFont(ofSize: 13, weight: .regular),
                wrapLines: true
            ),
            behavior: .init(
                indentOption: .spaces(count: 2)
            ),
            layout: .init(
                contentInsets: NSEdgeInsets(top: 0, left: 0, bottom: 40, right: 0)
            ),
            peripherals: .init(
                showMinimap: false
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SourceEditor(
                    $content,
                    language: .yaml,
                    configuration: editorConfiguration,
                    state: $editorState
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                HStack {
                    Spacer()

                    Button("Cancel") {
                        if hasChanges {
                            showUnsavedChangesAlert = true
                        } else {
                            dismiss()
                        }
                    }
                    .disabled(isSaving)

                    Button("Save") {
                        performSave()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!hasChanges || isSaving)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.bar)
            }
            .navigationTitle("Edit Config")
            .onChange(of: content) { _, _ in
                hasChanges = true
            }
            .alert("Save Error", isPresented: $showSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveError ?? "Unknown error occurred while saving")
            }
            .alert("Unsaved Changes", isPresented: $showUnsavedChangesAlert) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.black.opacity(0.2))
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    private func performSave() {
        isSaving = true

        Task {
            do {
                try validateYAML(content)
                try configManager.saveContent(id: profileID, content: content)

                await MainActor.run {
                    isSaving = false
                    hasChanges = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveError = error.localizedDescription
                    showSaveError = true
                }
            }
        }
    }

    private func validateYAML(_ yaml: String) throws {
        guard !yaml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConfigError.invalidYAML(description: "Config file cannot be empty")
        }
    }
}

#Preview {
    ConfigEditorSheet(profileID: UUID(), initialContent: "mixed-port: 7890\n")
        .environment(AppState())
}
