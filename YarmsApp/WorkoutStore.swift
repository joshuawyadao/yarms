import Foundation

struct WorkoutStore {
    // Enrichment, inbox import, note edits, and restore all read then replace the library.
    // One app-process lock prevents a later writer from dropping another writer's changes.
    private static let accessLock = NSRecursiveLock()

    enum StoreError: Error {
        case unsupportedVersion
    }

    private struct LibraryFile: Codable {
        let schemaVersion: Int
        var workouts: [Workout]
    }

    private let fileURL: URL
    private let inbox: SharedInbox
    private let shareInbox: (any PendingLinkInbox)?

    init(fileURL: URL, inbox: SharedInbox, shareInbox: (any PendingLinkInbox)? = nil) {
        self.fileURL = fileURL
        self.inbox = inbox
        self.shareInbox = shareInbox
    }

    static func live() -> WorkoutStore? {
        guard let container = SharedInbox.liveContainer else { return nil }
        return WorkoutStore(
            fileURL: container.appendingPathComponent("Library.json"),
            inbox: SharedInbox(directory: container.appendingPathComponent("Inbox", isDirectory: true)),
            shareInbox: KeychainInbox.live()
        )
    }

    func load() throws -> [Workout] {
        Self.accessLock.lock()
        defer { Self.accessLock.unlock() }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let library = try JSONDecoder().decode(LibraryFile.self, from: data)
        guard library.schemaVersion == 1 else { throw StoreError.unsupportedVersion }
        return library.workouts.sorted { $0.savedAt > $1.savedAt }
    }

    @discardableResult
    func importPending() throws -> [Workout] {
        Self.accessLock.lock()
        defer { Self.accessLock.unlock() }
        var workouts = try load()
        try importPending(from: inbox, into: &workouts)
        if let shareInbox {
            try importPending(from: shareInbox, into: &workouts)
        }
        return workouts.sorted { $0.savedAt > $1.savedAt }
    }

    private func importPending(from inbox: any PendingLinkInbox, into workouts: inout [Workout]) throws {
        for pending in try inbox.load().reversed() {
            let duplicate = workouts.contains { workout in
                workout.sourceLink.url == pending.link.url ||
                workout.sourceAliases?.contains(where: { $0.url == pending.link.url }) == true ||
                (pending.link.videoID != nil && workout.playbackLink.videoID == pending.link.videoID)
            }
            if !duplicate {
                workouts.append(Workout(id: pending.id, sourceLink: pending.link, savedAt: pending.savedAt))
                try save(workouts)
            }
            try inbox.remove(pending.id)
        }
    }

    func applyEnrichment(_ enrichment: TikTokEnrichment, to id: UUID) throws {
        Self.accessLock.lock()
        defer { Self.accessLock.unlock() }
        var workouts = try load()
        let index = workouts.firstIndex(where: { $0.id == id }) ??
            enrichment.resolvedLink?.videoID.flatMap { videoID in
                workouts.firstIndex { $0.playbackLink.videoID == videoID }
            }
        guard let index else { return }
        var changed = false
        if let resolvedLink = enrichment.resolvedLink, resolvedLink.videoID != nil {
            workouts[index].resolvedLink = resolvedLink
            changed = true
        }
        if let metadata = enrichment.metadata {
            if workouts[index].title == nil, let title = metadata.title, !title.isEmpty {
                workouts[index].title = title
                changed = true
            }
            if workouts[index].creator == nil, let creator = metadata.creator, !creator.isEmpty {
                workouts[index].creator = creator
                changed = true
            }
            if workouts[index].thumbnailURL == nil, let thumbnailURL = metadata.thumbnailURL {
                workouts[index].thumbnailURL = thumbnailURL
                changed = true
            }
        }
        if let videoID = workouts[index].playbackLink.videoID {
            changed = coalesceDuplicates(in: &workouts, for: videoID) || changed
        }
        if changed { try save(workouts) }
    }

    private func coalesceDuplicates(in workouts: inout [Workout], for videoID: String) -> Bool {
        let matches = workouts.filter { $0.playbackLink.videoID == videoID }.sorted {
            $0.savedAt == $1.savedAt
                ? $0.id.uuidString < $1.id.uuidString
                : $0.savedAt < $1.savedAt
        }
        guard matches.count > 1 else { return false }

        // Keep the first save's identity, and fill its missing details from later saves.
        var keeper = matches[0]
        var notes = [String]()
        var aliases = Set(keeper.sourceAliases ?? [])
        for match in matches {
            aliases.insert(match.sourceLink)
            aliases.formUnion(match.sourceAliases ?? [])
            if let note = match.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
               !note.isEmpty, !notes.contains(note) {
                notes.append(note)
            }
            if match.id == keeper.id { continue }
            if keeper.title == nil { keeper.title = match.title }
            if keeper.creator == nil { keeper.creator = match.creator }
            if keeper.thumbnailURL == nil { keeper.thumbnailURL = match.thumbnailURL }
        }
        keeper.notes = notes.isEmpty ? nil : notes.joined(separator: "\n\n")
        aliases.remove(keeper.sourceLink)
        keeper.sourceAliases = aliases.isEmpty ? nil : aliases.sorted { $0.url.absoluteString < $1.url.absoluteString }
        workouts.removeAll { $0.playbackLink.videoID == videoID }
        workouts.append(keeper)
        return true
    }

