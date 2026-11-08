import SwiftUI
import Dispatch

@main
struct MihomoMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .background(WindowReader { window in
                    appDelegate.windowController.attach(to: window)
                })
                .onAppear {
                    appDelegate.setup(appState: appState)
                }
        }
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Open Dashboard") {
                    appDelegate.openDashboard()
                }
                .keyboardShortcut("D", modifiers: [.command, .shift])
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?
    let windowController = WindowVisibilityController()
    private var statusBarController: StatusBarController?
    private var sigTermSource: (any DispatchSourceSignal)?
    private var iconObservation: Any?
    private var shouldStartMihomoAtLogin = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        shouldStartMihomoAtLogin = Self.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent)
        startMihomoAtLoginIfNeeded()
    }

    nonisolated static func isLoginLaunch(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event,
              event.eventClass == kCoreEventClass,
              event.eventID == kAEOpenApplication else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    func setup(appState: AppState) {
        guard self.appState == nil else { return }
        self.appState = appState
        installSIGTERMHandler()
        startMihomoAtLoginIfNeeded()

        statusBarController = StatusBarController(
            appState: appState,
            openDashboard: { [weak self] in self?.openDashboard() }
        )

        iconObservation = withObservationTracking {
            _ = appState.systemProxy.isEnabled
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.statusBarController?.updateIcon()
                self?.startIconTracking()
            }
        }
    }

    private func startIconTracking() {
        guard let appState else { return }
        iconObservation = withObservationTracking {
            _ = appState.systemProxy.isEnabled
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.statusBarController?.updateIcon()
                self?.startIconTracking()
            }
        }
    }

    private func startMihomoAtLoginIfNeeded() {
        guard shouldStartMihomoAtLogin, let appState else { return }
        shouldStartMihomoAtLogin = false
        appState.startMihomo()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState?.systemProxy.disableSync()
    }

    func openDashboard() {
        windowController.openDashboard()
    }

    private func installSIGTERMHandler() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { [weak self] in
            self?.appState?.systemProxy.disableSync()
            exit(0)
        }
        source.resume()
        sigTermSource = source
    }
}
