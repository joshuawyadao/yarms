import Foundation

struct TikTokMetadata: Equatable {
    let title: String?
    let creator: String?
    let thumbnailURL: URL?
}

struct TikTokEnrichment {
    let resolvedLink: TikTokLink?
    let metadata: TikTokMetadata?
}

struct TikTokMetadataClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func enrich(_ link: TikTokLink) async -> TikTokEnrichment {
        let resolvedLink: TikTokLink?
        if link.videoID != nil {
            resolvedLink = link
        } else {
            resolvedLink = await resolveShortLink(link)
        }

        // TikTok may still return oEmbed data for a short URL when HEAD is
        // unavailable. Only a numeric canonical URL is eligible for playback.
        let metadata = await fetchMetadata(for: resolvedLink ?? link)
        return TikTokEnrichment(resolvedLink: resolvedLink, metadata: metadata)
    }

    private func resolveShortLink(_ link: TikTokLink) async -> TikTokLink? {
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
                  let response = response as? HTTPURLResponse else { return nil }

            if (300..<400).contains(response.statusCode) {
                guard let location = response.value(forHTTPHeaderField: "Location"),
                      let nextURL = URL(string: location, relativeTo: current.url)?.absoluteURL,
                      let next = TikTokLink(text: nextURL.absoluteString) else { return nil }
                current = next
                continue
            }

            guard (200..<300).contains(response.statusCode),
                  current.videoID != nil else { return nil }
            return current
        }
        return nil
    }

    private func fetchMetadata(for link: TikTokLink) async -> TikTokMetadata? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.tiktok.com"
        components.path = "/oembed"
        components.queryItems = [URLQueryItem(name: "url", value: link.url.absoluteString)]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        guard let (data, response) = try? await session.data(for: request),
              let response = response as? HTTPURLResponse,
              response.statusCode == 200,
              let payload = try? JSONDecoder().decode(OEmbedResponse.self, from: data) else {
            return nil
        }

        let thumbnailURL = payload.thumbnailURL.flatMap(URL.init(string:))
        return TikTokMetadata(title: payload.title?.nonempty,
                              creator: payload.authorName?.nonempty,
                              thumbnailURL: thumbnailURL?.scheme?.lowercased() == "https" ? thumbnailURL : nil)
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
