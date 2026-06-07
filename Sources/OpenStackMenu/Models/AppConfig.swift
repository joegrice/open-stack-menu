import Foundation

struct AppConfig: Codable, Sendable, Equatable {
    var checkInterval: TimeInterval = 60
    var notifyOnStatusChange: Bool = false
    var launchAtLogin: Bool = false
    var servers: [ServerConnection] = []
    var containerOverrides: [ContainerOverride] = []

    struct ContainerOverride: Identifiable, Codable, Hashable, Sendable {
        var id: String
        var customURL: String?
        var healthCheckPath: String?
        var enabled: Bool = true
        var displayName: String?
    }

    static let defaultConfig = AppConfig()
}
