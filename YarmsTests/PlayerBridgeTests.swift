import XCTest
import WebKit
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

    @MainActor
    func testCommandsWaitForReadyEventFromWebKit() throws {
        let page = makeLocalPlayerPage()

        page.controller.send(.play)
        XCTAssertEqual(try page.commands(), [])

        try page.emit(type: "onPlayerReady", value: ["duration": 40])
        waitForState { page.controller.isReady }
        XCTAssertEqual(page.controller.duration, 40)

        page.controller.send(.play)
        page.controller.send(.pause)
        XCTAssertEqual(try page.commands(), ["play:null", "pause:null"])
    }

    @MainActor
    func testPlaybackStateTransitionsThroughWebKitHandler() throws {
        let page = makeLocalPlayerPage()
        try page.emit(type: "onPlayerReady", value: NSNull())
        waitForState { page.controller.isReady }

        try page.emit(type: "onStateChange", value: 1)
        waitForState { page.controller.isPlaying }
        try page.emit(type: "onStateChange", value: 2)
        waitForState { !page.controller.isPlaying }
        try page.emit(type: "onStateChange", value: 1)
        waitForState { page.controller.isPlaying }
        try page.emit(type: "onStateChange", value: 3)
        waitForState { !page.controller.isPlaying }

        try page.emit(type: "onCurrentTime", value: ["currentTime": 12, "duration": 40])
        waitForState { page.controller.currentTime == 12 }
        try page.emit(type: "onStateChange", value: 1)
        waitForState { page.controller.isPlaying }
        try page.emit(type: "onStateChange", value: 0)
        waitForState { !page.controller.isPlaying && page.controller.currentTime == 40 }
    }

    @MainActor
    func testTimeAndDurationCanArriveInEitherOrderAndStayWithinBounds() throws {
        let page = makeLocalPlayerPage()
        try page.emit(type: "onCurrentTime", value: ["currentTime": 12, "duration": 40])
        waitForState { page.controller.currentTime == 12 && page.controller.duration == 40 }
        try page.emit(type: "onPlayerReady", value: NSNull())
        waitForState { page.controller.isReady }
        XCTAssertEqual(page.controller.duration, 40)

        try page.emit(type: "onCurrentTime", value: ["currentTime": 55])
        waitForState { page.controller.currentTime == 40 }
        try page.emit(type: "onPlayerReady", value: ["duration": 60])
        waitForState { page.controller.duration == 60 }
        try page.emit(type: "onCurrentTime", value: ["currentTime": 50])
        waitForState { page.controller.currentTime == 50 }
    }

    @MainActor
    func testErrorStopsPlaybackAndRecordsFailure() throws {
        let page = makeLocalPlayerPage()
        try page.emit(type: "onPlayerReady", value: NSNull())
        waitForState { page.controller.isReady }
        try page.emit(type: "onStateChange", value: 1)
        waitForState { page.controller.isPlaying }

        try page.emit(type: "onPlayerError", value: NSNull())
        waitForState { page.controller.hasError && !page.controller.isPlaying }
    }

    @MainActor
    func testSeekCommandsClampWithKnownAndUnknownDuration() throws {
        let page = makeLocalPlayerPage()
        page.controller.seek(by: 10)
        XCTAssertEqual(try page.commands(), [])

        try page.emit(type: "onPlayerReady", value: NSNull())
        waitForState { page.controller.isReady }
        try page.emit(type: "onCurrentTime", value: ["currentTime": 5])
        waitForState { page.controller.currentTime == 5 }
        page.controller.seek(by: -10)
        page.controller.seek(by: 10)
        XCTAssertEqual(try page.commands(), ["seekTo:0", "seekTo:15"])

        try page.emit(type: "onCurrentTime", value: ["currentTime": 35, "duration": 40])
        waitForState { page.controller.currentTime == 35 && page.controller.duration == 40 }
        page.controller.seek(by: 10)
        page.controller.seek(by: -50)
        XCTAssertEqual(try page.commands(), ["seekTo:0", "seekTo:15", "seekTo:40", "seekTo:0"])
    }

    @MainActor
    private func makeLocalPlayerPage() -> LocalPlayerPage {
        let page = LocalPlayerPage()
        let loaded = expectation(description: "local player page loaded")
        page.didLoad = { loaded.fulfill() }
        page.load()
        wait(for: [loaded], timeout: 5)
        return page
    }

    @MainActor
    private func waitForState(_ condition: @escaping () -> Bool) {
        let changed = expectation(description: "player state changed")
        let deadline = Date().addingTimeInterval(2)
        @MainActor func check() {
            if condition() {
                changed.fulfill()
            } else if Date() < deadline {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { @MainActor in
                    check()
                }
            }
        }
        check()
        wait(for: [changed], timeout: 2.5)
    }

    private func envelope(type: String, value: Any) -> [String: Any] {
        [
            "origin": "https://www.tiktok.com",
            "message": ["x-tiktok-player": true, "type": type, "value": value]
        ]
    }
}

private final class LocalPlayerPage: NSObject, WKNavigationDelegate {
    let controller = TikTokPlayerController()
    let webView: WKWebView
    var didLoad: (() -> Void)?

    override init() {
        let content = WKUserContentController()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = content
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        content.add(controller, name: "yarmsPlayerEvents")
        controller.connect(webView)
        webView.navigationDelegate = self
    }

    func load() {
        webView.loadHTMLString("""
            <!doctype html><html><body><script>
            window.commands = [];
            window.yarmsPlayerCommand = function(message) {
                window.commands.push(message);
            };
            window.emitPlayerEvent = function(type, value) {
                window.webkit.messageHandlers.yarmsPlayerEvents.postMessage({
                    origin: 'https://www.tiktok.com',
                    message: {'x-tiktok-player': true, type: type, value: value}
                });
            };
            </script></body></html>
            """, baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        didLoad?()
        didLoad = nil
    }

    func emit(type: String, value: Any) throws {
        let data = try JSONSerialization.data(withJSONObject: ["type": type, "value": value],
                                              options: [.fragmentsAllowed])
        let argument = try XCTUnwrap(String(data: data, encoding: .utf8))
        try evaluate("{ const event = \(argument); window.emitPlayerEvent(event.type, event.value); }")
    }

    func commands() throws -> [String] {
        let result = try evaluate("window.commands.map(item => item.type + ':' + item.value)")
        return try XCTUnwrap(result as? [String])
    }

    @discardableResult
    private func evaluate(_ script: String) throws -> Any? {
        let evaluated = XCTestExpectation(description: "JavaScript evaluated")
        var result: Any?
        var error: Error?
        webView.evaluateJavaScript(script) { value, failure in
            result = value
            error = failure
            evaluated.fulfill()
        }
        let outcome = XCTWaiter.wait(for: [evaluated], timeout: 5)
        XCTAssertEqual(outcome, .completed)
        if let error { throw error }
        return result
    }
}
