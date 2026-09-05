import Foundation
import Security

/// Credentials live in the iOS Keychain, never in UserDefaults or a plain file.
/// They are used only to sign in to the site the user entered them for, from
/// this device — nothing is sent anywhere else.
enum KeychainStore {
    struct Credentials {
        let email: String
        let password: String
    }

    /// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`: readable only while the device
    /// is unlocked, and never migrated to a new device via encrypted backup.
    private static let accessibility = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

    static func save(_ credentials: Credentials, service: String) -> Bool {
        guard let passwordData = credentials.password.data(using: .utf8) else { return false }
        delete(service: service)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: credentials.email,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: accessibility,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load(service: String) -> Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let result = item as? [String: Any],
              let email = result[kSecAttrAccount as String] as? String,
              let data = result[kSecValueData as String] as? Data,
              let password = String(data: data, encoding: .utf8) else { return nil }
        return Credentials(email: email, password: password)
    }

    @discardableResult
    static func delete(service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
