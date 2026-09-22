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
    }

    static let maximumBytes = 10 * 1_024 * 1_024
    let workouts: [Workout]

    init(workouts: [Workout]) throws {
        try Self.validate(workouts)
        self.workouts = workouts
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
        return try WorkoutBackup(workouts: archive.workouts)
    }

    func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(Archive(schemaVersion: 1, workouts: workouts))
        guard data.count <= Self.maximumBytes else { throw BackupError.tooLarge }
        return data
    }

    private static func validate(_ workouts: [Workout]) throws {
        var identifiers = Set<UUID>()
        for workout in workouts {
            guard identifiers.insert(workout.id).inserted,
                  workout.savedAt.timeIntervalSince1970.isFinite,
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
        }
    }

    private static func isAuthentic(_ link: TikTokLink) -> Bool {
        TikTokLink(text: link.url.absoluteString) == link
    }
}

struct BackupRestoreResult: Equatable {
    let added: Int
    let updated: Int
}
