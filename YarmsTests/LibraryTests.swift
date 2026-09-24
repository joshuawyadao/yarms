import XCTest
@testable import Yarms

final class LibraryTests: XCTestCase {
    private func makeStore() -> (WorkoutStore, SharedInbox, URL) {
        let container = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let inbox = SharedInbox(directory: container.appendingPathComponent("Inbox"))
        let store = WorkoutStore(fileURL: container.appendingPathComponent("Library.json"), inbox: inbox)
        return (store, inbox, container)
    }

    func testImportPersistsLinkThenClearsInbox() throws {
        let (store, inbox, container) = makeStore()
        defer { try? FileManager.default.removeItem(at: container) }
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        try inbox.save(link)

        let imported = try store.importPending()

        XCTAssertEqual(imported.count, 1)
        XCTAssertEqual(imported[0].sourceLink, link)
        XCTAssertEqual(try store.load(), imported)
        XCTAssertTrue(try inbox.load().isEmpty)
    }

    func testRepeatedShareDoesNotCreateDuplicate() throws {
        let (store, inbox, container) = makeStore()
        defer { try? FileManager.default.removeItem(at: container) }
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        try inbox.save(link)
        try store.importPending()
        try inbox.save(link)

        XCTAssertEqual(try store.importPending().count, 1)
        XCTAssertTrue(try inbox.load().isEmpty)
    }

    func testCorruptLibraryLeavesPendingLinkUntouched() throws {
        let (store, inbox, container) = makeStore()
        defer { try? FileManager.default.removeItem(at: container) }
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        try inbox.save(link)
        try Data("not json".utf8).write(to: container.appendingPathComponent("Library.json"))

        XCTAssertThrowsError(try store.importPending())
        XCTAssertEqual(try inbox.load().count, 1)
    }

    func testSearchMatchesTitleCreatorAndOriginalLink() throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        var workout = Workout(id: UUID(), sourceLink: link, savedAt: Date())
        workout.title = "Leg day strength"
        workout.creator = "Coach Alex"

