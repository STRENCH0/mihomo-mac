import SwiftUI

struct WiFiProxyRulesSection: View {
    @Environment(AppState.self) private var appState
    @State private var newSSID = ""
    @State private var newRuleEnabled = true

    var body: some View {
        Section("Wi-Fi Rules") {
            Toggle("Switch System Proxy by Wi-Fi network", isOn: Binding(
                get: { appState.appConfig.wifiRulesEnabled },
                set: { appState.setWiFiRulesEnabled($0) }
            ))
            if appState.appConfig.wifiRulesEnabled {
                if let ssid = appState.wifiMonitor.ssid {
                    LabeledContent("Current Wi-Fi", value: ssid)
                } else if let message = appState.wifiMonitor.statusMessage {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
                Picker("Other Wi-Fi networks", selection: Binding(
                    get: { appState.appConfig.otherWiFiProxyState },
                    set: { appState.setOtherWiFiProxyState($0) }
                )) {
                    Text("Keep Current").tag(nil as Bool?)
                    Text("On").tag(Optional(true))
                    Text("Off").tag(Optional(false))
                }
                ForEach(appState.appConfig.wifiProxyRules.keys.sorted(), id: \.self) { ssid in
                    HStack {
                        Text(verbatim: ssid)
                        Spacer()
                        actionPicker(for: ssid, selection: Binding(
                            get: { appState.appConfig.wifiProxyRules[ssid] ?? false },
                            set: { appState.setWiFiRule(for: ssid, enabled: $0) }
                        ))
                        Button {
                            appState.setWiFiRule(for: ssid, enabled: nil)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .accessibilityLabel("Remove rule for \(ssid)")
                    }
                }
                HStack {
                    TextField("Network name (SSID)", text: $newSSID)
                        .textFieldStyle(.roundedBorder)
                    if let ssid = appState.wifiMonitor.ssid {
                        Button("Use Current") { newSSID = ssid }
                    }
                    actionPicker(for: "new network", selection: $newRuleEnabled)
                    Button("Add") {
                        appState.setWiFiRule(for: newSSID, enabled: newRuleEnabled)
                        newSSID = ""
                    }
                    .disabled(newSSID.isEmpty || newSSID.utf8.count > 32 || appState.appConfig.wifiProxyRules[newSSID] != nil)
                }
                Text("Rules apply when mihomo starts or the Wi-Fi network changes. A rule for a named network takes priority.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func actionPicker(for network: String, selection: Binding<Bool>) -> some View {
        Picker("System Proxy for \(network)", selection: selection) {
            Text("On").tag(true)
            Text("Off").tag(false)
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .fixedSize()
    }
}
