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

    private func writeLibrary(_ workouts: [Workout], into directory: URL,
                              folders: [WorkoutFolder]? = nil) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let library = TestBackupLibrary(schemaVersion: 1, workouts: workouts, folders: folders)
        try JSONEncoder().encode(library).write(to: directory.appendingPathComponent("Library.json"))
    }

    func testBackupRoundTripPreservesWorkoutFieldsButDiscardsThumbnail() throws {
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

        var imported = workout
        imported.thumbnailURL = nil // Re-enriched after import, never loaded from archive URLs.
        XCTAssertEqual(decoded.workouts, [imported])
        XCTAssertEqual(try WorkoutBackup.decode(decoded.encode()).workouts, [imported])
        XCTAssertTrue(decoded.folders.isEmpty)
    }

    func testFolderBackupRoundTripAndLegacyArchiveDecode() throws {
        let folder = WorkoutFolder(id: UUID(), name: "Strength")
        var workout = try makeWorkout()
        workout.folderID = folder.id
        let backup = try WorkoutBackup(workouts: [workout], folders: [folder])
        let decoded = try WorkoutBackup.decode(backup.encode())
        XCTAssertEqual(decoded.folders, [folder])
        XCTAssertEqual(decoded.workouts.first?.folderID, folder.id)

        let legacy = try JSONEncoder().encode(TestBackupLibrary(schemaVersion: 1, workouts: [
            try makeWorkout("456")
        ]))
        let legacyDecoded = try WorkoutBackup.decode(legacy)
        XCTAssertTrue(legacyDecoded.folders.isEmpty)
        XCTAssertNil(legacyDecoded.workouts.first?.folderID)
    }

    func testStoreExportAndRestoreKeepFolderMembership() throws {
        let (source, sourceDirectory) = makeStore()
        let (destination, destinationDirectory) = makeStore()
        defer {
            try? FileManager.default.removeItem(at: sourceDirectory)
            try? FileManager.default.removeItem(at: destinationDirectory)
        }
        let folder = try source.createFolder(named: "Mobility")
        var workout = try makeWorkout()
        workout.folderID = folder.id
        try writeLibrary([workout], into: sourceDirectory, folders: [folder])

        let backup = try WorkoutBackup.decode(source.exportBackup())
        XCTAssertEqual(backup.folders, [folder])
        XCTAssertEqual(try destination.restoreBackup(backup), BackupRestoreResult(added: 1, updated: 0))
        XCTAssertEqual(try destination.loadFolders(), [folder])
        XCTAssertEqual(try destination.load().first?.folderID, folder.id)
    }

    func testFolderBackupRejectsInvalidReferencesAndDuplicateNames() throws {
        var workout = try makeWorkout()
        workout.folderID = UUID()
        XCTAssertThrowsError(try WorkoutBackup(workouts: [workout])) { error in
            XCTAssertEqual(error as? WorkoutBackup.BackupError, .invalidArchive)
        }
        let folders = [WorkoutFolder(id: UUID(), name: "Cardio"),
                       WorkoutFolder(id: UUID(), name: "cárdio")]
        XCTAssertThrowsError(try WorkoutBackup(workouts: [], folders: folders)) { error in
            XCTAssertEqual(error as? WorkoutBackup.BackupError, .invalidArchive)
        }
    }

    func testFolderRestoreMapsNamesAndIDConflictsIdempotently() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let local = try store.createFolder(named: "Strength")
        let collided = try store.createFolder(named: "Cardio")
        let incomingStrength = WorkoutFolder(id: UUID(), name: "strength")
        let incomingNew = WorkoutFolder(id: collided.id, name: "Yoga")
        var first = try makeWorkout("123")
        first.folderID = incomingStrength.id
        var second = try makeWorkout("456")
        second.folderID = incomingNew.id
        let backup = try WorkoutBackup(workouts: [first, second], folders: [incomingStrength, incomingNew])

        XCTAssertEqual(try store.restoreBackup(backup), BackupRestoreResult(added: 2, updated: 0))
        let folders = try store.loadFolders()
        XCTAssertEqual(folders.count, 3)
        let yoga = try XCTUnwrap(folders.first { $0.name == "Yoga" })
        XCTAssertNotEqual(yoga.id, collided.id)
        XCTAssertEqual(try store.load().first { $0.id == first.id }?.folderID, local.id)
        XCTAssertEqual(try store.load().first { $0.id == second.id }?.folderID, yoga.id)
        XCTAssertEqual(try store.restoreBackup(backup), BackupRestoreResult(added: 0, updated: 0))
        XCTAssertEqual(try store.loadFolders(), folders)
    }

    func testRestorePreservesExistingFolderAndFillsUnfiledDuplicate() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let local = try store.createFolder(named: "Strength")
        let importedFolder = WorkoutFolder(id: UUID(), name: "Cardio")
        var current = try makeWorkout("123")
        current.folderID = local.id
        try writeLibrary([current], into: directory, folders: [local])
        var incoming = current
        incoming.folderID = importedFolder.id
        let backup = try WorkoutBackup(workouts: [incoming], folders: [importedFolder])

        XCTAssertEqual(try store.restoreBackup(backup), BackupRestoreResult(added: 0, updated: 0))
        XCTAssertEqual(try store.load().first?.folderID, local.id)
        XCTAssertEqual(try store.loadFolders().count, 2)

        current.folderID = nil
        try writeLibrary([current], into: directory, folders: [local])
        XCTAssertEqual(try store.restoreBackup(backup), BackupRestoreResult(added: 0, updated: 1))
        XCTAssertEqual(try store.load().first?.folderID, importedFolder.id)
        XCTAssertEqual(try store.restoreBackup(backup), BackupRestoreResult(added: 0, updated: 0))
    }

    func testDecoderRejectsInvalidAndUnsupportedArchives() throws {
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

    func testBlankOptionalFieldsNormalizeOnConstructionAndDecode() throws {
        var workout = try makeWorkout()
        workout.title = " \n "
        workout.creator = "\t"
        workout.notes = "  \n\t "

        let constructed = try WorkoutBackup(workouts: [workout])
        XCTAssertNil(constructed.workouts[0].title)
        XCTAssertNil(constructed.workouts[0].creator)
        XCTAssertNil(constructed.workouts[0].notes)

        let rawArchive = try JSONEncoder().encode(TestBackupLibrary(schemaVersion: 1, workouts: [workout]))
        let decoded = try WorkoutBackup.decode(rawArchive)
        XCTAssertNil(decoded.workouts[0].title)
        XCTAssertNil(decoded.workouts[0].creator)
        XCTAssertNil(decoded.workouts[0].notes)
    }

    func testOversizedFileIsRejectedBeforeDecode() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("oversized.json")
        XCTAssertTrue(FileManager.default.createFile(atPath: file.path, contents: nil))
        let handle = try FileHandle(forWritingTo: file)
        try handle.truncate(atOffset: UInt64(WorkoutBackup.maximumBytes + 1))
        try handle.close()

        XCTAssertThrowsError(try WorkoutBackup.load(from: file)) { error in
            XCTAssertEqual(error as? WorkoutBackup.BackupError, .tooLarge)
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

    func testResolvedShortLinkCoalescesCurrentVideosAndKeepsEarliestIdentity() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let short = try XCTUnwrap(TikTokLink(text: "https://vt.tiktok.com/ZMshort/"))
        let canonical = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        var first = Workout(id: UUID(), sourceLink: short,
                            savedAt: Date(timeIntervalSince1970: 100))
        first.resolvedLink = canonical
        first.notes = "Short note"
        var second = Workout(id: UUID(), sourceLink: canonical,
                             savedAt: Date(timeIntervalSince1970: 200))
        second.title = "Canonical title"
        second.notes = "Canonical note"
        try writeLibrary([second, first], into: directory)
        var restored = first
        restored.notes = "Backup note"
        let backup = try WorkoutBackup(workouts: [restored])

        XCTAssertEqual(try store.restoreBackup(backup), BackupRestoreResult(added: 0, updated: 2))
        let workout = try XCTUnwrap(store.load().first)
        XCTAssertEqual(try store.load().count, 1)
        XCTAssertEqual(workout.id, first.id)
        XCTAssertEqual(workout.savedAt, first.savedAt)
        XCTAssertEqual(workout.playbackLink.videoID, "123")
        XCTAssertEqual(workout.title, "Canonical title")
        XCTAssertEqual(workout.notes, "Short note\n\nCanonical note\n\nBackup note")
        XCTAssertEqual(try store.restoreBackup(backup), BackupRestoreResult(added: 0, updated: 0))
    }

    func testCoalescedSourceAliasMatchesLaterUnresolvedBackupRecord() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let short = try XCTUnwrap(TikTokLink(text: "https://vt.tiktok.com/ZMalias/"))
        let canonical = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        var canonicalCurrent = Workout(id: UUID(), sourceLink: canonical,
                                       savedAt: Date(timeIntervalSince1970: 100))
        canonicalCurrent.notes = "Canonical note"
        var shortCurrent = Workout(id: UUID(), sourceLink: short,
                                   savedAt: Date(timeIntervalSince1970: 200))
        shortCurrent.resolvedLink = canonical
        shortCurrent.notes = "Short note"
        try writeLibrary([canonicalCurrent, shortCurrent], into: directory)

        var canonicalImport = Workout(id: UUID(), sourceLink: canonical,
                                      savedAt: Date(timeIntervalSince1970: 300))
        canonicalImport.notes = "First import"
        var unresolvedShortImport = Workout(id: UUID(), sourceLink: short,
                                             savedAt: Date(timeIntervalSince1970: 400))
        unresolvedShortImport.notes = "Second import"

        XCTAssertEqual(try store.restoreBackup(WorkoutBackup(workouts: [
            canonicalImport, unresolvedShortImport
        ])), BackupRestoreResult(added: 0, updated: 2))
        let merged = try XCTUnwrap(store.load().first)
        XCTAssertEqual(try store.load().count, 1)
        XCTAssertEqual(merged.id, canonicalCurrent.id)
        XCTAssertEqual(merged.notes, "Canonical note\n\nShort note\n\nFirst import\n\nSecond import")
        XCTAssertEqual(merged.sourceAliases, [short])
        XCTAssertEqual(try store.restoreBackup(WorkoutBackup(workouts: [
            canonicalImport, unresolvedShortImport
        ])), BackupRestoreResult(added: 0, updated: 0))
        XCTAssertEqual(try store.load().count, 1)
    }

    func testUnverifiedImportedShortResolutionDoesNotBridgeCurrentPosts() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let short = try XCTUnwrap(TikTokLink(text: "https://vt.tiktok.com/ZMother/"))
        let canonical = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        let shortCurrent = Workout(id: UUID(), sourceLink: short,
                                   savedAt: Date(timeIntervalSince1970: 100))
        let canonicalCurrent = Workout(id: UUID(), sourceLink: canonical,
                                       savedAt: Date(timeIntervalSince1970: 200))
        try writeLibrary([shortCurrent, canonicalCurrent], into: directory)
        var incoming = Workout(id: UUID(), sourceLink: short,
                               savedAt: Date(timeIntervalSince1970: 300))
        incoming.resolvedLink = canonical
        incoming.notes = "Imported note"

        XCTAssertEqual(try store.restoreBackup(WorkoutBackup(workouts: [incoming])),
                       BackupRestoreResult(added: 0, updated: 1))
        let restored = try store.load()
        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(restored.first { $0.id == shortCurrent.id }?.notes, "Imported note")
        XCTAssertNil(restored.first { $0.id == shortCurrent.id }?.resolvedLink)
        XCTAssertNotNil(restored.first { $0.id == canonicalCurrent.id })
    }

    func testLargeBackupRestoresUniqueRecordsAndRemainsIdempotent() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let workouts = try (1...2_500).map { try makeWorkout(String($0 + 10_000)) }
        let backup = try WorkoutBackup(workouts: workouts)

        XCTAssertEqual(try store.restoreBackup(backup), BackupRestoreResult(added: 2_500, updated: 0))
        XCTAssertEqual(try store.load().count, 2_500)
        XCTAssertEqual(try store.restoreBackup(backup), BackupRestoreResult(added: 0, updated: 0))
    }

    func testManyURLsForOneVideoMaterializeDistinctAliasesOnce() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        // Distinct valid TikTok source URLs can identify the same numeric post.
        // This shape previously rebuilt and sorted the growing alias list per row.
        let count = 1_200
        let links = try (0..<count).map { number in
            try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach\(number)/video/123"))
        }
        let entries = links.enumerated().map { number, link in
            Workout(id: UUID(), sourceLink: link, savedAt: Date(timeIntervalSince1970: Double(number)))
        }
        let backup = try WorkoutBackup(workouts: entries)

        XCTAssertEqual(try store.restoreBackup(backup), BackupRestoreResult(added: 1, updated: 0))
        let merged = try XCTUnwrap(store.load().first)
        XCTAssertEqual(try store.load().count, 1)
        XCTAssertEqual(merged.id, entries[0].id)
        XCTAssertEqual(Set(merged.sourceAliases ?? []), Set(links.dropFirst()))
        XCTAssertEqual(try store.restoreBackup(backup), BackupRestoreResult(added: 0, updated: 0))
    }

    func testEnrichmentFillsMissingThumbnailWithoutReplacingSavedMetadata() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        var workout = try makeWorkout()
        workout.title = "My workout name"
        workout.creator = "My coach label"
        try writeLibrary([workout], into: directory)
        let cover = try XCTUnwrap(URL(string: "https://example.com/cover.jpg"))
        let otherCover = try XCTUnwrap(URL(string: "https://example.com/other.jpg"))

        try store.applyEnrichment(TikTokEnrichment(resolvedLink: nil, metadata: TikTokMetadata(
            title: "oEmbed title", creator: "oEmbed creator", thumbnailURL: cover
        )), to: workout.id)
        var refreshed = try XCTUnwrap(store.load().first)
        XCTAssertEqual(refreshed.title, "My workout name")
        XCTAssertEqual(refreshed.creator, "My coach label")
        XCTAssertEqual(refreshed.thumbnailURL, cover)

        try store.applyEnrichment(TikTokEnrichment(resolvedLink: nil, metadata: TikTokMetadata(
            title: "Another title", creator: "Another creator", thumbnailURL: otherCover
        )), to: workout.id)
        refreshed = try XCTUnwrap(store.load().first)
        XCTAssertEqual(refreshed.title, "My workout name")
        XCTAssertEqual(refreshed.creator, "My coach label")
        XCTAssertEqual(refreshed.thumbnailURL, cover)
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

    func testUUIDCollisionCannotHideBehindAnotherRecordWithMatchingURL() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        var collidedID = try makeWorkout("123")
        collidedID = Workout(id: collidedID.id, sourceLink: collidedID.sourceLink,
                             savedAt: Date(timeIntervalSince1970: 100))
        var matchingURL = try makeWorkout("456")
        matchingURL = Workout(id: matchingURL.id, sourceLink: matchingURL.sourceLink,
                              savedAt: Date(timeIntervalSince1970: 200))
        try writeLibrary([collidedID, matchingURL], into: directory)
        let before = try Data(contentsOf: directory.appendingPathComponent("Library.json"))
        let newLink = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/789"))
        let validNewWorkout = Workout(id: UUID(), sourceLink: newLink,
                                      savedAt: Date(timeIntervalSince1970: 50))
        let conflicting = Workout(id: collidedID.id, sourceLink: matchingURL.sourceLink,
                                  savedAt: Date(timeIntervalSince1970: 300))
        let backup = try WorkoutBackup(workouts: [validNewWorkout, conflicting])

        XCTAssertThrowsError(try store.restoreBackup(backup)) { error in
            XCTAssertEqual(error as? WorkoutBackup.BackupError, .invalidArchive)
        }
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("Library.json")), before)
    }

    func testUUIDCollisionStillRejectsAfterOriginalWasCoalesced() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let short = try XCTUnwrap(TikTokLink(text: "https://vt.tiktok.com/ZMshort/"))
        let canonical = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/video/123"))
        let first = Workout(id: UUID(), sourceLink: short,
                            savedAt: Date(timeIntervalSince1970: 100))
        let second = Workout(id: UUID(), sourceLink: canonical,
                             savedAt: Date(timeIntervalSince1970: 200))
        try writeLibrary([first, second], into: directory)
        let before = try Data(contentsOf: directory.appendingPathComponent("Library.json"))
        var resolved = Workout(id: first.id, sourceLink: short,
                               savedAt: Date(timeIntervalSince1970: 50))
        resolved.resolvedLink = canonical
        let otherPost = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/video/789"))
        let collision = Workout(id: second.id, sourceLink: otherPost,
                                savedAt: Date(timeIntervalSince1970: 300))
        let backup = try WorkoutBackup(workouts: [resolved, collision])

        XCTAssertThrowsError(try store.restoreBackup(backup)) { error in
            XCTAssertEqual(error as? WorkoutBackup.BackupError, .invalidArchive)
        }
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("Library.json")), before)
    }
}

private struct TestBackupLibrary: Encodable {
    let schemaVersion: Int
    let workouts: [Workout]
    var folders: [WorkoutFolder]? = nil
}
