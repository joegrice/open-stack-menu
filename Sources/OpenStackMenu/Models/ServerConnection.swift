import Foundation

struct ServerConnection: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var host: String
    var port: UInt16 = 22
    var username: String
    var enabled: Bool = true
    var identityFile: String?
    var usePassword: Bool = false  // When true, password auth is used (stored in Keychain)

    /// SSH connection string in user@host format
    var sshDestination: String {
        "\(username)@\(host)"
    }
}
