import Foundation
import Security

/// A tiny wrapper over the iOS Keychain (Security framework, no dependencies)
/// for storing small secrets — SSH passwords/keys, camera passwords — instead
/// of leaving them in `UserDefaults` in clear text.
///
/// Items are generic passwords scoped to a per-store `service` string and keyed
/// by an `account` string (typically `"<recordUUID>.<field>"`). They are marked
/// `AfterFirstUnlock` and non-synchronizable, so they stay on this device and
/// survive backgrounding but are never written to iCloud Keychain.
enum KeychainStore {
    /// Namespaces used by the app's stores.
    enum Service: String {
        case ssh = "com.nettoolbox.ssh"
        case camera = "com.nettoolbox.camera"
    }

    private static func baseQuery(_ service: Service, account: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service.rawValue,
            kSecAttrAccount: account,
        ]
    }

    /// Stores (or replaces) a secret. An empty value removes the item, so callers
    /// don't accumulate stale entries when a field is cleared.
    @discardableResult
    static func set(_ value: String, service: Service, account: String) -> Bool {
        guard !value.isEmpty else { return remove(service: service, account: account) }
        let data = Data(value.utf8)
        var query = baseQuery(service, account: account)
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        if updateStatus == errSecItemNotFound {
            query.merge(attributes) { _, new in new }
            return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    /// Reads a secret, or `nil` when none is stored (or the keychain is
    /// unavailable, e.g. in a test bundle without entitlements).
    static func get(service: Service, account: String) -> String? {
        var query = baseQuery(service, account: account)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    @discardableResult
    static func remove(service: Service, account: String) -> Bool {
        let status = SecItemDelete(baseQuery(service, account: account) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Deletes every secret for a service. Used when a store is wholesale
    /// replaced (e.g. restoring a backup) so no orphaned secrets linger.
    static func removeAll(service: Service) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
