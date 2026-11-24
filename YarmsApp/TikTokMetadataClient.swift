import Foundation

struct TikTokMetadata: Equatable {
    let title: String?
    let creator: String?
    let thumbnailURL: URL?

    static func thumbnailIsExpired(_ url: URL, at date: Date) -> Bool {
        guard let fields = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let value = fields.first(where: { $0.name == "x-expires" })?.value,
              let expires = TimeInterval(value), expires.isFinite else { return false }
        return expires <= date.timeIntervalSince1970
    }
}

struct TikTokEnrichment {
    enum Outcome: Equatable { case success, retryableFailure, permanentFailure }
    let resolvedLink: TikTokLink?
    let metadata: TikTokMetadata?
    var outcome: Outcome = .success
    var retryAfter: Date? = nil
}

struct TikTokMetadataClient {
    private static let maximumPublicPageBytes = 2 * 1_024 * 1_024
    private static let publicPagePayload = try! NSRegularExpression(
        pattern: #"<script(?=\s)[^<>]*?\sid\s*=\s*["']__UNIVERSAL_DATA_FOR_REHYDRATION__["'][^<>]*>"#,
        options: .caseInsensitive
    )
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func enrich(_ link: TikTokLink) async -> TikTokEnrichment {
        #if DEBUG
        if SharedInbox.usesUITestFixtures() {
            return TikTokEnrichment(resolvedLink: link.videoID == nil ? nil : link, metadata: nil)
        }
        #endif
        let resolution: LinkResolution
        if link.videoID != nil {
            resolution = LinkResolution(link: link, outcome: .success)
        } else {
            resolution = await resolveShortLink(link)
        }

        // TikTok may still return oEmbed data for a short URL when HEAD is
        // unavailable. Only a numeric canonical URL is eligible for playback.
        let fetched = await fetchMetadata(for: resolution.link ?? link)
        // Both operations supply independent details. A transient failure in either
        // must remain retryable even if the other succeeds or rejects the short URL.
        let outcomes = [resolution.outcome, fetched.outcome]
        let outcome: TikTokEnrichment.Outcome = outcomes.contains(.retryableFailure) ? .retryableFailure :
            outcomes.contains(.permanentFailure) ? .permanentFailure : .success
        return TikTokEnrichment(resolvedLink: resolution.link, metadata: fetched.metadata,
                                outcome: outcome,
                                retryAfter: [resolution.retryAfter, fetched.retryAfter].compactMap { $0 }.max())
    }

    private struct LinkResolution {
        let link: TikTokLink?
        let outcome: TikTokEnrichment.Outcome
        var retryAfter: Date? = nil
    }

    private func resolveShortLink(_ link: TikTokLink) async -> LinkResolution {
        var current = link
        // The delegate stops URLSession before it follows each response's Location.
        // Inspecting every hop keeps a TikTok short link from sending a request elsewhere.
        for _ in 0..<5 {
            var request = URLRequest(url: current.url)
            request.httpMethod = "HEAD"
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 10

            guard let (_, response) = try? await session.data(for: request,
                                                               delegate: NoAutomaticRedirects()),
                  let response = response as? HTTPURLResponse else {
                return LinkResolution(link: nil, outcome: .retryableFailure)
            }

            if (300..<400).contains(response.statusCode) {
                guard let location = response.value(forHTTPHeaderField: "Location"),
                      let nextURL = URL(string: location, relativeTo: current.url)?.absoluteURL,
                      let next = TikTokLink(text: nextURL.absoluteString) else {
                    return LinkResolution(link: nil, outcome: .permanentFailure)
                }
                if next.videoID != nil { return LinkResolution(link: next, outcome: .success) }
                current = next
                continue
            }

            let retryable = response.statusCode == 429 || response.statusCode >= 500
            return LinkResolution(link: nil,
                                  outcome: retryable ? .retryableFailure : .permanentFailure,
                                  retryAfter: retryable ? Self.retryAfter(response) : nil)
        }
        return LinkResolution(link: nil, outcome: .permanentFailure)
    }

