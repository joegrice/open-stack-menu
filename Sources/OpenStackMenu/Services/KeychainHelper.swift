import Foundation
import Security
import LocalAuthentication

/// Securely stores and retrieves SSH passwords in the macOS Keychain.
/// Each password is keyed by server connection ID.
/// Uses Touch ID (biometric) access control when available.
struct KeychainHelper: Sendable {
    private static let serviceName = "com.openstackmenu.OpenStackMenu.ssh"

    /// Checks if the device supports biometric authentication (Touch ID).
    static var isBiometryAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Stores a password for a server in the Keychain.
    /// Uses Touch ID access control when biometry is available.
    static func storePassword(for serverID: UUID, password: String) -> Bool {
        let account = serverID.uuidString
        let passwordData = password.data(using: .utf8)!

        // Delete existing entry first (access control can only be set at creation)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: passwordData,
        ]

        // Enable Touch ID access control when available
        if isBiometryAvailable {
            var error: Unmanaged<CFError>?
            let accessControl = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .userPresence,
                &error
            )
            if let accessControl {
                query[kSecAttrAccessControl as String] = accessControl
            }
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Checks if a password exists in the Keychain for a server (without retrieving it).
    /// Does not trigger Touch ID prompt — uses LAContext.interactionNotAllowed to check silently.
    static func passwordExists(for serverID: UUID) -> Bool {
        let account = serverID.uuidString

        // Use LAContext with interactionNotAllowed to check without triggering auth UI
        let context = LAContext()
        context.interactionNotAllowed = true

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false,
            kSecUseAuthenticationContext as String: context,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        // errSecSuccess = exists and accessible
        // errSecInteractionNotAllowed = exists but requires auth (Touch ID)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    /// Retrieves a password from the Keychain for a server.
    /// Triggers Touch ID prompt when biometric access control is set.
    static func retrievePassword(for serverID: UUID) -> String? {
        let account = serverID.uuidString

        // Use LAContext with localizedReason for Touch ID prompt
        let context = LAContext()
        context.localizedReason = "Authenticate to retrieve SSH password"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
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
