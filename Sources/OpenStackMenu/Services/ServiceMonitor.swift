import AppKit
import Foundation
import SwiftUI
import os

/// Central state manager for the app. Runs on the main actor since it feeds SwiftUI views.
@MainActor
final class ServiceMonitor: ObservableObject {
    // MARK: - Published State

    @Published var containers: [ContainerInfo] = []
    @Published var statuses: [String: ContainerStatus] = [:]
    @Published var healthResults: [String: HealthCheckResult] = [:]
    @Published var isRefreshing: Bool = false
    @Published var lastRefreshTime: Date?
    @Published var errorMessage: String?

    // MARK: - Private

    private var config: AppConfig
    private let dockerClient: DockerAPIClient
    private let healthChecker: HealthChecker
    private var refreshTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.openstackmenu.OpenStackMenu", category: "ServiceMonitor")
    private var wakeObserver: NSObjectProtocol?

    // MARK: - Computed

    var onlineCount: Int {
        statuses.values.filter { $0 == .online }.count
    }

    var totalServices: Int {
        containers.count
    }

    /// Services visible in the menu (not disabled via overrides)
    var enabledContainers: [ContainerInfo] {
        containers.filter { container in
            if let override = config.containerOverrides.first(where: { $0.id == container.id }) {
                return override.enabled
            }
            return true
        }
    }

    /// Grouped by Compose project, then alphabetically within each group
    var groupedContainers: [(String, [ContainerInfo])] {
        let grouped = Dictionary(grouping: enabledContainers) { container in
            container.composeProject ?? "General"
        }
        return grouped
            .map { ($0.key, $0.value.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) }
            .sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
    }

    // MARK: - Init

    init(config: AppConfig,
         dockerClient: DockerAPIClient = DockerAPIClient(),
         healthChecker: HealthChecker = HealthChecker()) {
        self.config = config
        self.dockerClient = dockerClient
        self.healthChecker = healthChecker
    }

    // MARK: - Public Methods

    func startMonitoring() {
        guard !config.servers.isEmpty else {
            logger.info("No servers configured, skipping monitoring.")
            return
        }
        logger.info("Starting monitoring with interval \(self.config.checkInterval) seconds.")
        refreshTask?.cancel()
        refreshTask = Task { await performRefresh() }
        scheduleNextRefresh()
        registerForWakeNotification()
    }

    func stopMonitoring() {
        timerTask?.cancel()
        timerTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        unregisterFromWakeNotification()
        logger.info("Monitoring stopped.")
    }

    func refreshAll() {
        refreshTask?.cancel()
        refreshTask = Task { await performRefresh() }
    }

    func openContainer(_ container: ContainerInfo) {
        guard let url = buildServiceURL(for: container) else {
            logger.warning("No URL available for container \(container.name)")
            return
        }
        logger.info("Opening \(url.absoluteString)")
        NSWorkspace.shared.open(url)
    }

    func addServer(_ server: ServerConnection) {
        config.servers.append(server)
        saveConfig()
        startMonitoring()
    }

    func removeServer(_ serverID: UUID) {
        config.servers.removeAll { $0.id == serverID }
        saveConfig()
        containers.removeAll { $0.serverID == serverID }
        for key in statuses.keys {
            if containers.first(where: { $0.id == key }) == nil {
                statuses.removeValue(forKey: key)
            }
        }
        if config.servers.isEmpty {
            stopMonitoring()
            containers = []
            statuses = [:]
            errorMessage = nil
        } else {
            refreshAll()
        }
    }

    func updateServer(_ server: ServerConnection) {
        guard let index = config.servers.firstIndex(where: { $0.id == server.id }) else { return }
        config.servers[index] = server
        saveConfig()
        refreshAll()
    }

    /// Replaces the entire config, saves it, and restarts monitoring if the server list changed.
    func updateConfig(_ newConfig: AppConfig) {
        let serversChanged = newConfig.servers != config.servers
        config = newConfig
        saveConfig()

        if serversChanged {
            // Server list changed — full reset needed
            refreshAll()
        } else if newConfig.checkInterval != config.checkInterval {
            // Just restart the timer with the new interval
            scheduleNextRefresh()
        }
        // For container overrides or notification toggles: no action needed,
        // changes are reflected in config immediately
    }

    /// Returns the current config (for settings views to edit)
    var currentConfig: AppConfig { config }

    /// Persists current config to disk.
    func saveConfig() {
        do {
            try ConfigurationManager.shared.saveConfig(config)
        } catch {
            logger.error("Failed to save config: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private func registerForWakeNotification() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.logger.info("System woke from sleep — restarting monitoring to clear stale connections")
                self?.startMonitoring()
            }
        }
    }

