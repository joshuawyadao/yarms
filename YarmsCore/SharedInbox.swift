import Foundation

struct PendingLink: Codable, Identifiable {
    let id: UUID
    let link: TikTokLink
    let savedAt: Date
}

struct SharedInbox {
    static let appGroup = "group.com.joshuawyadao.yarms"

    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    static func live() -> SharedInbox? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            return nil
        }
        return SharedInbox(directory: container.appendingPathComponent("Inbox", isDirectory: true))
    }

    @discardableResult
    func save(_ link: TikTokLink) throws -> PendingLink {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let entry = PendingLink(id: UUID(), link: link, savedAt: Date())
        let destination = directory.appendingPathComponent(entry.id.uuidString).appendingPathExtension("json")
        try JSONEncoder().encode(entry).write(to: destination, options: .atomic)
        return entry
    }

    func load() throws -> [PendingLink] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        return files.compactMap { file in
            guard let data = try? Data(contentsOf: file) else { return nil }
            return try? JSONDecoder().decode(PendingLink.self, from: data)
        }
            .sorted { $0.savedAt > $1.savedAt }
    }
}
