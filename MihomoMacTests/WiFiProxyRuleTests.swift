import Foundation
import Testing
@testable import MihomoMac

@Suite("Wi-Fi proxy rules")
struct WiFiProxyRuleTests {
    @Test("Rules preserve both actions and match only the configured network name")
    func persistedRules() throws {
        let suite = "WiFiProxyRuleTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let config = AppConfig(defaults: defaults)
        #expect(!config.wifiRulesEnabled)
        config.wifiProxyRules = ["Home": true, "Office": false]
        #expect(config.wifiProxyState(for: "Home") == nil)
        config.wifiRulesEnabled = true

        let restored = AppConfig(defaults: defaults)
        #expect(restored.wifiProxyState(for: "Home") == true)
        #expect(restored.wifiProxyState(for: "Office") == false)
        #expect(restored.wifiProxyState(for: "home") == nil)
        #expect(restored.wifiProxyState(for: nil) == nil)
        restored.wifiProxyRules["Home"] = nil
        #expect(AppConfig(defaults: defaults).wifiProxyState(for: "Home") == nil)
    }

    @Test("Other Wi-Fi networks use the saved action and named exceptions take priority")
    func otherNetworks() throws {
        let suite = "WiFiProxyRuleTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let config = AppConfig(defaults: defaults)
        config.wifiRulesEnabled = true
        for enabled in [true, false] {
            config.otherWiFiProxyState = enabled
            config.wifiProxyRules = ["Home": !enabled]
            let saved = AppConfig(defaults: defaults)
            #expect(saved.wifiProxyState(for: "Cafe") == enabled)
            #expect(saved.wifiProxyState(for: "Home") == !enabled)
            #expect(saved.wifiProxyState(for: nil) == nil)
            #expect(saved.wifiProxyState(for: "") == nil)
            saved.wifiProxyRules.removeValue(forKey: "Home")
            #expect(saved.wifiProxyState(for: "Home") == enabled)
        }
        config.wifiRulesEnabled = false
        #expect(config.wifiProxyState(for: "Cafe") == nil)
        config.otherWiFiProxyState = nil
        config.wifiRulesEnabled = true
        #expect(AppConfig(defaults: defaults).wifiProxyState(for: "Cafe") == nil)
    }

    @Test("Duplicate updates preserve manual changes and reconnecting reapplies the rule")
    @MainActor func networkTransitions() {
        let monitor = WiFiMonitor()
        var changes: [String?] = []
        monitor.onSSIDChanged = { changes.append($0) }
        for name in ["Home", "Home", "Office", nil, "Office"] {
            monitor.updateSSID(name)
        }
        #expect(changes == ["Home", "Office", nil, "Office"])
        monitor.refreshForKernelStart()
        monitor.updateSSID("Office")
        #expect(changes.last == "Office")
        #expect(changes.count == 5)
    }
}
