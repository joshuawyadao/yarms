import Foundation
import XCTest
@testable import Yarms

final class MetadataTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testCanonicalLinkFetchesOfficialOEmbedFields() async throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@trainer/video/12345"))
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.scheme, "https")
            XCTAssertEqual(components.host, "www.tiktok.com")
            XCTAssertEqual(components.path, "/oembed")
            XCTAssertEqual(components.queryItems?.first(where: { $0.name == "url" })?.value,
                           link.url.absoluteString)
            return (200, [:], Data(#"{"title":"  Full body workout  ","author_name":" Trainer ","thumbnail_url":"https://p16.tiktokcdn.com/cover.jpg"}"#.utf8))
        }

        let result = await client().enrich(link)
        XCTAssertEqual(result.resolvedLink, link)
        XCTAssertEqual(result.metadata?.title, "Full body workout")
        XCTAssertEqual(result.metadata?.creator, "Trainer")
        XCTAssertEqual(result.metadata?.thumbnailURL?.absoluteString,
                       "https://p16.tiktokcdn.com/cover.jpg")
        XCTAssertEqual(result.outcome, .success)
    }

    func testOEmbedFailureKeepsCanonicalLink() async throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@trainer/video/12345"))
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/oembed")
            return (503, [:], Data())
        }

        let result = await client().enrich(link)
        XCTAssertEqual(result.resolvedLink, link)
        XCTAssertNil(result.metadata)
        XCTAssertEqual(result.outcome, .retryableFailure)
    }

    func testShortLinkResolvesOnlyThroughTikTokAndThenFetchesMetadata() async throws {
        let short = try XCTUnwrap(TikTokLink(text: "https://vm.tiktok.com/ZMshort/"))
        var requestedURLs = [URL]()
        MockURLProtocol.handler = { request in
            requestedURLs.append(try XCTUnwrap(request.url))
            switch request.url?.host {
            case "vm.tiktok.com":
                XCTAssertEqual(request.httpMethod, "HEAD")
                return (302, ["Location": "https://www.tiktok.com/@trainer/video/98765?tracking=1"], Data())
            case "www.tiktok.com" where request.url?.path == "/@trainer/video/98765":
                XCTAssertEqual(request.httpMethod, "GET")
                return (200, [:], self.publicPage(videoID: "98765"))
            case "www.tiktok.com" where request.url?.path == "/oembed":
                XCTAssertEqual(request.httpMethod, "GET")
                return (200, [:], Data(#"{"title":"Strength","author_name":"Coach"}"#.utf8))
            default:
                XCTFail("Unexpected request: \(String(describing: request.url))")
                return (404, [:], Data())
            }
        }

        let result = await client().enrich(short)
        XCTAssertEqual(result.resolvedLink?.url.absoluteString,
                       "https://www.tiktok.com/@trainer/video/98765")
        XCTAssertEqual(result.resolvedLink?.videoID, "98765")
        XCTAssertEqual(result.metadata?.title, "Strength")
        XCTAssertEqual(result.metadata?.thumbnailURL?.host, "p16-sign.tiktokcdn-us.com")
        XCTAssertEqual(requestedURLs.map(\.path), ["/ZMshort", "/oembed", "/@trainer/video/98765"])
    }

    func testPublicPageFillsMissingOEmbedFieldsForMatchingVideo() async throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://m.tiktok.com/@trainer/video/12345"))
        let originCover = "https://p16-sign.tiktokcdn-us.com/cover.jpeg?x-expires=1957851434&x-signature=abc%2Bdef"
        MockURLProtocol.handler = { request in
            if request.url?.path == "/oembed" {
                return (200, [:], Data(#"{"title":"oEmbed title","html":"<iframe></iframe>"}"#.utf8))
            }
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.absoluteString, "https://www.tiktok.com/@trainer/video/12345")
            XCTAssertFalse(request.httpShouldHandleCookies)
            return (200, [:], self.publicPage(cover: "https://cdn.example.com/cover.jpeg", originCover: originCover))
        }

        let result = await client().enrich(link)
        XCTAssertEqual(result.outcome, .success)
        XCTAssertEqual(result.metadata?.title, "oEmbed title")
        XCTAssertEqual(result.metadata?.creator, "Page creator")
        XCTAssertEqual(result.metadata?.thumbnailURL?.absoluteString, originCover)
    }

    func testExpiredPosterFallsBackToCurrentOriginCover() async throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@trainer/video/12345"))
        let expired = "https://p16.tiktokcdn.com/expired.jpeg?x-expires=1"
        let fresh = "https://p16-sign.tiktokcdn-us.com/current.jpeg"

        MockURLProtocol.handler = { request in
            if request.url?.path == "/oembed" {
                let body = try JSONSerialization.data(withJSONObject: ["thumbnail_url": expired])
                return (200, [:], body)
            }
            return (200, [:], self.publicPage(cover: expired, originCover: fresh))
        }

        let result = await client().enrich(link)
        XCTAssertEqual(result.outcome, .success)
        XCTAssertEqual(result.metadata?.thumbnailURL?.absoluteString, fresh,
                       "Reject both expired candidates before choosing the alternate cover")
    }

    func testRateLimitedPublicPagePreservesOEmbedAndSchedulesRetry() async throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@trainer/video/12345"))
        MockURLProtocol.handler = { request in
            if request.url?.path == "/oembed" {
                return (200, [:], Data(#"{"title":"Strength","author_name":"Coach"}"#.utf8))
            }
            return (429, ["Retry-After": "120"], Data())
        }

        let startedAt = Date()
        let result = await client().enrich(link)
        XCTAssertEqual(result.metadata?.title, "Strength")
        XCTAssertEqual(result.metadata?.creator, "Coach")
        XCTAssertEqual(result.outcome, .retryableFailure)
        let deadline = try XCTUnwrap(result.retryAfter, "The optional page lookup must carry its retry deadline")
        XCTAssertGreaterThanOrEqual(deadline.timeIntervalSince(startedAt), 120)
        let state = WorkoutEnrichmentState.after(result: result, previous: nil, now: startedAt)
        XCTAssertEqual(state.status, .pending, "A rate-limited poster must remain eligible for background retry")
        XCTAssertEqual(state.nextAttemptAt, deadline)
    }

    func testPublicPageCannotSupplyMetadataForAnotherVideo() async throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@trainer/video/12345"))
        MockURLProtocol.handler = { request in
            if request.url?.path == "/oembed" {
                return (200, [:], Data(#"{"author_name":"oEmbed creator"}"#.utf8))
            }
            return (200, [:], self.publicPage(videoID: "98765"))
        }

        let result = await client().enrich(link)
        XCTAssertEqual(result.outcome, .success)
        XCTAssertNil(result.metadata?.title)
        XCTAssertEqual(result.metadata?.creator, "oEmbed creator")
        XCTAssertNil(result.metadata?.thumbnailURL)
    }

    func testPublicPageRejectsUntrustedCoverURLs() async throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@trainer/video/12345"))
        let rejectedCovers = [
            "http://p16.tiktokcdn.com/cover.jpeg",
            "https://p16.tiktokcdn.com.example.com/cover.jpeg",
            "https://eviltiktokcdn.com/cover.jpeg",
            "https://test@p16.tiktokcdn.com/cover.jpeg",
            "https://p16.tiktokcdn.com:443/cover.jpeg"
        ]
        for cover in rejectedCovers {
            MockURLProtocol.handler = { request in
                if request.url?.path == "/oembed" {
                    return (200, [:], Data("{}".utf8))
                }
                return (200, [:], self.publicPage(cover: cover))
            }

            let result = await client().enrich(link)
            XCTAssertEqual(result.metadata?.title, "Page caption")
            XCTAssertNil(result.metadata?.thumbnailURL, cover)
        }
    }

    func testPublicPageDoesNotRequestARedirectDestination() async throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@trainer/video/12345"))
        let transport = RedirectTransport(redirectingPath: link.url.path)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RedirectingURLProtocol.self]
        RedirectingURLProtocol.transport = transport
        defer { RedirectingURLProtocol.transport = nil }

        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let result = await TikTokMetadataClient(session: session).enrich(link)

        XCTAssertEqual(result.outcome, .success)
        XCTAssertNil(result.metadata?.thumbnailURL)
        XCTAssertEqual(transport.redirectCount, 1)
        XCTAssertEqual(transport.requestedHosts, ["www.tiktok.com", "www.tiktok.com"])
    }

    func testPublicPageDoesNotRequestAnExternalSourceHost() async throws {
        let link = try JSONDecoder().decode(TikTokLink.self, from: Data(
            #"{"url":"https://example.com/@trainer/video/12345","videoID":"12345"}"#.utf8
        ))
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "www.tiktok.com")
            XCTAssertEqual(request.url?.path, "/oembed")
            return (200, [:], Data("{}".utf8))
        }

        let result = await client().enrich(link)
        XCTAssertNil(result.metadata?.thumbnailURL)
    }

    func testPublicPageCannotSupplyMetadataAboveTheSizeLimit() async throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@trainer/video/12345"))
        var oversizedPage = publicPage()
        oversizedPage.append(Data(repeating: 32, count: 2 * 1_024 * 1_024))
        MockURLProtocol.handler = { request in
            if request.url?.path == "/oembed" {
                return (200, [:], Data("{}".utf8))
            }
            return (200, [:], oversizedPage)
        }

        let result = await client().enrich(link)
        XCTAssertEqual(result.outcome, .success)
        XCTAssertNil(result.metadata?.thumbnailURL)
    }

    func testExternalRedirectIsRejectedBeforeRequestingDestination() async throws {
        let short = try XCTUnwrap(TikTokLink(text: "https://vm.tiktok.com/ZMshort/"))
        var requestedHosts = [String]()
        MockURLProtocol.handler = { request in
            requestedHosts.append(try XCTUnwrap(request.url?.host))
            if request.url?.host == "vm.tiktok.com" {
                return (302, ["Location": "https://example.com/steal"], Data())
            }
            XCTAssertEqual(request.url?.path, "/oembed")
            let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.queryItems?.first?.value, short.url.absoluteString)
            return (503, [:], Data())
        }

        let result = await client().enrich(short)
        XCTAssertNil(result.resolvedLink)
        XCTAssertNil(result.metadata)
        XCTAssertEqual(requestedHosts, ["vm.tiktok.com", "www.tiktok.com"])
    }

    func testURLSessionDoesNotAutomaticallyFollowExternalRedirect() async throws {
        let short = try XCTUnwrap(TikTokLink(text: "https://vm.tiktok.com/ZMshort/"))
        let transport = RedirectTransport()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RedirectingURLProtocol.self]
        RedirectingURLProtocol.transport = transport
        defer { RedirectingURLProtocol.transport = nil }

        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let result = await TikTokMetadataClient(session: session).enrich(short)

        XCTAssertNil(result.resolvedLink)
        XCTAssertNil(result.metadata)
        XCTAssertEqual(transport.redirectCount, 1, "The fixture must exercise URLSession's redirect callback")
        XCTAssertEqual(transport.requestedHosts, ["vm.tiktok.com", "www.tiktok.com"],
                       "URLSession must not request the redirect destination before its host is validated")
    }

    func testUnavailableHEADCanStillGetShortLinkOEmbedWithoutPlaybackURL() async throws {
        let short = try XCTUnwrap(TikTokLink(text: "https://vt.tiktok.com/ZMshort/"))
        MockURLProtocol.handler = { request in
            if request.url?.host == "vt.tiktok.com" {
                return (403, [:], Data())
            }
            XCTAssertEqual(request.url?.path, "/oembed")
            let url = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            XCTAssertEqual(url.queryItems?.first?.value, short.url.absoluteString)
            return (200, [:], Data(#"{"title":"A short workout","author_name":"Coach"}"#.utf8))
        }

        let result = await client().enrich(short)
        XCTAssertNil(result.resolvedLink)
        XCTAssertEqual(result.metadata?.title, "A short workout")
        XCTAssertEqual(result.metadata?.creator, "Coach")
        XCTAssertEqual(result.outcome, .permanentFailure)
    }

    func testRetryAfterSecondsAndDateOnRateLimit() async throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@trainer/video/12345"))
        MockURLProtocol.handler = { _ in (429, ["Retry-After": "120"], Data()) }
        let before = Date()
        let seconds = await client().enrich(link)
        XCTAssertEqual(seconds.outcome, .retryableFailure)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(seconds.retryAfter), before.addingTimeInterval(119))

        MockURLProtocol.handler = { _ in (503, ["Retry-After": "Wed, 21 Oct 2037 07:28:00 GMT"], Data()) }
        let dated = await client().enrich(link)
        XCTAssertGreaterThan(try XCTUnwrap(dated.retryAfter), Date().addingTimeInterval(86_390))
    }

    func testShortLinkTimeoutRemainsRetryableWithSuccessfulMetadata() async throws {
        let short = try XCTUnwrap(TikTokLink(text: "https://vt.tiktok.com/ZMshort/"))
        var requests = 0
        MockURLProtocol.handler = { request in
            requests += 1
            if request.httpMethod == "HEAD" { throw URLError(.timedOut) }
            XCTAssertEqual(request.url?.path, "/oembed")
            return (200, [:], Data(#"{"title":"Workout","thumbnail_url":"https://p16.tiktokcdn.com/cover.jpg"}"#.utf8))
        }

        let result = await client().enrich(short)
        XCTAssertNil(result.resolvedLink)
        XCTAssertEqual(result.metadata?.title, "Workout")
        XCTAssertNotNil(result.metadata?.thumbnailURL)
        XCTAssertEqual(result.outcome, .retryableFailure)
        let now = Date(timeIntervalSince1970: 1_000)
        let state = WorkoutEnrichmentState.after(result: result, previous: nil, now: now)
        XCTAssertEqual(state.status, .pending)
        XCTAssertEqual(state.nextAttemptAt, now.addingTimeInterval(60))
        XCTAssertEqual(requests, 2)
    }

    func testShortLinkServerFailureRemainsRetryableWhenOEmbedRejectsURL() async throws {
        let short = try XCTUnwrap(TikTokLink(text: "https://vm.tiktok.com/ZMshort/"))
        MockURLProtocol.handler = { request in
            request.httpMethod == "HEAD" ? (503, ["Retry-After": "120"], Data()) : (404, [:], Data())
        }

        let before = Date()
        let result = await client().enrich(short)
        XCTAssertNil(result.resolvedLink)
        XCTAssertNil(result.metadata)
        XCTAssertEqual(result.outcome, .retryableFailure)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(result.retryAfter), before.addingTimeInterval(120))
        let state = WorkoutEnrichmentState.after(result: result, previous: nil, now: before)
        XCTAssertEqual(state.status, .pending)
        XCTAssertEqual(state.nextAttemptAt, result.retryAfter)
    }

    func testShortLinkAndMetadataFailuresHonorLaterRetryAfter() async throws {
        let short = try XCTUnwrap(TikTokLink(text: "https://vm.tiktok.com/ZMshort/"))
        // Exercise both orderings: neither endpoint may shorten the other's delay.
        for headDelay in [120, 240] {
            let metadataDelay = 360 - headDelay
            MockURLProtocol.handler = { request in
                request.httpMethod == "HEAD" ?
                    (429, ["Retry-After": String(headDelay)], Data()) :
                    (503, ["Retry-After": String(metadataDelay)], Data())
            }
            let before = Date()
            let result = await client().enrich(short)
            XCTAssertEqual(result.outcome, .retryableFailure)
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(result.retryAfter), before.addingTimeInterval(240))
            XCTAssertLessThanOrEqual(try XCTUnwrap(result.retryAfter), Date().addingTimeInterval(240))
        }
    }

    func testValidEmptyOptionalMetadataDoesNotCauseRetry() async throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@trainer/video/12345"))
        MockURLProtocol.handler = { _ in (200, [:], Data("{}".utf8)) }
        let result = await client().enrich(link)
        XCTAssertEqual(result.outcome, .success)
        XCTAssertNotNil(result.metadata)
    }

    func testInvalidOrExcessiveRetryAfterIsBounded() async throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@trainer/video/12345"))
        MockURLProtocol.handler = { _ in (429, ["Retry-After": "inf"], Data()) }
        let invalid = await client().enrich(link)
        XCTAssertNil(invalid.retryAfter)

        MockURLProtocol.handler = { _ in (429, ["Retry-After": "999999999"], Data()) }
        let before = Date()
        let bounded = await client().enrich(link)
        XCTAssertLessThanOrEqual(try XCTUnwrap(bounded.retryAfter), before.addingTimeInterval(86_405))
    }

    private func client() -> TikTokMetadataClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return TikTokMetadataClient(session: URLSession(configuration: configuration))
    }

    private func publicPage(videoID: String = "12345",
                            cover: String = "https://p16-sign.tiktokcdn-us.com/cover.jpeg",
                            originCover: String = "") -> Data {
        Data("""
        <html><head>
        <script type="application/json" id="__UNIVERSAL_DATA_FOR_REHYDRATION__">
        {"__DEFAULT_SCOPE__":{"webapp.video-detail":{"itemInfo":{"itemStruct":{
          "id":"\(videoID)", "desc":" Page caption ",
          "author":{"nickname":" Page creator ","uniqueId":"creator"},
          "video":{"cover":"\(cover)","originCover":"\(originCover)"}
        }}}}}
        </script>
        </head></html>
        """.utf8)
    }
}

