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

    /// Only TCP ports, deduplicated by (publicPort, privatePort).
    /// Docker often publishes the same port over both IPv4 and IPv6,
    /// producing duplicate entries — we keep only the first.
    var httpPorts: [PortMapping] {
        var seen = Set<String>()
        return ports.filter { $0.type == "tcp" }.filter { mapping in
            let key = "\(mapping.publicPort ?? -1):\(mapping.privatePort)"
            return seen.insert(key).inserted
        }
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
