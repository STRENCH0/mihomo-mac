import SwiftUI
import AppKit

struct WindowReader: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        ResolverView(onResolve: onResolve)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class ResolverView: NSView {
    let onResolve: (NSWindow) -> Void

    init(onResolve: @escaping (NSWindow) -> Void) {
        self.onResolve = onResolve
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            onResolve(window)
        }
    }
}
