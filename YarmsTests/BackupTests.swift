import XCTest
@testable import Yarms

final class BackupTests: XCTestCase {
    private func makeStore() -> (WorkoutStore, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = WorkoutStore(
            fileURL: directory.appendingPathComponent("Library.json"),
            inbox: SharedInbox(directory: directory.appendingPathComponent("Inbox"))
        )
        return (store, directory)
    }

    private func makeWorkout(_ number: String = "123") throws -> Workout {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/\(number)"))
        return Workout(id: UUID(), sourceLink: link, savedAt: Date(timeIntervalSince1970: 1234))
    }

    private func writeLibrary(_ workouts: [Workout], into directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let library = TestBackupLibrary(schemaVersion: 1, workouts: workouts)
        try JSONEncoder().encode(library).write(to: directory.appendingPathComponent("Library.json"))
    }

    func testRoundTripPreservesEntireWorkout() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        var workout = try makeWorkout()
        workout.resolvedLink = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/video/123"))
        workout.title = "Core workout"
        workout.creator = "Coach"
        workout.thumbnailURL = URL(string: "https://example.com/cover.jpg")
        workout.notes = "Three rounds"
        try writeLibrary([workout], into: directory)

        let data = try store.exportBackup()
        let decoded = try WorkoutBackup.decode(data)

