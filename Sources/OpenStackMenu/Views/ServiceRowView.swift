import SwiftUI

/// A single row in the menu dropdown representing one Docker container.
struct ServiceRowView: View {
    let container: ContainerInfo
    let status: ContainerStatus
    let healthResult: HealthCheckResult?
    let containerOverride: AppConfig.ContainerOverride?
    let serverHost: String?
    let onOpen: () -> Void

    var body: some View {
        Button {
            onOpen()
        } label: {
            HStack(spacing: 8) {
                StatusIndicatorView(status: status)

                VStack(alignment: .leading, spacing: 1) {
                    Text(displayName)
                        .font(.system(size: 13))
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if status == .degraded {
                        Text(degradedSubtitle)
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let port = container.httpPorts.first {
                    Text(portLabel(for: port))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                        )
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
        if let customName = containerOverride?.displayName,
           !customName.isEmpty {
            return customName
        }
        return container.name
    }

    // MARK: - Port Label

    private func portLabel(for port: ContainerInfo.PortMapping) -> String {
        if let publicPort = port.publicPort {
            return "\(publicPort):\(port.privatePort)"
        }
        return "\(port.privatePort)"
    }

    // MARK: - Degraded Subtitle

    private var degradedSubtitle: String {
        if let result = healthResult {
            return result.errorMessage ?? "Unhealthy"
        }
        return "Unhealthy"
    }

    private var tooltip: String {
        let host = serverHost ?? "unknown"
        let ports = container.httpPorts

        if ports.isEmpty {
            return "\(container.image) — no HTTP port exposed"
        }

        let portList = ports.map { portLabel(for: $0) }.joined(separator: ", ")
        return "http://\(host) — ports: \(portList) — \(container.image)"
    }
}
