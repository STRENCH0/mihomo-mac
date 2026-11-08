import Testing
import SwiftUI
@testable import MihomoMac

@Suite("Config editor theme")
struct ConfigEditorThemeTests {

    @Test("Dark theme background is safe for brightness checks")
    func darkThemeUsesConcreteBackgroundColor() {
        let theme = ConfigEditorTheme.make(for: .dark)
        #expect(theme.background.brightnessComponent < 0.5)
    }

    @Test("Light theme background is safe for brightness checks")
    func lightThemeUsesConcreteBackgroundColor() {
        let theme = ConfigEditorTheme.make(for: .light)
        #expect(theme.background.brightnessComponent > 0.5)
    }
}