    @discardableResult
    func updateNotes(_ text: String, for id: UUID) throws -> Bool {
        Self.accessLock.lock()
        defer { Self.accessLock.unlock() }
        var workouts = try load()
        guard let index = workouts.firstIndex(where: { $0.id == id }) else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        workouts[index].notes = trimmed.isEmpty ? nil : trimmed
        try save(workouts)
        return true
    }

    func remove(_ id: UUID) throws {
        Self.accessLock.lock()
        defer { Self.accessLock.unlock() }
        let workouts = try load().filter { $0.id != id }
        try save(workouts)
    }

    func exportBackup() throws -> Data {
        Self.accessLock.lock()
        defer { Self.accessLock.unlock() }
        return try WorkoutBackup(workouts: load()).encode()
    }

    func restoreBackup(_ backup: WorkoutBackup) throws -> BackupRestoreResult {
        Self.accessLock.lock()
        defer { Self.accessLock.unlock() }
        // Revalidate even when the caller constructed an archive without decoding JSON.
        let validated = try WorkoutBackup.decode(backup.encode())
        let current = try load()
        var index = BackupMergeIndex(current)
        let ordered = validated.workouts.sorted {
            $0.savedAt == $1.savedAt
                ? $0.id.uuidString < $1.id.uuidString
                : $0.savedAt < $1.savedAt
        }
        for incoming in ordered {
            try index.absorb(incoming)
        }
        let merged = index.workouts
        if merged != current { try save(merged) }
        return index.result
    }

    private func save(_ workouts: [Workout]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(LibraryFile(schemaVersion: 1, workouts: workouts))
        try data.write(to: fileURL, options: .atomic)
    }
}

private struct BackupMergeIndex {
    private var records: [Workout?] = []
    private var byID: [UUID: Int] = [:]
    private var bySource: [URL: Set<Int>] = [:]
    private var byVideoID: [String: Set<Int>] = [:]
    private var sourceAliases: [Int: Set<TikTokLink>] = [:]
    private let originals: [UUID: Workout]

