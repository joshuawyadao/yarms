import Foundation

struct Workout: Codable, Identifiable, Equatable {
    let id: UUID
    let sourceLink: TikTokLink
    let savedAt: Date
    var resolvedLink: TikTokLink? = nil
    var title: String? = nil
    var creator: String? = nil
    var thumbnailURL: URL? = nil

    var playbackLink: TikTokLink { resolvedLink ?? sourceLink }

    func matches(_ query: String) -> Bool {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return true }
        return [title, creator, sourceLink.url.absoluteString, resolvedLink?.url.absoluteString]
            .compactMap { $0 }
            .contains { $0.localizedStandardContains(term) }
    }
}
