import Foundation
import Security

struct StoredSession: Codable {
    let accessToken: String
    let refreshToken: String
}

protocol SessionVault {
    func read() throws -> StoredSession?
    func save(_ session: StoredSession) throws
    func clear()
}

struct KeychainSessionVault: SessionVault {
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.humanhydration.supabase",
         kSecAttrAccount as String: "session"]
    }
    func read() throws -> StoredSession? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw VaultError.unavailable }
        return try JSONDecoder().decode(StoredSession.self, from: data)
    }
    func save(_ session: StoredSession) throws {
        let data = try JSONEncoder().encode(session)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw VaultError.unavailable }
        } else if status != errSecSuccess { throw VaultError.unavailable }
    }
    func clear() { SecItemDelete(query as CFDictionary) }
    private enum VaultError: LocalizedError {
        case unavailable
        var errorDescription: String? { "Your session couldn’t be stored securely. Please try again." }
    }
}
