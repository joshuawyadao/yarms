import XCTest
@testable import Yarms

final class FoundationTests: XCTestCase {
    func testCanonicalVideoLinkBuildsOfficialPlayerURL() throws {
        let link = try XCTUnwrap(TikTokLink(text: "Watch https://www.tiktok.com/@coach/video/123456?is_from_webapp=1"))
        XCTAssertEqual(link.url.absoluteString, "https://www.tiktok.com/@coach/video/123456")
        XCTAssertEqual(link.videoID, "123456")
        XCTAssertEqual(link.playerURL?.absoluteString, "https://www.tiktok.com/player/v1/123456?controls=1")
    }

    func testShortLinkIsSavedWithoutAssumingVideoID() throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://vm.tiktok.com/ZMabcdef/"))
        XCTAssertNil(link.videoID)
        XCTAssertNil(link.playerURL)
        let webShortLink = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/t/ZTabcdef/"))
        XCTAssertNil(webShortLink.videoID)
    }

    func testRejectsLookalikeAndInsecureLinks() {
        XCTAssertNil(TikTokLink(text: "https://tiktok.com.evil.example/@a/video/123"))
        XCTAssertNil(TikTokLink(text: "http://www.tiktok.com/@a/video/123"))
        XCTAssertNil(TikTokLink(text: "https://www.tiktok.com/@a"))
    }

    func testFindsTikTokVideoAfterAnotherURLInSharedText() throws {
        let text = "Coach profile https://example.com/coach Workout https://www.tiktok.com/@coach/video/123456"
        let link = try XCTUnwrap(TikTokLink(text: text))
        XCTAssertEqual(link.videoID, "123456")
    }

    func testInboxPersistsIndependentShares() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let inbox = SharedInbox(directory: directory)
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@a/video/123"))
        try inbox.save(link)
        try inbox.save(link)
        let saved = try inbox.load()
        XCTAssertEqual(saved.count, 2)
        XCTAssertNotEqual(saved[0].id, saved[1].id)
        XCTAssertTrue(saved.allSatisfy { $0.link == link })
    }

    func testDamagedInboxFileDoesNotHideValidShare() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let inbox = SharedInbox(directory: directory)
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@a/video/123"))
        try inbox.save(link)
        try Data("broken".utf8).write(to: directory.appendingPathComponent("damaged.json"))
        XCTAssertEqual(try inbox.load().map(\.link), [link])
    }

    func testUITestStoreUsesUniqueTemporaryContainerAndRejectsInvalidIdentifier() {
        let support = URL(fileURLWithPath: "/support")
        let temporary = URL(fileURLWithPath: "/temporary")
        let identifier = UUID()
        let testArguments = ["Yarms", SharedInbox.uiTestStoreArgument, identifier.uuidString]

        XCTAssertEqual(
            SharedInbox.container(arguments: testArguments, applicationSupport: support, temporaryDirectory: temporary),
            temporary.appendingPathComponent("YarmsUITests/\(identifier.uuidString)", isDirectory: true),
            "A valid UI-test ID should choose its own temporary container"
        )
        XCTAssertNil(SharedInbox.container(
            arguments: ["Yarms", SharedInbox.uiTestStoreArgument, "invalid"],
            applicationSupport: support,
            temporaryDirectory: temporary
        ), "An invalid UI-test ID must not fall back to the normal library")
        XCTAssertEqual(
            SharedInbox.container(arguments: ["Yarms"], applicationSupport: support, temporaryDirectory: temporary),
            support.appendingPathComponent("Yarms", isDirectory: true),
            "A normal launch should keep the regular Application Support library"
        )
    }
}
