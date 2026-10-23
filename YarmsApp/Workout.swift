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
    var enrichmentState: WorkoutEnrichmentState? = nil

    var playbackLink: TikTokLink { resolvedLink ?? sourceLink }

    func matches(_ query: String) -> Bool {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return true }
        let searchable = [title, creator, sourceLink.url.absoluteString, resolvedLink?.url.absoluteString]
            .compactMap { $0 } + (sourceAliases?.map { $0.url.absoluteString } ?? [])
        return searchable.contains { $0.localizedStandardContains(term) }
    }
}

struct WorkoutEnrichmentState: Codable, Equatable {
    enum Status: String, Codable { case pending, partial, complete, permanentFailure }
    static let maximumAttempts = 5

    var status: Status
    var attemptCount: Int
    var nextAttemptAt: Date?

    static func after(result: TikTokEnrichment, previous: Self?, now: Date) -> Self {
        let attempts = min((previous?.attemptCount ?? 0) + 1, maximumAttempts)
        switch result.outcome {
        case .success:
            let complete = result.resolvedLink?.videoID != nil &&
                result.metadata?.title != nil && result.metadata?.thumbnailURL != nil
            return Self(status: complete ? .complete : .partial,
                        attemptCount: attempts, nextAttemptAt: nil)
        case .permanentFailure:
            return Self(status: .permanentFailure, attemptCount: attempts, nextAttemptAt: nil)
        case .retryableFailure:
            guard attempts < maximumAttempts else {
                return Self(status: .permanentFailure, attemptCount: attempts, nextAttemptAt: nil)
            }
            // 1, 2, 4, 8 minutes. A server-specified delay can extend this.
            let backoff = now.addingTimeInterval(TimeInterval(60 * (1 << (attempts - 1))))
            return Self(status: .pending, attemptCount: attempts,
                        nextAttemptAt: max(backoff, result.retryAfter ?? backoff))
        }
    }
}

struct WorkoutFolder: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
}
