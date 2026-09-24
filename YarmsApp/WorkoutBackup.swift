import Foundation

struct WorkoutBackup {
    enum BackupError: Error, Equatable {
        case tooLarge
        case unsupportedVersion
        case invalidArchive
    }

    private struct Archive: Codable {
        let schemaVersion: Int
        let workouts: [Workout]
        let folders: [WorkoutFolder]?
    }

    static let maximumBytes = 10 * 1_024 * 1_024
    let workouts: [Workout]
    let folders: [WorkoutFolder]

    init(workouts: [Workout], folders: [WorkoutFolder] = []) throws {
        try self.init(workouts: workouts, folders: folders, importing: false)
    }

    private init(workouts: [Workout], folders: [WorkoutFolder], importing: Bool) throws {
        let normalized = workouts.map { workout in
            var copy = workout
            copy.title = Self.nonblank(copy.title)
            copy.creator = Self.nonblank(copy.creator)
            copy.notes = Self.nonblank(copy.notes)
            if importing {
                // The archive is user-selected data. Re-fetch thumbnails from TikTok
                // rather than contacting an arbitrary URL embedded in that file.
                copy.thumbnailURL = nil
                // Source aliases can only be trusted after this installation has
                // independently matched or resolved their URLs.
                copy.sourceAliases = nil
                // A short URL has no video ID to prove that its saved resolution
                // belongs to it. Resolve it through the normal bounded redirect path.
                if copy.sourceLink.videoID == nil { copy.resolvedLink = nil }
            }
            return copy
        }
        let normalizedFolders: [WorkoutFolder]
        do {
            normalizedFolders = try folders.map { folder in
                WorkoutFolder(id: folder.id, name: try WorkoutStore.normalizedFolderName(folder.name))
            }
        } catch {
            throw BackupError.invalidArchive
        }
        try Self.validate(normalized, folders: normalizedFolders)
        self.workouts = normalized
        self.folders = normalizedFolders
    }

    static func load(from url: URL) throws -> WorkoutBackup {
        if let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size > maximumBytes {
            throw BackupError.tooLarge
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while data.count <= maximumBytes {
            let remaining = maximumBytes + 1 - data.count
            let chunk = try handle.read(upToCount: min(64 * 1_024, remaining)) ?? Data()
            if chunk.isEmpty { break }
            data.append(chunk)
        }
        return try decode(data)
    }

    static func decode(_ data: Data) throws -> WorkoutBackup {
        guard !data.isEmpty else { throw BackupError.invalidArchive }
        guard data.count <= maximumBytes else { throw BackupError.tooLarge }
        let archive: Archive
        do {
            archive = try JSONDecoder().decode(Archive.self, from: data)
        } catch {
            throw BackupError.invalidArchive
        }
        guard archive.schemaVersion == 1 else { throw BackupError.unsupportedVersion }
        return try WorkoutBackup(workouts: archive.workouts, folders: archive.folders ?? [], importing: true)
    }

    func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        // Local libraries can grow beyond the defensive import limit through
        // notes and later saves. An export must still include every record.
        return try encoder.encode(Archive(schemaVersion: 1, workouts: workouts, folders: folders))
    }

    private static func validate(_ workouts: [Workout], folders: [WorkoutFolder]) throws {
        var folderIDs = Set<UUID>()
        var folderNames = Set<String>()
        for folder in folders {
            let normalized = WorkoutStore.folderNameKey(folder.name)
            guard folderIDs.insert(folder.id).inserted,
                  folderNames.insert(normalized).inserted else { throw BackupError.invalidArchive }
        }
        var identifiers = Set<UUID>()
        for workout in workouts {
            guard identifiers.insert(workout.id).inserted,
                  workout.savedAt.timeIntervalSince1970.isFinite,
                  workout.folderID.map({ folderIDs.contains($0) }) ?? true,
                  isAuthentic(workout.sourceLink) else { throw BackupError.invalidArchive }
            if let resolvedLink = workout.resolvedLink {
                guard isAuthentic(resolvedLink), resolvedLink.videoID != nil,
                      workout.sourceLink.videoID == nil ||
                        workout.sourceLink.videoID == resolvedLink.videoID else {
                    throw BackupError.invalidArchive
                }
            }
            if let thumbnail = workout.thumbnailURL {
                guard thumbnail.scheme?.lowercased() == "https",
                      thumbnail.host != nil,
                      thumbnail.user == nil,
                      thumbnail.password == nil else { throw BackupError.invalidArchive }
            }
            if let aliases = workout.sourceAliases {
                for alias in aliases {
                    guard isAuthentic(alias),
                          alias.videoID == nil || workout.playbackLink.videoID == alias.videoID else {
                        throw BackupError.invalidArchive
                    }
                }
            }
        }
    }

    private static func isAuthentic(_ link: TikTokLink) -> Bool {
        TikTokLink(text: link.url.absoluteString) == link
    }

    private static func nonblank(_ value: String?) -> String? {
        guard let value,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }
}

struct BackupRestoreResult: Equatable {
    let added: Int
    let updated: Int
}
