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

            ContainerOverrideView(monitor: monitor)
                .tabItem {
                    Label("Containers", systemImage: "shippingbox")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(minWidth: 520, minHeight: 420)
    }
}
