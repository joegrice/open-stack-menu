import Foundation

struct ContainerInfo: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var image: String
    var state: String
    var status: String
    var ports: [PortMapping]
    var composeProject: String?
    var labels: [String: String]
    var serverID: UUID
    var serverName: String

    var displayName: String { name }

    /// Only TCP ports
    var httpPorts: [PortMapping] {
        ports.filter { $0.type == "tcp" }
    }

    /// Best guess URL port: first TCP public port, or first TCP private port
    var bestPort: Int? {
        httpPorts.first?.publicPort ?? httpPorts.first?.privatePort
    }

    struct PortMapping: Codable, Hashable, Sendable {
        var ip: String?
        var privatePort: Int
        var publicPort: Int?
        var type: String
    }
}
