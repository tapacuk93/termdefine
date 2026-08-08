import Foundation
import Security

/// Storage for the API key the user pastes into the app.
/// The Keychain rather than UserDefaults — a preferences plist is readable by anything
/// running as this user.
enum Keychain {
    private static let service = "com.oeaio.termdefine"
    private static let account = "ANTHROPIC_API_KEY"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.trimmed.isEmpty
        else { return nil }
        return value.trimmed
    }

    @discardableResult
    static func write(_ value: String) -> Bool {
        SecItemDelete(baseQuery as CFDictionary)

        var attributes = baseQuery
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        attributes[kSecAttrLabel as String] = "TermDefine — Anthropic API key"
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
