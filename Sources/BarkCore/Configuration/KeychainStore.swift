import Foundation
import Security

public struct KeychainStore: Sendable {
    private let service: String

    public init(service: String = "app.barkdesk.shared") {
        self.service = service
    }

    public func read(account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return "" }
        guard status == errSecSuccess, let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError(status: status)
        }
        return value
    }

    public func write(_ value: String, account: String) throws {
        let key: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if value.isEmpty {
            let status = SecItemDelete(key as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError(status: status)
            }
            return
        }
        let attributes: [String: Any] = [kSecValueData as String: Data(value.utf8)]
        let updateStatus = SecItemUpdate(key as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var add = key
            add.merge(attributes) { _, new in new }
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
        } else if updateStatus != errSecSuccess {
            throw KeychainError(status: updateStatus)
        }
    }
}

public struct KeychainError: LocalizedError {
    public let status: OSStatus

    public var errorDescription: String? {
        SecCopyErrorMessageString(status, nil) as String? ?? "系统钥匙串错误 \(status)"
    }
}