        XCTAssertTrue(workout.matches("leg day"))
        XCTAssertTrue(workout.matches("alex"))
        XCTAssertTrue(workout.matches("123"))
        XCTAssertFalse(workout.matches("yoga"))
    }

    func testEnrichmentPersistsMetadataAndResolvedPlaybackLink() throws {
        let (store, inbox, container) = makeStore()
        defer { try? FileManager.default.removeItem(at: container) }
        let short = try XCTUnwrap(TikTokLink(text: "https://vt.tiktok.com/ZMshort/"))
        let canonical = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        try inbox.save(short)
        let id = try XCTUnwrap(store.importPending().first?.id)

        try store.applyEnrichment(
            TikTokEnrichment(
                resolvedLink: canonical,
                metadata: TikTokMetadata(
                    title: "Core strength",
                    creator: "Coach",
                    thumbnailURL: URL(string: "https://example.com/cover.jpg")
                )
            ),
            to: id
        )

        let workout = try XCTUnwrap(store.load().first)
        XCTAssertEqual(workout.sourceLink, short)
        XCTAssertEqual(workout.playbackLink, canonical)
        XCTAssertEqual(workout.title, "Core strength")
        XCTAssertEqual(workout.creator, "Coach")
        XCTAssertTrue(workout.matches("core"))
    }

    func testResolvedShortLinkCoalescesWithCanonicalSave() throws {
        let (store, inbox, container) = makeStore()
        defer { try? FileManager.default.removeItem(at: container) }
        let canonical = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        let short = try XCTUnwrap(TikTokLink(text: "https://vt.tiktok.com/ZMshort/"))
        try inbox.save(canonical)
        let shortEntry = try inbox.save(short)
        XCTAssertEqual(try store.importPending().count, 2)

        try store.applyEnrichment(
            TikTokEnrichment(
                resolvedLink: canonical,
                metadata: TikTokMetadata(title: "Strength", creator: "Coach", thumbnailURL: nil)
            ),
            to: shortEntry.id
        )

        let workout = try XCTUnwrap(store.load().onlyElement)
        XCTAssertEqual(workout.playbackLink.videoID, "123")
        XCTAssertEqual(workout.title, "Strength")
        XCTAssertEqual(workout.creator, "Coach")
    }

    func testTwoShortLinksCoalesceAfterBothResolve() throws {
        let (store, inbox, container) = makeStore()
        defer { try? FileManager.default.removeItem(at: container) }
        let first = try XCTUnwrap(TikTokLink(text: "https://vt.tiktok.com/ZMfirst/"))
        let second = try XCTUnwrap(TikTokLink(text: "https://vm.tiktok.com/ZMsecond/"))
        let canonical = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        let firstEntry = try inbox.save(first)
        let secondEntry = try inbox.save(second)
        XCTAssertEqual(try store.importPending().count, 2)

        try store.applyEnrichment(TikTokEnrichment(resolvedLink: canonical, metadata: nil),
                                  to: firstEntry.id)
        try store.applyEnrichment(TikTokEnrichment(resolvedLink: canonical, metadata: nil),
                                  to: secondEntry.id)

        let workout = try XCTUnwrap(store.load().onlyElement)
        XCTAssertEqual(workout.playbackLink.videoID, "123")
        XCTAssertTrue([first, second].contains(workout.sourceLink))
    }

    func testLateMetadataForRemovedDuplicateUpdatesSurvivingWorkout() throws {
        let (store, inbox, container) = makeStore()
        defer { try? FileManager.default.removeItem(at: container) }
        let short = try XCTUnwrap(TikTokLink(text: "https://vt.tiktok.com/ZMshort/"))
        let canonical = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        let first = try inbox.save(short)
        let later = try inbox.save(canonical)
        XCTAssertEqual(try store.importPending().count, 2)

        try store.applyEnrichment(TikTokEnrichment(resolvedLink: canonical, metadata: nil),
                                  to: first.id)
        XCTAssertEqual(try store.load().onlyElement?.id, first.id)

        try store.applyEnrichment(
            TikTokEnrichment(
                resolvedLink: canonical,
                metadata: TikTokMetadata(title: "Complete workout", creator: "Coach",
                                         thumbnailURL: URL(string: "https://example.com/cover.jpg"))
            ),
            to: later.id
        )

        let workout = try XCTUnwrap(store.load().onlyElement)
        XCTAssertEqual(workout.id, first.id)
        XCTAssertEqual(workout.title, "Complete workout")
        XCTAssertEqual(workout.creator, "Coach")
        XCTAssertEqual(workout.thumbnailURL?.absoluteString, "https://example.com/cover.jpg")
    }

    func testNotesSaveReloadAndClear() throws {
        let (store, inbox, container) = makeStore()
        defer { try? FileManager.default.removeItem(at: container) }
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        let entry = try inbox.save(link)
        try store.importPending()

        XCTAssertTrue(try store.updateNotes("  Three rounds\nRest 30 seconds  \n", for: entry.id))
        XCTAssertEqual(try store.load().onlyElement?.notes, "Three rounds\nRest 30 seconds")

        XCTAssertTrue(try store.updateNotes(" \n\t ", for: entry.id))
        XCTAssertNil(try store.load().onlyElement?.notes)
        XCTAssertFalse(try store.updateNotes("Missing", for: UUID()))
    }

    func testLibraryRecordWithoutNotesDecodes() throws {
        let (store, _, container) = makeStore()
        defer { try? FileManager.default.removeItem(at: container) }
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        let workout = Workout(id: UUID(), sourceLink: link, savedAt: Date(timeIntervalSince1970: 100))
        let data = try JSONEncoder().encode(TestLibraryFile(workouts: [workout]))
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("\"notes\""))
        try data.write(to: container.appendingPathComponent("Library.json"))

        let loaded = try XCTUnwrap(store.load().onlyElement)
        XCTAssertEqual(loaded.id, workout.id)
        XCTAssertNil(loaded.notes)
        XCTAssertNil(loaded.folderID)
        XCTAssertTrue(try store.loadFolders().isEmpty)
    }

    func testFolderCRUDAndMovePreserveWorkouts() throws {
        let (store, inbox, container) = makeStore()
        defer { try? FileManager.default.removeItem(at: container) }
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        let entry = try inbox.save(link)
        try store.importPending()

        let folder = try store.createFolder(named: "  Strength  ")
        XCTAssertEqual(folder.name, "Strength")
        XCTAssertEqual(try store.loadFolders(), [folder])
        XCTAssertTrue(try store.moveWorkout(entry.id, to: folder.id))
        XCTAssertEqual(try store.load().first?.folderID, folder.id)
        XCTAssertTrue(try store.renameFolder(folder.id, to: "Leg Day"))
        XCTAssertEqual(try store.loadFolders().first?.name, "Leg Day")
        XCTAssertTrue(try store.deleteFolder(folder.id))
        XCTAssertTrue(try store.loadFolders().isEmpty)
        XCTAssertEqual(try store.load().count, 1)
        XCTAssertNil(try store.load().first?.folderID)
        XCTAssertFalse(try store.deleteFolder(folder.id))
    }

    func testFolderNamesAndReferencesAreValidated() throws {
        let (store, inbox, container) = makeStore()
        defer { try? FileManager.default.removeItem(at: container) }
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        let entry = try inbox.save(link)
        try store.importPending()
        XCTAssertThrowsError(try store.createFolder(named: "  "))
        XCTAssertThrowsError(try store.createFolder(named: String(repeating: "x", count: 81)))
        let folder = try store.createFolder(named: "Cardio")
        XCTAssertThrowsError(try store.createFolder(named: "cárdio"))
        XCTAssertThrowsError(try store.moveWorkout(entry.id, to: UUID()))
        XCTAssertNil(try store.load().first?.folderID)
        XCTAssertTrue(try store.moveWorkout(entry.id, to: folder.id))
        XCTAssertTrue(try store.moveWorkout(entry.id, to: nil))
        XCTAssertNil(try store.load().first?.folderID)
    }

    func testCoalescingKeepsEarliestNoteAndAppendsDistinctLaterNotes() throws {
        let (store, _, container) = makeStore()
        defer { try? FileManager.default.removeItem(at: container) }
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let canonical = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        var first = Workout(id: UUID(), sourceLink: canonical,
                            savedAt: Date(timeIntervalSince1970: 100))
        first.notes = "Warm up"
        var duplicate = Workout(id: UUID(), sourceLink: canonical,
                                savedAt: Date(timeIntervalSince1970: 200))
        duplicate.notes = "Warm up"
        var later = Workout(id: UUID(), sourceLink: canonical,
                            savedAt: Date(timeIntervalSince1970: 300))
        later.notes = "  Add a stretch  "
        let data = try JSONEncoder().encode(TestLibraryFile(workouts: [later, duplicate, first]))
        try data.write(to: container.appendingPathComponent("Library.json"))

        try store.applyEnrichment(TikTokEnrichment(resolvedLink: canonical, metadata: nil), to: later.id)

        let merged = try XCTUnwrap(store.load().onlyElement)
        XCTAssertEqual(merged.id, first.id)
        XCTAssertEqual(merged.notes, "Warm up\n\nAdd a stretch")
    }

    func testCoalescingFillsUnfiledSurvivorFromFiledDuplicate() throws {
        let (store, _, container) = makeStore()
        defer { try? FileManager.default.removeItem(at: container) }
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let canonical = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        let folder = WorkoutFolder(id: UUID(), name: "Strength")
        let earliest = Workout(id: UUID(), sourceLink: canonical,
                               savedAt: Date(timeIntervalSince1970: 100))
        var filedDuplicate = Workout(id: UUID(), sourceLink: canonical,
                                     savedAt: Date(timeIntervalSince1970: 200))
        filedDuplicate.folderID = folder.id
        let data = try JSONEncoder().encode(TestLibraryFile(workouts: [filedDuplicate, earliest],
                                                            folders: [folder]))
        try data.write(to: container.appendingPathComponent("Library.json"))

        try store.applyEnrichment(TikTokEnrichment(resolvedLink: canonical, metadata: nil),
                                  to: filedDuplicate.id)

        let merged = try XCTUnwrap(store.load().onlyElement)
        XCTAssertEqual(merged.id, earliest.id, "Coalescing should keep the earliest save")
        XCTAssertEqual(merged.folderID, folder.id,
                       "Coalescing should fill the survivor's empty folder from its duplicate")
    }
}

private struct TestLibraryFile: Encodable {
    let schemaVersion = 1
    let workouts: [Workout]
    var folders: [WorkoutFolder]? = nil
}

private extension Array {
    var onlyElement: Element? { count == 1 ? first : nil }
}
