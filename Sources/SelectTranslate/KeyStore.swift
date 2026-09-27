import Foundation
import Security

@MainActor enum KeyStore {
    // Legacy namespace retained across the Select Translate rename; never migrate the secret through files.
    private static let base: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "jp.ryota.HoverTranslate.OpenRouter",
        kSecAttrAccount as String: "api-key",
        // This ad-hoc signed personal build uses the login keychain and its app ACL.
        // Synchronizable/data-protection items require properly provisioned signing.
        kSecUseDataProtectionKeychain as String: false,
        kSecAttrSynchronizable as String: false
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
    static func read() throws -> String? {
        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw Failure(status: status, operation: "読み取り") }
        guard let data = item as? Data, let key = String(data: data, encoding: .utf8), !key.isEmpty else {
            throw Failure(status: errSecDecode, operation: "読み取り")
        }
        return key
    }
    static func save(_ key: String) throws {
        let attributes: [String: Any] = [kSecValueData as String: Data(key.utf8)]
        let status = SecItemUpdate(base as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let query = base.merging(attributes) { _, new in new }
            let added = SecItemAdd(query as CFDictionary, nil)
            guard added == errSecSuccess else { throw Failure(status: added) }
        } else if status != errSecSuccess { throw Failure(status: status) }
    }
    static func delete() throws {
        let status = SecItemDelete(base as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure(status: status, operation: "削除") }
    }
    struct Failure: LocalizedError {
        let status: OSStatus
        var operation: String = "保存"
        var errorDescription: String? {
            "キーチェーンの\(operation)ができませんでした（\(status)）。Macのロックとアクセス許可を確認してください。"
        }
    }
}