    private func unregisterFromWakeNotification() {
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            wakeObserver = nil
        }
    }

    private func performRefresh() async {
        guard !config.servers.isEmpty else { return }

        isRefreshing = true
        errorMessage = nil
        var allContainers: [ContainerInfo] = []
        var newStatuses: [String: ContainerStatus] = [:]
        var errors: [String] = []

        let enabledServers = config.servers.filter(\.enabled)

        // Initially set all known containers to .checking
        for container in containers {
            newStatuses[container.id] = .checking
        }

        do {
            try await withThrowingTaskGroup(
                of: (server: ServerConnection, result: Result<[DockerContainerJSON], Error>).self
            ) { group in
                for server in enabledServers {
                    group.addTask {
                        do {
                            let containers = try await self.dockerClient.listContainers(on: server)
                            return (server, .success(containers))
                        } catch {
                            return (server, .failure(error))
                        }
                    }
                }

                for try await (server, result) in group {
                    try Task.checkCancellation()

                    switch result {
                    case .success(let dockerContainers):
                        let serverContainers = dockerClient.toContainerInfo(dockerContainers, server: server)
                        allContainers.append(contentsOf: serverContainers)

                        for container in serverContainers {
                            let baseStatus: ContainerStatus
                            switch container.state {
                            case "running":
                                baseStatus = .online
                            case "paused":
                                baseStatus = .degraded
                            case "restarting":
                                baseStatus = .restarting
                            default:
                                baseStatus = .offline
                            }
                            newStatuses[container.id] = baseStatus
                        }
                    case .failure(let error):
                        errors.append("\(server.name): \(error.localizedDescription)")
                        for container in containers where container.serverID == server.id {
                            newStatuses[container.id] = .offline
                        }
                    }
                }
            }
        } catch is CancellationError {
            isRefreshing = false
            scheduleNextRefresh()
            return
        } catch {
            // If the task group itself fails (unlikely), mark all servers as error
            for server in enabledServers {
                errors.append("\(server.name): \(error.localizedDescription)")
                for container in containers where container.serverID == server.id {
                    newStatuses[container.id] = .offline
                }
            }
        }

        try? Task.checkCancellation()
        if Task.isCancelled {
            isRefreshing = false
            scheduleNextRefresh()
            return
        }

        // Run optional HTTP health checks for running containers with health paths
        await performHealthChecks(for: allContainers, statuses: &newStatuses)

        try? Task.checkCancellation()
        if Task.isCancelled {
            isRefreshing = false
            scheduleNextRefresh()
            return
        }

        // Update published state
        self.containers = allContainers
        self.statuses = newStatuses
        self.lastRefreshTime = Date()

        logger.info("Refresh complete: \(allContainers.count) containers, \(newStatuses.count) statuses")
        if !allContainers.isEmpty {
            logger.info("Container names: \(allContainers.map(\.name).joined(separator: ", "))")
        }

        if errors.isEmpty {
            errorMessage = nil
        } else {
            errorMessage = errors.joined(separator: "\n")
        }

        isRefreshing = false
        scheduleNextRefresh()
    }

    private func performHealthChecks(
        for containers: [ContainerInfo],
        statuses: inout [String: ContainerStatus]
    ) async {
        let containersToCheck = containers.filter { container in
            guard container.state == "running" else { return false }
            guard let override = config.containerOverrides.first(where: { $0.id == container.id }),
                  let healthPath = override.healthCheckPath,
                  !healthPath.isEmpty else {
                return false
            }
            return true
        }

        guard !containersToCheck.isEmpty else { return }

        await withTaskGroup(of: (containerID: String, result: HealthCheckResult).self) { group in
            for container in containersToCheck {
                guard let url = buildServiceURL(for: container) else { continue }
                let healthPath = config.containerOverrides
                    .first(where: { $0.id == container.id })?
                    .healthCheckPath ?? ""

                group.addTask {
                    var result = await self.healthChecker.check(
                        url: url,
                        timeout: 10,
                        additionalPath: healthPath
                    )
                    result.containerID = container.id
                    return (container.id, result)
                }
            }

            for await (containerID, result) in group {
                if Task.isCancelled { break }
                healthResults[containerID] = result
                if !result.isHealthy {
                    statuses[containerID] = .degraded
                }
            }
        }
    }

    private func buildServiceURL(for container: ContainerInfo) -> URL? {
        // Check for custom URL override
        if let override = config.containerOverrides.first(where: { $0.id == container.id }),
           let customURL = override.customURL,
           !customURL.isEmpty {
            return URL(string: customURL)
        }

        // Find the server this container belongs to
        guard let server = config.servers.first(where: { $0.id == container.serverID }) else {
            return nil
        }

        // Build URL from server host + container port
        guard let port = container.bestPort else { return nil }

        var components = URLComponents()
        components.scheme = "http"
        // Wrap IPv6 addresses in brackets
        if server.host.contains(":") {
            components.host = "[\(server.host)]"
        } else {
            components.host = server.host
        }
        components.port = port
        return components.url
    }

    private func scheduleNextRefresh() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            guard let self else { return }
            let interval = UInt64(self.config.checkInterval * 1_000_000_000)
            try? await Task.sleep(nanoseconds: interval)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                guard !self.isRefreshing else {
                    self.logger.warning("Skipping scheduled refresh — previous refresh still in progress")
                    self.scheduleNextRefresh()
                    return
                }
                self.refreshTask?.cancel()
                self.refreshTask = Task { await self.performRefresh() }
            }
        }
    }
}
