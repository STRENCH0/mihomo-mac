import SwiftUI

struct ModePickerControl: View {
    let selectedMode: OutboundMode?
    let isEnabled: Bool
    let onSelect: (OutboundMode) async -> Bool

    @State private var draft: OutboundMode = .rule
    @State private var latestExternalMode: OutboundMode?

    var body: some View {
        Picker("Mode", selection: $draft) {
            ForEach(OutboundMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .disabled(!isEnabled)
        .onChange(of: selectedMode) { _, newValue in
            if let newValue {
                latestExternalMode = newValue
                draft = newValue
            }
        }
        .onChange(of: draft) { oldValue, newValue in
            guard oldValue != newValue, newValue != latestExternalMode else { return }
            Task {
                let success = await onSelect(newValue)
                if !success {
                    draft = latestExternalMode ?? .rule
                }
            }
        }
        .onAppear {
            let mode = selectedMode ?? .rule
            draft = mode
            latestExternalMode = mode
        }
    }
}
