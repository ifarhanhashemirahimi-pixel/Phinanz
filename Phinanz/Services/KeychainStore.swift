//
//  KeychainStore.swift
//  Phinanz
//
//  Minimal Keychain wrapper for the Gemini API key.
//

import Foundation
import Security

enum KeychainStore {
    private static let service = "Farhan.Phinanz"

    private static func baseQuery(for account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    /// Stores `value` (replacing any previous one). An empty value removes the item.
    @discardableResult
    static func set(_ value: String, for account: String) -> Bool {
        let query = baseQuery(for: account)
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return true }

        var attributes = query
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    static func get(_ account: String) -> String? {
        var query = baseQuery(for: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
