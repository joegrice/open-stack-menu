import SwiftUI

/// The root SwiftUI app. Launched from main.swift (not @main).
struct OpenStackMenuApp: App {
    @StateObject private var monitor: ServiceMonitor

    init() {
        let config = ConfigurationManager.shared.loadConfig()
        let monitor = ServiceMonitor(config: config)
        _monitor = StateObject(wrappedValue: monitor)
        monitor.startMonitoring()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(monitor: monitor)
                .frame(minWidth: 280, maxWidth: 360)
        } label: {
            menuBarLabel
                .contextMenu {
                    Button("Refresh All") {
                        monitor.refreshAll()
                    }
                    .disabled(monitor.isRefreshing)

                    SettingsLink {
                        Text("Settings...")
                    }

                    Divider()

                    Button("Quit Open Stack Menu") {
                        NSApplication.shared.terminate(nil)
                    }
                }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(monitor: monitor)
        }
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        HStack(spacing: 2) {
            Image(systemName: overallStatusIcon)
                .font(.system(size: 14))

            if monitor.totalServices > 0 {
                Text("\(monitor.onlineCount)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .offset(y: -1)
            }
        }
    }

    private var overallStatusIcon: String {
        if monitor.isRefreshing {
            return "arrow.triangle.2.circlepath"
        }
        if monitor.errorMessage != nil && monitor.onlineCount == 0 {
            return "exclamationmark.triangle"
        }
        return "server.rack"
    }
}
