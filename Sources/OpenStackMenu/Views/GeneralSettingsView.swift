import SwiftUI
import ServiceManagement

/// General app settings tab.
struct GeneralSettingsView: View {
    @ObservedObject var monitor: ServiceMonitor
    @State private var checkInterval: TimeInterval
    @State private var notifyOnStatusChange: Bool
    @State private var launchAtLogin: Bool

    private let intervals: [(TimeInterval, String)] = [
        (15, "15 seconds"),
        (30, "30 seconds"),
        (60, "1 minute"),
        (120, "2 minutes"),
        (300, "5 minutes")
    ]

    init(monitor: ServiceMonitor) {
        self.monitor = monitor
        let config = monitor.currentConfig
        _checkInterval = State(initialValue: config.checkInterval)
        _notifyOnStatusChange = State(initialValue: config.notifyOnStatusChange)
        _launchAtLogin = State(initialValue: config.launchAtLogin)
    }

    var body: some View {
        Form {
            Section {
                Picker("Check every", selection: $checkInterval) {
                    ForEach(intervals, id: \.0) { interval, label in
                        Text(label).tag(interval)
                    }
                }
                .onChange(of: checkInterval) { _, newValue in
                    saveSettings()
                }

                Text("How often to poll your Docker servers for container status.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Refresh")
            }

            Section {
                Toggle("Notify when container status changes", isOn: $notifyOnStatusChange)
                    .onChange(of: notifyOnStatusChange) { _, _ in
                        saveSettings()
                    }
            } header: {
                Text("Notifications")
            }

            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                        saveSettings()
                    }
            } header: {
                Text("Startup")
            }
        }
        .formStyle(.columns)
    }

    private func saveSettings() {
        var config = monitor.currentConfig
        config.checkInterval = checkInterval
        config.notifyOnStatusChange = notifyOnStatusChange
        config.launchAtLogin = launchAtLogin
        monitor.updateConfig(config)
    }

    private func setLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }
}
