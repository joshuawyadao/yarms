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
    }

    func testOEmbedFailureKeepsCanonicalLink() async throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@trainer/video/12345"))
        MockURLProtocol.handler = { _ in (503, [:], Data()) }

        let result = await client().enrich(link)
        XCTAssertEqual(result.resolvedLink, link)
        XCTAssertNil(result.metadata)
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
                XCTAssertEqual(request.httpMethod, "HEAD")
                return (200, [:], Data())
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
        XCTAssertEqual(requestedURLs.count, 3)
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
    }

    private func client() -> TikTokMetadataClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return TikTokMetadataClient(session: URLSession(configuration: configuration))
    }
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
