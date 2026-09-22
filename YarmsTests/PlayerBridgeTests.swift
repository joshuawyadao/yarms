import XCTest
@testable import Yarms

final class PlayerBridgeTests: XCTestCase {
    func testOfficialPlayerEventsDecodeFromMainFrame() {
        let ready = envelope(type: "onPlayerReady", value: NSNull())
        let playing = envelope(type: "onStateChange", value: 1)
        let time = envelope(type: "onCurrentTime",
                            value: ["currentTime": 12.5, "duration": 40.0])

        XCTAssertEqual(TikTokPlayerEvent.parse(ready, fromMainFrame: true), .ready(duration: nil))
        XCTAssertEqual(TikTokPlayerEvent.parse(playing, fromMainFrame: true), .state(1))
        XCTAssertEqual(TikTokPlayerEvent.parse(time, fromMainFrame: true),
                       .time(current: 12.5, duration: 40))
    }

    func testDurationFromReadyAndCurrentTimeWithoutDuration() {
        let ready = envelope(type: "onPlayerReady", value: ["duration": 40.0])
        let time = envelope(type: "onCurrentTime", value: ["currentTime": 12.5])

        XCTAssertEqual(TikTokPlayerEvent.parse(ready, fromMainFrame: true),
                       .ready(duration: 40))
        XCTAssertEqual(TikTokPlayerEvent.parse(time, fromMainFrame: true),
                       .time(current: 12.5, duration: nil))
    }

    func testForeignAndChildFrameMessagesAreIgnored() {
        var foreign = envelope(type: "onPlayerReady", value: NSNull())
        foreign["origin"] = "https://example.com"
        let official = envelope(type: "onPlayerReady", value: NSNull())

        XCTAssertNil(TikTokPlayerEvent.parse(foreign, fromMainFrame: true))
        XCTAssertNil(TikTokPlayerEvent.parse(official, fromMainFrame: false))
    }

    func testMalformedPlayerTimeIsIgnored() {
        let negative = envelope(type: "onCurrentTime",
                                value: ["currentTime": -1.0, "duration": 40.0])
        let missing = envelope(type: "onCurrentTime", value: ["duration": 40.0])

        XCTAssertNil(TikTokPlayerEvent.parse(negative, fromMainFrame: true))
        XCTAssertNil(TikTokPlayerEvent.parse(missing, fromMainFrame: true))
    }

    func testCommandsUseDocumentedPlayerMessageAndSafeSeekValue() {
        XCTAssertTrue(TikTokPlayerCommand.play.javaScript.contains("type:'play'"))
        XCTAssertTrue(TikTokPlayerCommand.pause.javaScript.contains("type:'pause'"))
        XCTAssertTrue(TikTokPlayerCommand.seekTo(12.5).javaScript.contains("value:12.5"))
        XCTAssertTrue(TikTokPlayerCommand.seekTo(-10).javaScript.contains("value:0.0"))
        XCTAssertTrue(TikTokPlayerCommand.seekTo(.infinity).javaScript.contains("value:0.0"))
        XCTAssertTrue(TikTokPlayerCommand.play.javaScript.contains("'x-tiktok-player':true"))
    }

    func testHostDocumentAcceptsOnlyNumericOfficialPlayerPath() throws {
        let official = try XCTUnwrap(URL(string: "https://www.tiktok.com/player/v1/123?controls=1"))
        let external = try XCTUnwrap(URL(string: "https://example.com/player/v1/123"))
        let wrongPath = try XCTUnwrap(URL(string: "https://www.tiktok.com/player/v1/x/123"))

        let html = try XCTUnwrap(TikTokPlayerHTML.document(for: official))
        XCTAssertTrue(html.contains("https://www.tiktok.com/player/v1/123?controls=1"))
        XCTAssertTrue(html.contains("event.origin !== 'https://www.tiktok.com'"))
        XCTAssertTrue(html.contains("postMessage(message, 'https://www.tiktok.com')"))
        XCTAssertNil(TikTokPlayerHTML.document(for: external))
        XCTAssertNil(TikTokPlayerHTML.document(for: wrongPath))
    }

    private func envelope(type: String, value: Any) -> [String: Any] {
        [
            "origin": "https://www.tiktok.com",
            "message": ["x-tiktok-player": true, "type": type, "value": value]
        ]
    }
}