    private func fetchMetadata(for link: TikTokLink) async -> TikTokEnrichment {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.tiktok.com"
        components.path = "/oembed"
        components.queryItems = [URLQueryItem(name: "url", value: link.url.absoluteString)]
        guard let url = components.url else {
            return TikTokEnrichment(resolvedLink: nil, metadata: nil, outcome: .permanentFailure)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        guard let (data, response) = try? await session.data(for: request,
                                                               delegate: NoAutomaticRedirects()),
              let response = response as? HTTPURLResponse else {
            return TikTokEnrichment(resolvedLink: nil, metadata: nil, outcome: .retryableFailure)
        }
        guard response.statusCode == 200 else {
            let retryable = response.statusCode == 429 || response.statusCode >= 500
            return TikTokEnrichment(resolvedLink: nil, metadata: nil,
                                    outcome: retryable ? .retryableFailure : .permanentFailure,
                                    retryAfter: retryable ? Self.retryAfter(response) : nil)
        }
        guard let payload = try? JSONDecoder().decode(OEmbedResponse.self, from: data) else {
            return TikTokEnrichment(resolvedLink: nil, metadata: nil, outcome: .retryableFailure)
        }

        let thumbnailURL = payload.thumbnailURL.flatMap(Self.trustedThumbnailURL)
        let fallback = thumbnailURL == nil ? await fetchPublicVideoMetadata(for: link) : nil
        let metadata = TikTokMetadata(title: payload.title?.nonempty ?? fallback?.metadata?.title,
                                      creator: payload.authorName?.nonempty ?? fallback?.metadata?.creator,
                                      thumbnailURL: thumbnailURL ?? fallback?.metadata?.thumbnailURL)
        return TikTokEnrichment(resolvedLink: nil, metadata: metadata,
                                outcome: fallback?.outcome ?? .success, retryAfter: fallback?.retryAfter)
    }

    // A valid oEmbed response may contain just the player iframe. Recover its
    // poster from the original public post when the canonical video is known.
    private func fetchPublicVideoMetadata(for link: TikTokLink) async -> TikTokEnrichment? {
        guard let videoID = link.videoID, let url = Self.publicPageURL(for: link, videoID: videoID) else {
            return nil
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpShouldHandleCookies = false
        request.timeoutInterval = 10
        request.setValue("text/html", forHTTPHeaderField: "Accept")

        do {
            let (bytes, response) = try await session.bytes(for: request, delegate: NoAutomaticRedirects())
            defer { bytes.task.cancel() }
            guard let response = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            if response.statusCode == 429 || response.statusCode >= 500 {
                return TikTokEnrichment(resolvedLink: nil, metadata: nil,
                                        outcome: .retryableFailure, retryAfter: Self.retryAfter(response))
            }
            guard response.statusCode == 200,
                  response.expectedContentLength <= Self.maximumPublicPageBytes else { return nil }
            var data = Data()
            for try await byte in bytes {
                guard data.count < Self.maximumPublicPageBytes else { return nil }
                data.append(byte)
            }
            return TikTokEnrichment(resolvedLink: nil, metadata: Self.metadata(inPublicPage: data, videoID: videoID))
        } catch {
            // Keep oEmbed details while letting the queue retry the poster.
            return TikTokEnrichment(resolvedLink: nil, metadata: nil, outcome: .retryableFailure)
        }
    }

    private static func publicPageURL(for link: TikTokLink, videoID: String) -> URL? {
        guard !videoID.isEmpty, videoID.utf8.allSatisfy({ (48...57).contains($0) }),
              var components = URLComponents(url: link.url, resolvingAgainstBaseURL: false),
              components.scheme == "https",
              let host = components.host?.lowercased(),
              ["tiktok.com", "www.tiktok.com", "m.tiktok.com"].contains(host),
              components.user == nil, components.password == nil, components.port == nil else { return nil }

        let path = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        let videoPath = "/video/\(videoID)"
        if path != videoPath {
            guard let handle = path.split(separator: "/").first,
                  handle.first == "@", handle.count > 1,
                  handle.dropFirst().allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" }),
                  path == "/\(handle)\(videoPath)" else { return nil }
        }

        components.host = "www.tiktok.com"
        components.path = path
        components.query = nil
        components.fragment = nil
        return components.url
    }

    private static func metadata(inPublicPage data: Data, videoID: String) -> TikTokMetadata? {
        guard let html = String(data: data, encoding: .utf8),
              let match = publicPagePayload.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let script = Range(match.range, in: html),
              let end = html.range(of: "</script>", options: .caseInsensitive, range: script.upperBound..<html.endIndex),
              let payload = try? JSONDecoder().decode(
                  PublicVideoPage.self, from: Data(html[script.upperBound..<end.lowerBound].utf8)
              ),
              let item = payload.scope.detail?.itemInfo?.itemStruct,
              item.id == videoID else { return nil }

        let coverURL = item.video?.cover.flatMap(trustedThumbnailURL) ??
            item.video?.originCover.flatMap(trustedThumbnailURL)
        return TikTokMetadata(title: item.desc?.nonempty,
                              creator: item.author?.nickname?.nonempty ?? item.author?.uniqueId?.nonempty,
                              thumbnailURL: coverURL)
    }

    private static func trustedThumbnailURL(_ value: String) -> URL? {
        guard let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              components.user == nil, components.password == nil, components.port == nil,
              let host = components.host?.lowercased(),
              ["tiktokcdn.com", "tiktokcdn-us.com"].contains(where: { host == $0 || host.hasSuffix(".\($0)") }),
              let url = components.url, !TikTokMetadata.thumbnailIsExpired(url, at: .now)
        else { return nil }
        return url
    }

    private static func retryAfter(_ response: HTTPURLResponse) -> Date? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        let now = Date()
        if let seconds = TimeInterval(value), seconds.isFinite, seconds >= 0 {
            return now.addingTimeInterval(min(seconds, 86_400))
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in ["EEE, dd MMM yyyy HH:mm:ss zzz", "EEEE, dd-MMM-yy HH:mm:ss zzz", "EEE MMM d HH:mm:ss yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return min(date, now.addingTimeInterval(86_400))
            }
        }
        return nil
    }
}

private struct OEmbedResponse: Decodable {
    let title: String?
    let authorName: String?
    let thumbnailURL: String?

    enum CodingKeys: String, CodingKey {
        case title
        case authorName = "author_name"
        case thumbnailURL = "thumbnail_url"
    }
}

private struct PublicVideoPage: Decodable {
    let scope: Scope

    enum CodingKeys: String, CodingKey {
        case scope = "__DEFAULT_SCOPE__"
    }

    struct Scope: Decodable {
        let detail: VideoDetail?

        enum CodingKeys: String, CodingKey {
            case detail = "webapp.video-detail"
        }
    }

    struct VideoDetail: Decodable {
        let itemInfo: ItemInfo?
    }

    struct ItemInfo: Decodable {
        let itemStruct: Item?
    }

    struct Item: Decodable {
        let id: String
        let desc: String?
        let author: Author?
        let video: Video?

        struct Author: Decodable {
            let nickname: String?
            let uniqueId: String?
        }

        struct Video: Decodable {
            let cover: String?
            let originCover: String?
        }
    }
}

private extension String {
    var nonempty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private final class NoAutomaticRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