        XCTAssertEqual(decoded.workouts, [workout])
        XCTAssertEqual(try WorkoutBackup.decode(decoded.encode()).workouts, [workout])
    }

    func testInvalidAndUnsupportedArchivesLeaveLibraryUntouched() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = try makeWorkout()
        try writeLibrary([original], into: directory)
        let before = try Data(contentsOf: directory.appendingPathComponent("Library.json"))

        let unsupported = Data("{\"schemaVersion\":2,\"workouts\":[]}".utf8)
        XCTAssertThrowsError(try WorkoutBackup.decode(unsupported)) { error in
            XCTAssertEqual(error as? WorkoutBackup.BackupError, .unsupportedVersion)
        }
        XCTAssertThrowsError(try WorkoutBackup.decode(Data("bad json".utf8)))
        XCTAssertThrowsError(try WorkoutBackup.decode(Data(repeating: 0, count: WorkoutBackup.maximumBytes + 1))) {
            error in
            XCTAssertEqual(error as? WorkoutBackup.BackupError, .tooLarge)
        }

        var archive = try XCTUnwrap(JSONSerialization.jsonObject(with: WorkoutBackup(workouts: [
            try makeWorkout("456"), try makeWorkout("789")
        ]).encode()) as? [String: Any])
        var workouts = try XCTUnwrap(archive["workouts"] as? [[String: Any]])
        var forgedLink = try XCTUnwrap(workouts[1]["sourceLink"] as? [String: Any])
        forgedLink["url"] = "https://evil.example/@coach/video/789"
        workouts[1]["sourceLink"] = forgedLink
        archive["workouts"] = workouts
        XCTAssertThrowsError(try WorkoutBackup.decode(JSONSerialization.data(withJSONObject: archive)))

        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("Library.json")), before)
        XCTAssertEqual(try store.load(), [original])
    }

    func testForgedVideoIDCannotBeImported() throws {
        let workout = try makeWorkout()
        var archive = try XCTUnwrap(JSONSerialization.jsonObject(with: WorkoutBackup(workouts: [workout]).encode())
                                    as? [String: Any])
        var workouts = try XCTUnwrap(archive["workouts"] as? [[String: Any]])
        var forgedLink = try XCTUnwrap(workouts[0]["sourceLink"] as? [String: Any])
        forgedLink["videoID"] = "999"
        workouts[0]["sourceLink"] = forgedLink
        archive["workouts"] = workouts

        XCTAssertThrowsError(try WorkoutBackup.decode(JSONSerialization.data(withJSONObject: archive)))
    }

    func testConflictingCanonicalSourceAndResolvedVideoCannotBeImported() throws {
        var workout = try makeWorkout("123")
        workout.resolvedLink = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/video/456"))

        XCTAssertThrowsError(try WorkoutBackup(workouts: [workout])) { error in
            XCTAssertEqual(error as? WorkoutBackup.BackupError, .invalidArchive)
        }
    }

    func testRepeatedRestoreIsIdempotentAndMatchesCanonicalVideoID() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        var current = try makeWorkout()
        current.title = nil
        try writeLibrary([current], into: directory)
        let alternateLink = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/video/123"))
        var imported = Workout(id: UUID(), sourceLink: alternateLink,
                               savedAt: Date(timeIntervalSince1970: 2345))
        imported.title = "Core workout"
        let backup = try WorkoutBackup(workouts: [imported])

        XCTAssertEqual(try store.restoreBackup(backup), BackupRestoreResult(added: 0, updated: 1))
        XCTAssertEqual(try store.restoreBackup(backup), BackupRestoreResult(added: 0, updated: 0))
        let restored = try XCTUnwrap(store.load().first)
        XCTAssertEqual(try store.load().count, 1)
        XCTAssertEqual(restored.id, current.id)
        XCTAssertEqual(restored.title, "Core workout")
    }

    func testRestoreKeepsExistingDetailsAndFillsMissingNotes() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        var current = try makeWorkout()
        current.title = "My title"
        current.notes = "My notes"
        try writeLibrary([current], into: directory)
        var imported = current
        imported.title = "Other title"
        imported.notes = "Other notes"
        imported.creator = "Coach"

        XCTAssertEqual(try store.restoreBackup(WorkoutBackup(workouts: [imported])),
                       BackupRestoreResult(added: 0, updated: 1))
        var restored = try XCTUnwrap(store.load().first)
        XCTAssertEqual(restored.title, "My title")
        XCTAssertEqual(restored.notes, "My notes\n\nOther notes")
        XCTAssertEqual(restored.creator, "Coach")

        try store.updateNotes("", for: current.id)
        XCTAssertEqual(try store.restoreBackup(WorkoutBackup(workouts: [imported])),
                       BackupRestoreResult(added: 0, updated: 1))
        restored = try XCTUnwrap(store.load().first)
        XCTAssertEqual(restored.notes, "Other notes")
    }

    func testRestoreAddsNewWorkoutWithoutReplacingCurrentLibrary() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let existing = try makeWorkout()
        let newWorkout = try makeWorkout("456")
        try writeLibrary([existing], into: directory)

        XCTAssertEqual(try store.restoreBackup(WorkoutBackup(workouts: [newWorkout])),
                       BackupRestoreResult(added: 1, updated: 0))
        XCTAssertEqual(Set(try store.load().map(\.id)), Set([existing.id, newWorkout.id]))
    }

    func testRestoreAppendsDistinctNotesFromMatchingBackupsInSaveOrder() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        var current = try makeWorkout("123")
        current.notes = "Current note"
        try writeLibrary([current], into: directory)

        let alternateLink = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/video/123"))
        var earlier = Workout(id: UUID(), sourceLink: alternateLink,
                              savedAt: Date(timeIntervalSince1970: 100))
        earlier.notes = "Earlier note"
        var later = Workout(id: UUID(), sourceLink: current.sourceLink,
                            savedAt: Date(timeIntervalSince1970: 200))
        later.notes = "Later note"
        let backup = try WorkoutBackup(workouts: [later, earlier])

        XCTAssertEqual(try store.restoreBackup(backup), BackupRestoreResult(added: 0, updated: 1))
        XCTAssertEqual(try store.load().first?.notes,
                       "Current note\n\nEarlier note\n\nLater note")
        XCTAssertEqual(try store.restoreBackup(backup), BackupRestoreResult(added: 0, updated: 0))
        XCTAssertEqual(try store.load().first?.notes,
                       "Current note\n\nEarlier note\n\nLater note")
    }

    func testBackupsForOneNewVideoCountAsOneAdditionAndNoUpdate() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        var earlier = try makeWorkout("123")
        earlier.notes = "Warm up"
        let alternateLink = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/video/123"))
        var later = Workout(id: UUID(), sourceLink: alternateLink,
                            savedAt: Date(timeIntervalSince1970: 2000))
        later.notes = "Stretch"
        let backup = try WorkoutBackup(workouts: [later, earlier])

        XCTAssertEqual(try store.restoreBackup(backup), BackupRestoreResult(added: 1, updated: 0))
        XCTAssertEqual(try store.load().count, 1)
        XCTAssertEqual(try store.load().first?.id, earlier.id)
        XCTAssertEqual(try store.load().first?.notes, "Warm up\n\nStretch")
        XCTAssertEqual(try store.restoreBackup(backup), BackupRestoreResult(added: 0, updated: 0))
        XCTAssertEqual(try store.load().first?.notes, "Warm up\n\nStretch")
    }

    func testLaterConflictingIdentifierLeavesEntireLibraryUnchanged() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let existing = try makeWorkout("123")
        try writeLibrary([existing], into: directory)
        let before = try Data(contentsOf: directory.appendingPathComponent("Library.json"))
        let validNewWorkout = try makeWorkout("456")
        let otherPost = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@other/video/789"))
        let conflicting = Workout(id: existing.id, sourceLink: otherPost,
                                  savedAt: Date(timeIntervalSince1970: 9999))
        let backup = try WorkoutBackup(workouts: [validNewWorkout, conflicting])

        XCTAssertThrowsError(try store.restoreBackup(backup)) { error in
            XCTAssertEqual(error as? WorkoutBackup.BackupError, .invalidArchive)
        }
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("Library.json")), before)
        XCTAssertEqual(try store.load(), [existing])
    }
}

private struct TestBackupLibrary: Encodable {
    let schemaVersion: Int
    let workouts: [Workout]
}
