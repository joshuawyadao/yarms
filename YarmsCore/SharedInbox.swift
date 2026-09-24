import Foundation

struct PendingLink: Codable, Identifiable {
    let id: UUID
    let link: TikTokLink
    let savedAt: Date
}

protocol PendingLinkInbox {
    func load() throws -> [PendingLink]
    func remove(_ id: UUID) throws
}

struct SharedInbox: PendingLinkInbox {
    static let uiTestStoreArgument = "-YarmsUITestStoreID"

    static var isUITestStoreRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestStoreArgument)
    }

    static var liveContainer: URL? {
        container(
            arguments: ProcessInfo.processInfo.arguments,
            applicationSupport: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
            temporaryDirectory: FileManager.default.temporaryDirectory
        )
    }

    static func container(arguments: [String], applicationSupport: URL?, temporaryDirectory: URL) -> URL? {
        if let index = arguments.firstIndex(of: uiTestStoreArgument) {
            guard arguments.indices.contains(index + 1),
                  let identifier = UUID(uuidString: arguments[index + 1]) else { return nil }
            return temporaryDirectory
                .appendingPathComponent("YarmsUITests", isDirectory: true)
                .appendingPathComponent(identifier.uuidString, isDirectory: true)
        }
        return applicationSupport?.appendingPathComponent("Yarms", isDirectory: true)
    }

    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    static func live() -> SharedInbox? {
        guard let container = liveContainer else { return nil }
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

    func remove(_ id: UUID) throws {
        let file = directory.appendingPathComponent(id.uuidString).appendingPathExtension("json")
        if FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
    }
}
