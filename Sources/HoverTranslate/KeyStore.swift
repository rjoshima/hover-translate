import Foundation
import Security

@MainActor enum KeyStore {
    private static let base: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "jp.ryota.HoverTranslate.OpenRouter",
        kSecAttrAccount as String: "api-key"
    ]
    /// Check metadata only; do not read or display the secret during launch.
    static func isConfigured() -> Bool {
        var query = base
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess { return true }
        if status == errSecItemNotFound { return false }
        // A locked/unavailable keychain must not make a saved key look deleted.
        return UserDefaults.standard.bool(forKey: "hasKey")
    }
    static func read() -> String? {
        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ key: String) throws {
        let attributes: [String: Any] = [kSecValueData as String: Data(key.utf8)]
        let status = SecItemUpdate(base as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var query = base.merging(attributes) { _, new in new }
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let added = SecItemAdd(query as CFDictionary, nil)
            guard added == errSecSuccess else { throw Failure(status: added) }
        } else if status != errSecSuccess { throw Failure(status: status) }
    }
    static func delete() throws {
        let status = SecItemDelete(base as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure(status: status) }
    }
    struct Failure: LocalizedError {
        let status: OSStatus
        var errorDescription: String? { "キーチェーンに保存できませんでした（\(status)）。" }
    }
}
