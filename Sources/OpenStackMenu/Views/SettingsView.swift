import SwiftUI

/// Settings window container with tab navigation.
struct SettingsView: View {
    @ObservedObject var monitor: ServiceMonitor

    var body: some View {
        TabView {
            GeneralSettingsView(monitor: monitor)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ServersSettingsView(monitor: monitor)
                .tabItem {
                    Label("Servers", systemImage: "server.rack")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(minWidth: 440, idealWidth: 440, minHeight: 320, idealHeight: 320)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