private final class RedirectTransport {
    private let lock = NSLock()
    private var hosts = [String]()
    private var redirects = 0
    private let redirectingPath: String?

    init(redirectingPath: String? = nil) {
        self.redirectingPath = redirectingPath
    }

    var requestedHosts: [String] { lock.withLock { hosts } }
    var redirectCount: Int { lock.withLock { redirects } }

    func record(_ request: URLRequest) {
        lock.withLock { hosts.append(request.url?.host ?? "<missing host>") }
    }

    func recordRedirect() {
        lock.withLock { redirects += 1 }
    }

    func shouldRedirect(_ url: URL) -> Bool {
        if let redirectingPath { return url.path == redirectingPath }
        return url.host == "vm.tiktok.com"
    }

    var nonRedirectingStatus: Int { redirectingPath == nil ? 503 : 200 }
}

private final class RedirectingURLProtocol: URLProtocol {
    static var transport: RedirectTransport?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let transport = Self.transport else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        transport.record(request)

        if transport.shouldRedirect(url) {
            let destination = URL(string: "https://example.com/steal")!
            let response = HTTPURLResponse(url: url, statusCode: 302, httpVersion: "HTTP/1.1",
                                           headerFields: ["Location": destination.absoluteString])!
            transport.recordRedirect()
            // Supplying the original response lets async URLSession.data finish
            // with the 302 when its task delegate declines the redirect.
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: destination),
                                redirectResponse: response)
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        let response = HTTPURLResponse(url: url, statusCode: transport.nonRedirectingStatus, httpVersion: "HTTP/1.1",
                                       headerFields: [:])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if transport.nonRedirectingStatus == 200 {
            client?.urlProtocol(self, didLoad: Data("{}".utf8))
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, [String: String], Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let handler = try XCTUnwrap(Self.handler)
            let (status, headers, data) = try handler(request)
            let response = try XCTUnwrap(HTTPURLResponse(url: request.url!, statusCode: status,
                                                         httpVersion: "HTTP/1.1", headerFields: headers))
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