    init(_ workouts: [Workout]) {
        originals = Dictionary(workouts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for workout in workouts { append(workout, trustAliases: true) }
    }

    var workouts: [Workout] {
        records.indices.compactMap { position in
            guard var workout = records[position] else { return nil }
            var aliases = sourceAliases[position] ?? []
            aliases.remove(workout.sourceLink)
            workout.sourceAliases = aliases.isEmpty ? nil : aliases.sorted {
                $0.url.absoluteString < $1.url.absoluteString
            }
            return workout
        }
    }

    var result: BackupRestoreResult {
        let final = workouts
        let added = final.filter { originals[$0.id] == nil }.count
        let finalByID = Dictionary(final.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let updated = originals.filter { id, original in finalByID[id] != original }.count
        return BackupRestoreResult(added: added, updated: updated)
    }

    mutating func absorb(_ incoming: Workout) throws {
        // Check identity before matching URL or video. A matching post elsewhere must not
        // hide a reused UUID that belongs to a different current workout. Consult
        // the original library too: coalescing may have removed that UUID's index.
        if let original = originals[incoming.id], !Self.samePost(original, incoming) {
            throw WorkoutBackup.BackupError.invalidArchive
        }
        if let position = byID[incoming.id], let sameID = records[position],
           !Self.samePost(sameID, incoming) {
            throw WorkoutBackup.BackupError.invalidArchive
        }

        var matches = bySource[incoming.sourceLink.url] ?? []
        if let videoID = incoming.playbackLink.videoID {
            matches.formUnion(byVideoID[videoID] ?? [])
        }
        if let position = byID[incoming.id] { matches.insert(position) }
        // A source-only import may match a locally resolved short link. Include
        // its already-known canonical peers before choosing the keeper.
        var pendingMatches = Array(matches)
        while let position = pendingMatches.popLast() {
            guard let videoID = records[position]?.playbackLink.videoID else { continue }
            for peer in byVideoID[videoID] ?? [] where matches.insert(peer).inserted {
                pendingMatches.append(peer)
            }
        }
        guard !matches.isEmpty else {
            append(incoming)
            return
        }

        if matches.count == 1, let position = matches.first, let current = records[position] {
            try Self.validateCompatible(current, incoming)
            let merged = Self.merge(current, incoming)
            records[position] = merged
            // Extend the index in place. Materialize and sort aliases once at
            // the end of restore, regardless of how many links share this post.
            if sourceAliases[position, default: []].insert(incoming.sourceLink).inserted {
                bySource[incoming.sourceLink.url, default: []].insert(position)
            }
            if current.playbackLink.videoID != merged.playbackLink.videoID,
               let videoID = merged.playbackLink.videoID {
                byVideoID[videoID, default: []].insert(position)
            }
            return
        }

        let ordered = matches.sorted { left, right in
            guard let a = records[left], let b = records[right] else { return left < right }
            return a.savedAt == b.savedAt
                ? a.id.uuidString < b.id.uuidString
                : a.savedAt < b.savedAt
        }
        // A current library identity takes precedence over an imported one; among
        // current duplicates, keep the earliest save.
        let keeperIndex = ordered.first { position in
            guard let workout = records[position] else { return false }
            return originals[workout.id] != nil
        } ?? ordered[0]
        var keeper = records[keeperIndex]!
        var aliases = Set([incoming.sourceLink])
        for position in ordered {
            aliases.formUnion(sourceAliases[position] ?? [])
        }
        for position in ordered where position != keeperIndex {
            guard let other = records[position] else { continue }
            try Self.validateCompatible(keeper, other)
            keeper = Self.merge(keeper, other)
        }
        try Self.validateCompatible(keeper, incoming)
        keeper = Self.merge(keeper, incoming)

        for position in ordered { remove(position) }
        records[keeperIndex] = keeper
        sourceAliases[keeperIndex] = aliases
        addIndex(for: keeperIndex)
    }

    private static func samePost(_ left: Workout, _ right: Workout) -> Bool {
        left.sourceLink.url == right.sourceLink.url ||
            left.sourceAliases?.contains(where: { $0.url == right.sourceLink.url }) == true ||
            (left.playbackLink.videoID != nil &&
             left.playbackLink.videoID == right.playbackLink.videoID)
    }

    private static func validateCompatible(_ left: Workout, _ right: Workout) throws {
        if let leftVideoID = left.playbackLink.videoID,
           let rightVideoID = right.playbackLink.videoID,
           leftVideoID != rightVideoID {
            throw WorkoutBackup.BackupError.invalidArchive
        }
    }

    private static func merge(_ current: Workout, _ incoming: Workout) -> Workout {
        var merged = current
        if merged.resolvedLink == nil { merged.resolvedLink = incoming.resolvedLink }
        if merged.title == nil { merged.title = incoming.title }
        if merged.creator == nil { merged.creator = incoming.creator }
        if merged.thumbnailURL == nil { merged.thumbnailURL = incoming.thumbnailURL }
        merged.notes = mergeNotes(current.notes, incoming.notes)
        return merged
    }

    private static func mergeNotes(_ existing: String?, _ incoming: String?) -> String? {
        guard let incoming else { return existing }
        guard let existing else { return incoming }
        let separator = "\n\n"
        if existing == incoming || existing.hasPrefix(incoming + separator) ||
            existing.hasSuffix(separator + incoming) ||
            existing.contains(separator + incoming + separator) {
            return existing
        }
        return existing + separator + incoming
    }

    private mutating func append(_ workout: Workout, trustAliases: Bool = false) {
        let position = records.count
        var stored = workout
        if !trustAliases { stored.sourceAliases = nil }
        records.append(stored)
        // Imported alias claims never make a new record match unrelated local posts.
        sourceAliases[position] = Set([workout.sourceLink] + (trustAliases ? workout.sourceAliases ?? [] : []))
        addIndex(for: position)
    }

    private mutating func addIndex(for position: Int) {
        guard let workout = records[position] else { return }
        byID[workout.id] = position
        for source in sourceAliases[position] ?? [workout.sourceLink] {
            bySource[source.url, default: []].insert(position)
        }
        if let videoID = workout.playbackLink.videoID {
            byVideoID[videoID, default: []].insert(position)
        }
    }

    private mutating func remove(_ position: Int) {
        guard let workout = records[position] else { return }
        if byID[workout.id] == position { byID.removeValue(forKey: workout.id) }
        for source in sourceAliases[position] ?? [workout.sourceLink] {
            bySource[source.url]?.remove(position)
            if bySource[source.url]?.isEmpty == true {
                bySource.removeValue(forKey: source.url)
            }
        }
        if let videoID = workout.playbackLink.videoID {
            byVideoID[videoID]?.remove(position)
            if byVideoID[videoID]?.isEmpty == true { byVideoID.removeValue(forKey: videoID) }
        }
        records[position] = nil
        sourceAliases.removeValue(forKey: position)
    }
}
