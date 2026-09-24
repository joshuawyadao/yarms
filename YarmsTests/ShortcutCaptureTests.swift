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
}
