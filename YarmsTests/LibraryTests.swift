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
}
