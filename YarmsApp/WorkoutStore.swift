import Foundation

struct WorkoutStore {
    enum StoreError: Error {
        case unsupportedVersion
    }

    private struct LibraryFile: Codable {
        let schemaVersion: Int
        var workouts: [Workout]
    }

    private let fileURL: URL
    private let inbox: SharedInbox

    init(fileURL: URL, inbox: SharedInbox) {
        self.fileURL = fileURL
        self.inbox = inbox
    }

    static func live() -> WorkoutStore? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedInbox.appGroup
        ) else { return nil }
        return WorkoutStore(
            fileURL: container.appendingPathComponent("Library.json"),
            inbox: SharedInbox(directory: container.appendingPathComponent("Inbox", isDirectory: true))
        )
    }

    func load() throws -> [Workout] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let library = try JSONDecoder().decode(LibraryFile.self, from: data)
        guard library.schemaVersion == 1 else { throw StoreError.unsupportedVersion }
        return library.workouts.sorted { $0.savedAt > $1.savedAt }
    }

    @discardableResult
    func importPending() throws -> [Workout] {
        var workouts = try load()
        for pending in try inbox.load().reversed() {
            let duplicate = workouts.contains { workout in
                workout.sourceLink.url == pending.link.url ||
                (pending.link.videoID != nil && workout.playbackLink.videoID == pending.link.videoID)
            }
            if !duplicate {
                workouts.append(Workout(id: pending.id, sourceLink: pending.link, savedAt: pending.savedAt))
                try save(workouts)
            }
            try inbox.remove(pending.id)
        }
        return workouts.sorted { $0.savedAt > $1.savedAt }
    }

    func applyEnrichment(_ enrichment: TikTokEnrichment, to id: UUID) throws {
        var workouts = try load()
        guard let index = workouts.firstIndex(where: { $0.id == id }) else { return }
        var changed = false
        if let resolvedLink = enrichment.resolvedLink, resolvedLink.videoID != nil {
            workouts[index].resolvedLink = resolvedLink
            changed = true
        }
        if let metadata = enrichment.metadata {
            if let title = metadata.title, !title.isEmpty {
                workouts[index].title = title
                changed = true
            }
            if let creator = metadata.creator, !creator.isEmpty {
                workouts[index].creator = creator
                changed = true
            }
            if let thumbnailURL = metadata.thumbnailURL {
                workouts[index].thumbnailURL = thumbnailURL
                changed = true
            }
        }
        if changed { try save(workouts) }
    }

    func remove(_ id: UUID) throws {
        let workouts = try load().filter { $0.id != id }
        try save(workouts)
    }

    private func save(_ workouts: [Workout]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(LibraryFile(schemaVersion: 1, workouts: workouts))
        try data.write(to: fileURL, options: .atomic)
    }
}
