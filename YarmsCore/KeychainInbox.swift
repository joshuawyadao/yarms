import Foundation
import Security

enum KeychainInboxError: Error, Equatable {
    case payloadTooLarge
    case unexpectedResult
    case status(OSStatus)
}

/// A small, local handoff queue shared by the app and its Share extension.
/// Workouts and notes stay in the app's file-backed library, never in Keychain.
struct KeychainInbox: PendingLinkInbox {
    private static let maximumEntryBytes = 4_096
    private static let defaultService = "com.joshuawyadao.yarms.pending-links"

    let service: String

    init(service: String = defaultService) {
        self.service = service
    }

    static func live() -> KeychainInbox {
        KeychainInbox()
    }

    @discardableResult
    func save(_ link: TikTokLink) throws -> PendingLink {
        let entry = PendingLink(id: UUID(), link: link, savedAt: Date())
        let data = try JSONEncoder().encode(entry)
        guard data.count <= Self.maximumEntryBytes else { throw KeychainInboxError.payloadTooLarge }
        var query = baseQuery()
        query[kSecAttrAccount as String] = entry.id.uuidString
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainInboxError.status(status) }
        return entry
    }

    func load() throws -> [PendingLink] {
        var query = baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        query[kSecReturnData as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else { throw KeychainInboxError.status(status) }
        guard let dataItems = result as? [Data] else { throw KeychainInboxError.unexpectedResult }
        return try dataItems.map { try JSONDecoder().decode(PendingLink.self, from: $0) }
            .sorted { $0.savedAt > $1.savedAt }
    }

    func remove(_ id: UUID) throws {
        var query = baseQuery()
        query[kSecAttrAccount as String] = id.uuidString
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainInboxError.status(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
    }
}
