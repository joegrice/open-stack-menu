import SwiftUI

/// A single row in the menu dropdown representing one Docker container.
struct ServiceRowView: View {
    let container: ContainerInfo
    let status: ContainerStatus
    let healthResult: HealthCheckResult?
    let containerOverride: AppConfig.ContainerOverride?
    let serverHost: String?
    let onOpen: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button {
            onOpen()
        } label: {
            HStack(spacing: 6) {
                Text(status.emoji)
                    .font(.system(size: 10))

                Text(displayName)
                    .font(.system(size: 13))
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                if !container.httpPorts.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(container.httpPorts, id: \.self) { port in
                            Text(portLabel(for: port))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(isHovering
                                              ? Color.accentColor.opacity(0.25)
                                              : Color.secondary.opacity(0.3))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(
                                            isHovering ? Color.accentColor.opacity(0.6) : .clear,
                                            lineWidth: 1
                                        )
                                )
                        }
                    }
                }

                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 9))
                    .foregroundStyle(isHovering ? .primary : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
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
