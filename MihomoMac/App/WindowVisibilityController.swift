import AppKit

@MainActor
final class WindowVisibilityController: NSObject, NSWindowDelegate {
    private(set) var isWindowHidden = false
    weak var window: NSWindow?

    func attach(to window: NSWindow) {
        self.window = window
        window.delegate = self
    }

    func shouldAllowWindowClose() -> Bool {
        hideWindow()
        return false
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        shouldAllowWindowClose()
    }

    func hideWindow() {
        isWindowHidden = true
        NSApp.setActivationPolicy(.accessory)
        window?.orderOut(nil)
    }

    func openDashboard() {
        isWindowHidden = false
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
