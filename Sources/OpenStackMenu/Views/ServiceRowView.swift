import SwiftUI

/// A single row in the menu dropdown representing one Docker container.
struct ServiceRowView: View {
    let container: ContainerInfo
    let status: ContainerStatus
    @ObservedObject var monitor: ServiceMonitor

    var body: some View {
        Button {
            monitor.openContainer(container)
        } label: {
            HStack(spacing: 8) {
                StatusIndicatorView(status: status)

                VStack(alignment: .leading, spacing: 1) {
                    Text(displayName)
                        .font(.system(size: 13))
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let port = container.bestPort, status == .online {
                    Text(":\(port)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private var displayName: String {
        if let override = monitor.currentConfig.containerOverrides.first(where: { $0.id == container.id }),
           let customName = override.displayName,
           !customName.isEmpty {
            return customName
        }
        return container.name
    }

    private var subtitle: String {
        if status == .degraded {
            if let result = monitor.healthResults[container.id] {
                return result.errorMessage ?? "Unhealthy"
            }
            return "Unhealthy"
        }
        return container.status
    }

    private var tooltip: String {
        let serverHost: String
        if let server = monitor.currentConfig.servers.first(where: { $0.id == container.serverID }) {
            serverHost = server.host
        } else {
            serverHost = "unknown"
        }

        if let port = container.bestPort {
            return "http://\(serverHost):\(port) — \(container.image)"
        }
        return "\(container.image) — no HTTP port exposed"
    }
}
