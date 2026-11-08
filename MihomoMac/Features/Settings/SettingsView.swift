import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    @State private var showBinaryPicker = false

    var body: some View {
        @Bindable var appConfig = appState.appConfig

        Form {
            Section("Startup") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { appState.isLaunchAtLoginEnabled },
                    set: { appState.setLaunchAtLoginEnabled($0) }
                ))

                Text("Launch MihomoMac and start mihomo when you log in. System Proxy stays off.")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                if appState.launchAtLoginRequiresApproval {
                    Text("Allow MihomoMac in System Settings to enable launch at login.")
                        .foregroundStyle(.secondary)
                        .font(.caption)

                    Button("Open Login Items Settings") {
                        appState.openLoginItemsSettings()
                    }
                }

                if let error = appState.launchAtLoginError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Section("Mihomo Binary") {
                HStack {
                    TextField(
                        "Path to mihomo binary",
                        text: $appConfig.mihomoPath
                    )
                    .textFieldStyle(.roundedBorder)

                    Button("Browse...") {
                        showBinaryPicker = true
                    }
                }
                .fileImporter(
                    isPresented: $showBinaryPicker,
                    allowedContentTypes: [.item]
                ) { result in
                    if case .success(let url) = result {
                        appConfig.mihomoPath = url.path
                    }
                }
            }

            Section("System Proxy") {
                Toggle("Enable System Proxy", isOn: Binding(
                    get: { appState.systemProxy.isEnabled },
                    set: { enabled in
                        Task { await appState.setSystemProxyEnabled(enabled) }
                    }
                ))
                .disabled(!appState.canToggleSystemProxy)

                if !appState.canToggleSystemProxy {
                    Text("Start mihomo to enable system proxy")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                if let error = appState.systemProxy.lastError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Section("Process") {
                processStatusView

                HStack {
                    Button(appState.mihomoProcess.isRunning ? "Stop" : "Start") {
                        if appState.mihomoProcess.isRunning {
                            appState.stopMihomo()
                        } else {
                            appState.startMihomo()
                        }
                    }
                    .disabled(!appState.isConfigured)

                    if let version = appState.mihomoVersion {
                        Text(version)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            appState.refreshLaunchAtLoginStatus()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                appState.refreshLaunchAtLoginStatus()
            }
        }
    }

    @ViewBuilder
    private var processStatusView: some View {
        switch appState.mihomoProcess.status {
        case .stopped:
            Label("Stopped", systemImage: "stop.circle")
                .foregroundStyle(.secondary)
        case .starting:
            Label("Starting...", systemImage: "hourglass")
                .foregroundStyle(.orange)
        case .running:
            Label("Running", systemImage: "play.circle")
                .foregroundStyle(.green)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        case .failed:
            Label("Failed (max restarts reached)", systemImage: "xmark.circle")
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
