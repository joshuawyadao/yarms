import Foundation

struct TikTokLink: Codable, Hashable, Identifiable {
    let url: URL
    let videoID: String?

    var id: String { url.absoluteString }

    init?(text: String) {
        guard let expression = try? NSRegularExpression(pattern: #"https?://[^\s<>]+"#,
                                                        options: .caseInsensitive) else { return nil }
        let wholeText = NSRange(text.startIndex..., in: text)
        for match in expression.matches(in: text, range: wholeText) {
            guard let range = Range(match.range, in: text) else { continue }
            let candidate = String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: ".,);]\"'"))
            if let link = Self(urlString: candidate) {
                self = link
                return
            }
        }
        return nil
    }

    private init?(urlString: String) {
        guard var components = URLComponents(string: urlString),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              ["tiktok.com", "www.tiktok.com", "m.tiktok.com", "vm.tiktok.com", "vt.tiktok.com"].contains(host),
              components.user == nil,
              components.password == nil,
              components.port == nil else { return nil }

        let parts = components.path.split(separator: "/").map(String.init)
        let parsedID: String?
        if parts.count >= 3, parts[0].hasPrefix("@"), parts[1] == "video",
           !parts[2].isEmpty, parts[2].allSatisfy(\.isNumber) {
            parsedID = parts[2]
        } else if parts.count >= 2, parts[0] == "video",
                  !parts[1].isEmpty, parts[1].allSatisfy(\.isNumber) {
            parsedID = parts[1]
        } else if (["vm.tiktok.com", "vt.tiktok.com"].contains(host) && !parts.isEmpty) ||
                  (parts.count >= 2 && parts[0] == "t") {
            parsedID = nil
        } else {
            return nil
        }

        components.scheme = "https"
        components.host = host
        components.query = nil
        components.fragment = nil
        guard let cleanURL = components.url else { return nil }
        self.url = cleanURL
        self.videoID = parsedID
    }

    var playerURL: URL? {
        guard let videoID else { return nil }
        return URL(string: "https://www.tiktok.com/player/v1/\(videoID)?controls=1")
    }
}
