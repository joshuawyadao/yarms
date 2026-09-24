import Foundation

struct Workout: Codable, Identifiable, Equatable {
    let id: UUID
    let sourceLink: TikTokLink
    let savedAt: Date
    var resolvedLink: TikTokLink? = nil
    var title: String? = nil
    var creator: String? = nil
    var thumbnailURL: URL? = nil
    var notes: String? = nil
    var folderID: UUID? = nil
    // Other source URLs locally confirmed to identify this same video.
    // Optional so libraries written before backup support still decode.
    var sourceAliases: [TikTokLink]? = nil

    var playbackLink: TikTokLink { resolvedLink ?? sourceLink }

    func matches(_ query: String) -> Bool {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return true }
        let searchable = [title, creator, sourceLink.url.absoluteString, resolvedLink?.url.absoluteString]
            .compactMap { $0 } + (sourceAliases?.map { $0.url.absoluteString } ?? [])
        return searchable.contains { $0.localizedStandardContains(term) }
    }
}

struct WorkoutFolder: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
}
