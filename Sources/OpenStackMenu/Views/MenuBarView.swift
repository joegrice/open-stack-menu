import AppKit
import SwiftUI

/// The dropdown content shown when clicking the menu bar icon.
struct MenuBarView: View {
    @ObservedObject var monitor: ServiceMonitor

    var body: some View {
        Group {
            if monitor.containers.isEmpty && monitor.errorMessage == nil && !monitor.isRefreshing {
                emptyState
            } else if let error = monitor.errorMessage, monitor.containers.isEmpty {
                errorState(error)
            } else {
                containerList
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("No Servers Configured")
                .font(.headline)

            Text("Add your home server to start monitoring Docker containers.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            SettingsLink {
                Text("Add Server...")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error State

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)

            Text("Connection Error")
                .font(.headline)

            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            HStack(spacing: 8) {
                Button("Retry") {
                    monitor.refreshAll()
                }
                .keyboardShortcut("r")

                if let serverID = serverWithPasswordError {
                    Button("Set Password…") {
                        promptForPassword(serverID: serverID)
                    }
                }
            }

            SettingsLink {
                Text("Settings...")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }

    /// Finds the first server that has a password-related error.
    private var serverWithPasswordError: UUID? {
        guard let error = monitor.errorMessage else { return nil }
        if error.contains("no password stored") || error.contains("Password authentication") {
            if let colonIndex = error.firstIndex(of: ":") {
                let serverName = error[..<colonIndex].trimmingCharacters(in: .whitespaces)
                return monitor.currentConfig.servers.first { $0.name == serverName }?.id
            }
        }
        return nil
    }

    /// Shows an NSAlert to collect and store an SSH password.
    private func promptForPassword(serverID: UUID) {
        guard let server = monitor.currentConfig.servers.first(where: { $0.id == serverID }) else { return }

        // Activate the app so the alert appears in front
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Enter SSH Password"
        alert.informativeText = "For \(server.name) (\(server.username)@\(server.host))"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 22))
        field.placeholderString = "Password"
        alert.accessoryView = field

        let response = alert.runModal()
        if response == .alertFirstButtonReturn, !field.stringValue.isEmpty {
            let success = KeychainHelper.storePassword(for: serverID, password: field.stringValue)
            if success {
                monitor.refreshAll()
            }
            // If it failed, the KeychainHelper already logged the error.
            // Don't show another alert — just let the user retry.
        }
    }

    // MARK: - Container List

    private var containerList: some View {
        // Snapshot all data needed by child views to break the observation chain.
        // Passing @ObservedObject down causes infinite render loops in menu bar apps.
        let grouped = monitor.groupedContainers
        let statuses = monitor.statuses
        let healthResults = monitor.healthResults
        let overrides = monitor.currentConfig.containerOverrides
        let servers = monitor.currentConfig.servers

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(grouped, id: \.0) { group, containers in
                GroupSection(
                    title: group,
                    containers: containers,
                    statuses: statuses,
                    healthResults: healthResults,
                    overrides: overrides,
                    servers: servers,
                    onOpen: { monitor.openContainer($0) }
                )
            }

            Divider()

            bottomBar
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 2) {
            Button {
                monitor.refreshAll()
            } label: {
                HStack {
                    if monitor.isRefreshing {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Refresh All")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(monitor.isRefreshing)
            .keyboardShortcut("r")
            .buttonStyle(.borderless)

            lastRefreshText
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 4)

            Divider()

            SettingsLink {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings...")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .keyboardShortcut(",", modifiers: .command)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit Open Stack Menu")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .keyboardShortcut("q", modifiers: .command)
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var lastRefreshText: some View {
        if let lastRefresh = monitor.lastRefreshTime {
            Text("Updated \(lastRefresh, style: .relative) ago")
        } else {
            Text("Not yet refreshed")
        }
    }

}

// MARK: - Group Section

private struct GroupSection: View {
    let title: String
    let containers: [ContainerInfo]
    let statuses: [String: ContainerStatus]
    let healthResults: [String: HealthCheckResult]
    let overrides: [AppConfig.ContainerOverride]
    let servers: [ServerConnection]
    let onOpen: (ContainerInfo) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

            ForEach(containers) { container in
                let status = statuses[container.id] ?? .unknown
                let healthResult = healthResults[container.id]
                let containerOverride = overrides.first { $0.id == container.id }
                let serverHost = servers.first { $0.id == container.serverID }?.host

                ServiceRowView(
                    container: container,
                    status: status,
                    healthResult: healthResult,
                    containerOverride: containerOverride,
                    serverHost: serverHost,
                    onOpen: { onOpen(container) }
                )
            }

            Divider().padding(.top, 2)
        }
    }
}
