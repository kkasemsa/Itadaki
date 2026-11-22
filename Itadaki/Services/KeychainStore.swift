import Foundation
import Security

/// Minimal Keychain wrapper for the API key. Values never leave the device and are
/// never logged.
enum KeychainStore {
    static let apiKeyAccount = "anthropic-api-key"
    private static let service = "net.kktp.itadaki"

    static func string(for account: String) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
            let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Stores `value`, or removes the item when `value` is nil or empty.
    @discardableResult
    static func set(_ value: String?, for account: String) -> Bool {
        let query = baseQuery(account)
        SecItemDelete(query as CFDictionary)
        guard let value, !value.isEmpty else { return true }
        var attributes = query
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    private static func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
