import AppKit
import CoreLocation
import CoreWLAN

@MainActor
@Observable
final class WiFiMonitor: NSObject, CLLocationManagerDelegate, CWEventDelegate {
    private(set) var ssid: String?
    private(set) var statusMessage: String?
    var onSSIDChanged: ((String?) -> Void)?

    private var location: CLLocationManager?
    private var client: CWWiFiClient?
    private var readTask: Task<Void, Never>?

    func start() {
        guard location == nil else { return }
        let manager = CLLocationManager()
        location = manager
        manager.delegate = self
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(refreshAfterWake), name: NSWorkspace.didWakeNotification, object: nil
        )
        refresh()
    }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        readTask?.cancel()
        readTask = nil
        location?.delegate = nil
        location = nil
        stopMonitoringEvents()
        ssid = nil
        statusMessage = nil
    }

    private func refresh() {
        readTask?.cancel()
        guard let location else { return }
        guard location.authorizationStatus == .authorizedAlways else {
            stopMonitoringEvents()
            statusMessage = "Allow location access in System Settings → Privacy & Security → Location Services to read the Wi-Fi name."
            updateSSID(nil)
            return
        }
        if client == nil {
            let wifi = CWWiFiClient.shared()
            wifi.delegate = self
            do {
                try wifi.startMonitoringEvent(with: .ssidDidChange)
                client = wifi
            } catch {
                wifi.delegate = nil
                statusMessage = "Could not monitor Wi-Fi: \(error.localizedDescription)"
                updateSSID(nil)
                return
            }
        }
        readTask = Task {
            let name = await Self.readSSID()
            guard !Task.isCancelled else { return }
            statusMessage = name == nil ? "Current Wi-Fi network unavailable." : nil
            updateSSID(name)
        }
    }

    @objc private func refreshAfterWake() {
        refresh()
    }

    private nonisolated static func readSSID() async -> String? {
        CWWiFiClient.shared().interface()?.ssid()
    }

    func refreshForKernelStart() {
        ssid = nil
        refresh()
    }

    func updateSSID(_ name: String?) {
        guard ssid != name else { return }
        ssid = name
        onSSIDChanged?(name)
    }

    private func stopMonitoringEvents() {
        try? client?.stopMonitoringEvent(with: .ssidDidChange)
        client?.delegate = nil
        client = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in refresh() }
    }

    nonisolated func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor in refresh() }
    }
}
