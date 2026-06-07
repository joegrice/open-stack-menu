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

            Button("Retry") {
                monitor.refreshAll()
            }
            .keyboardShortcut("r")

            SettingsLink {
                Text("Settings...")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Container List

    private var containerList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(monitor.groupedContainers, id: \.0) { group, containers in
                GroupSection(
                    title: group,
                    containers: containers,
                    monitor: monitor
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
    @ObservedObject var monitor: ServiceMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

            ForEach(containers) { container in
                ServiceRowView(
                    container: container,
                    status: monitor.statuses[container.id] ?? .unknown,
                    monitor: monitor
                )
            }

            Divider().padding(.top, 2)
        }
    }
}
