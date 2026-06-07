import Foundation
import Security

/// Securely stores and retrieves SSH passwords in the macOS Keychain.
/// Each password is keyed by server connection ID.
struct KeychainHelper: Sendable {
    private static let serviceName = "com.openstackmenu.OpenStackMenu.ssh"

    /// Stores a password for a server in the Keychain.
    static func storePassword(for serverID: UUID, password: String) -> Bool {
        let account = serverID.uuidString
        let passwordData = password.data(using: .utf8)!

        // First, try to update existing entry
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: passwordData
        ]

        // Delete existing entry if any
        SecItemDelete(query as CFDictionary)

        // Add new entry
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieves a password from the Keychain for a server.
    static func retrievePassword(for serverID: UUID) -> String? {
        let account = serverID.uuidString
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }

        return password
    }

    /// Deletes a password from the Keychain for a server.
    static func deletePassword(for serverID: UUID) -> Bool {
        let account = serverID.uuidString
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
