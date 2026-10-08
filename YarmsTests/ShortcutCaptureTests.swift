import XCTest
@testable import Yarms

final class ShortcutCaptureTests: XCTestCase {
    func testSharedTikTokTextIsDurableAndAppearsInLibrary() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let inbox = SharedInbox(directory: directory.appendingPathComponent("Inbox"))
        let store = WorkoutStore(fileURL: directory.appendingPathComponent("Library.json"), inbox: inbox)
        let sharedText = "Coach https://example.com/profile Workout https://www.tiktok.com/@coach/video/123?lang=en"

        let captured = try WorkoutCapture.save(sharedText, to: inbox)

        XCTAssertEqual(captured.link.url.absoluteString, "https://www.tiktok.com/@coach/video/123")
        XCTAssertEqual(try inbox.load().map(\.id), [captured.id])
        XCTAssertEqual(try store.importPending().map(\.sourceLink), [captured.link])
        XCTAssertTrue(try inbox.load().isEmpty)
        XCTAssertEqual(try store.load().map(\.sourceLink), [captured.link])
    }

    func testInvalidSharedTextDoesNotClaimToSave() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let inbox = SharedInbox(directory: directory)

        XCTAssertThrowsError(try WorkoutCapture.save("https://example.com/workout", to: inbox)) { error in
            XCTAssertEqual(error as? WorkoutCaptureError, .invalidLink)
        }
        XCTAssertTrue(try inbox.load().isEmpty)
    }

    func testFileAndShareInboxesImportWithoutDuplicateWorkouts() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileInbox = SharedInbox(directory: directory.appendingPathComponent("FileInbox"))
        let shareInbox = SharedInbox(directory: directory.appendingPathComponent("ShareInbox"))
        let store = WorkoutStore(fileURL: directory.appendingPathComponent("Library.json"),
                                 inbox: fileInbox, shareInbox: shareInbox)
        let first = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        let second = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/456"))
        try fileInbox.save(first)
        try shareInbox.save(first)
        try shareInbox.save(second)

        let imported = try store.importPending()

        XCTAssertEqual(Set(imported.map(\.sourceLink)), Set([first, second]))
        XCTAssertEqual(try store.importPending().count, 2)
        XCTAssertTrue(try fileInbox.load().isEmpty)
        XCTAssertTrue(try shareInbox.load().isEmpty)
    }

    func testResharingEnrichedShortLinkPreservesPersonalDetailsAfterReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileInbox = SharedInbox(directory: directory.appendingPathComponent("FileInbox"))
        let shareInbox = SharedInbox(directory: directory.appendingPathComponent("ShareInbox"))
        let fileURL = directory.appendingPathComponent("Library.json")
        let store = WorkoutStore(fileURL: fileURL, inbox: fileInbox, shareInbox: shareInbox)
        let short = try XCTUnwrap(TikTokLink(text: "https://vt.tiktok.com/InventedReplayA/"))
        let canonical = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@replaycoach/video/901001"))

        XCTAssertEqual(try shareInbox.load().count, 0, "The share queue should start empty")
        let original = try shareInbox.save(short)
        XCTAssertEqual(try shareInbox.load().count, 1, "The first share should be queued")
        XCTAssertEqual(try store.importPending().count, 1)
        XCTAssertEqual(try shareInbox.load().count, 0, "Import should drain the first share")

        try store.applyEnrichment(TikTokEnrichment(resolvedLink: canonical, metadata: nil), to: original.id)
        let folder = try store.createFolder(named: "Replay practice")
        XCTAssertTrue(try store.updateNotes("Keep the warmup", for: original.id))
        XCTAssertTrue(try store.moveWorkout(original.id, to: folder.id))

        try shareInbox.save(short)
        XCTAssertEqual(try shareInbox.load().count, 1, "The exact original source should queue again")
        XCTAssertEqual(try store.importPending().count, 1,
                       "Replaying an enriched source must not create another workout")
        XCTAssertEqual(try shareInbox.load().count, 0, "The replayed share should be acknowledged")

        let reopened = WorkoutStore(fileURL: fileURL, inbox: fileInbox, shareInbox: shareInbox)
        let workouts = try reopened.load()
        XCTAssertEqual(workouts.count, 1, "The canonical video should remain one durable workout")
        let keeper = try XCTUnwrap(workouts.first)
        XCTAssertEqual(keeper.id, original.id, "Replay should retain the original workout identity")
        XCTAssertEqual(keeper.sourceLink, short, "Replay should retain the original short source")
        XCTAssertEqual(keeper.playbackLink, canonical, "Canonical enrichment should survive reload")
        XCTAssertEqual(keeper.notes, "Keep the warmup", "Replay should retain personal notes")
        XCTAssertEqual(keeper.folderID, folder.id, "Replay should retain the folder assignment")
        XCTAssertEqual(try reopened.loadFolders(), [folder], "The assigned folder should survive reload")
    }

    func testReplayingCoalescedAliasesAndCanonicalSourcePreservesKeeperAfterReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileInbox = SharedInbox(directory: directory.appendingPathComponent("FileInbox"))
        let shareInbox = SharedInbox(directory: directory.appendingPathComponent("ShareInbox"))
        let fileURL = directory.appendingPathComponent("Library.json")
        let store = WorkoutStore(fileURL: fileURL, inbox: fileInbox, shareInbox: shareInbox)
        let first = try XCTUnwrap(TikTokLink(text: "https://vt.tiktok.com/InventedReplayFirst/"))
        let second = try XCTUnwrap(TikTokLink(text: "https://vm.tiktok.com/InventedReplaySecond/"))
        let canonical = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@replaycoach/video/901002"))

        let firstEntry = try shareInbox.save(first)
        XCTAssertEqual(try store.importPending().count, 1)
        let secondEntry = try fileInbox.save(second)
        XCTAssertEqual(try store.importPending().count, 2,
                       "Distinct unresolved short sources should both import before enrichment")
        let folder = try store.createFolder(named: "Saved routines")
        XCTAssertTrue(try store.updateNotes("Keep this routine", for: firstEntry.id))
        XCTAssertTrue(try store.moveWorkout(firstEntry.id, to: folder.id))

        try store.applyEnrichment(TikTokEnrichment(resolvedLink: canonical, metadata: nil), to: firstEntry.id)
        try store.applyEnrichment(TikTokEnrichment(resolvedLink: canonical, metadata: nil), to: secondEntry.id)
        let coalesced = try XCTUnwrap(store.load().first)
        XCTAssertEqual(try store.load().count, 1, "Both short sources should coalesce to one video")
        XCTAssertEqual(coalesced.id, firstEntry.id, "The first save should remain the keeper")
        XCTAssertEqual(coalesced.sourceLink, first, "The keeper should retain its first short source")
        XCTAssertEqual(Set(coalesced.sourceAliases ?? []), [second],
                       "Coalescing should remember the second short source")

        try shareInbox.save(first)
        try fileInbox.save(second)
        try fileInbox.save(canonical)
        XCTAssertEqual(try shareInbox.load().count, 1, "The first alias should reach the share queue")
        XCTAssertEqual(try fileInbox.load().count, 2,
                       "The second alias and canonical URL should reach the file queue")
        XCTAssertEqual(try store.importPending().count, 1,
                       "Replaying both aliases and the canonical URL must not add records")
        XCTAssertTrue(try shareInbox.load().isEmpty, "The share queue should drain after replay")
        XCTAssertTrue(try fileInbox.load().isEmpty, "The file queue should drain after replay")

        let reopened = WorkoutStore(fileURL: fileURL, inbox: fileInbox, shareInbox: shareInbox)
        let workouts = try reopened.load()
        XCTAssertEqual(workouts.count, 1, "Coalescing and replay should remain durable")
        let keeper = try XCTUnwrap(workouts.first)
        XCTAssertEqual(keeper.id, firstEntry.id, "The original keeper identity should survive restart")
        XCTAssertEqual(keeper.sourceLink, first)
        XCTAssertEqual(keeper.playbackLink, canonical)
        XCTAssertEqual(Set(keeper.sourceAliases ?? []), [second],
                       "The second short alias should survive restart")
        XCTAssertEqual(keeper.notes, "Keep this routine", "Personal notes should survive replay")
        XCTAssertEqual(keeper.folderID, folder.id, "The folder assignment should survive replay")
        XCTAssertEqual(try reopened.loadFolders(), [folder])
    }
}
