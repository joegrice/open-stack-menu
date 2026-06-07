import SwiftUI

/// Per-container override settings: custom URL, health check path, display name, enable/disable.
struct ContainerOverrideView: View {
    @ObservedObject var monitor: ServiceMonitor
    @State private var overrides: [AppConfig.ContainerOverride] = []

    init(monitor: ServiceMonitor) {
        self.monitor = monitor
        _overrides = State(initialValue: monitor.currentConfig.containerOverrides)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if monitor.containers.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(monitor.containers) { container in
                        ContainerOverrideRow(
                            container: container,
                            override: binding(for: container.id),
                            onSave: saveOverrides
                        )
                    }
                }

                HStack {
                    Text("Changes are saved automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(12)
            }
        }
        .onAppear {
            overrides = monitor.currentConfig.containerOverrides
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("No Containers")
                .font(.headline)

            Text("Containers will appear here once you add a server and refresh.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func binding(for containerID: String) -> Binding<AppConfig.ContainerOverride> {
        Binding(
            get: {
                overrides.first(where: { $0.id == containerID })
                    ?? AppConfig.ContainerOverride(id: containerID)
            },
            set: { newValue in
                if let index = overrides.firstIndex(where: { $0.id == containerID }) {
                    overrides[index] = newValue
                } else {
                    overrides.append(newValue)
                }
                saveOverrides()
            }
        )
    }

    private func saveOverrides() {
        // Remove default/no-op overrides
        let meaningful = overrides.filter { override in
            override.customURL != nil ||
            override.healthCheckPath != nil ||
            !override.enabled ||
            override.displayName != nil
        }

        var config = monitor.currentConfig
        config.containerOverrides = meaningful
        monitor.updateConfig(config)
    }
}

// MARK: - Container Override Row

private struct ContainerOverrideRow: View {
    let container: ContainerInfo
    @Binding var override: AppConfig.ContainerOverride
    var onSave: () -> Void

    @State private var customURL: String = ""
    @State private var healthCheckPath: String = ""
    @State private var displayName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                Toggle("", isOn: $override.enabled)
                    .toggleStyle(.switch)
                    .onChange(of: override.enabled) { _, _ in onSave() }

                VStack(alignment: .leading, spacing: 1) {
                    Text(displayName.isEmpty ? container.name : displayName)
                        .font(.system(size: 13, weight: .medium))

                    Text(container.image)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Text("on \(container.serverName)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }

            // Override fields
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Display Name")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)

                    TextField(container.name, text: $displayName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .onChange(of: displayName) { _, newValue in
                            override.displayName = newValue.isEmpty ? nil : newValue
                            onSave()
                        }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom URL")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)

                    TextField(placeholderURL, text: $customURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .onChange(of: customURL) { _, newValue in
                            override.customURL = newValue.isEmpty ? nil : newValue
                            onSave()
                        }
                }
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Health Check Path")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)

                    TextField("/health", text: $healthCheckPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .onChange(of: healthCheckPath) { _, newValue in
                            override.healthCheckPath = newValue.isEmpty ? nil : newValue
                            onSave()
                        }
                }
            }
            .frame(maxWidth: 250)
        }
        .padding(.vertical, 4)
        .onAppear {
            customURL = override.customURL ?? ""
            healthCheckPath = override.healthCheckPath ?? ""
            displayName = override.displayName ?? ""
        }
    }

    private var placeholderURL: String {
        if let port = container.bestPort {
            return "http://\(container.serverName):\(port)"
        }
        return "http://server:port"
    }
}
