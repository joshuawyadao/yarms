import Foundation

struct TikTokMetadata: Equatable {
    let title: String?
    let creator: String?
    let thumbnailURL: URL?
}

struct TikTokEnrichment {
    enum Outcome: Equatable { case success, retryableFailure, permanentFailure }
    let resolvedLink: TikTokLink?
    let metadata: TikTokMetadata?
    var outcome: Outcome = .success
    var retryAfter: Date? = nil
}

struct TikTokMetadataClient {
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

        let thumbnailURL = payload.thumbnailURL.flatMap(URL.init(string:))
        let metadata = TikTokMetadata(title: payload.title?.nonempty,
                              creator: payload.authorName?.nonempty,
                              thumbnailURL: thumbnailURL?.scheme?.lowercased() == "https" ? thumbnailURL : nil)
        return TikTokEnrichment(resolvedLink: nil, metadata: metadata)
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
