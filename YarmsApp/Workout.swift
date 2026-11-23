import Foundation

struct Workout: Codable, Identifiable, Equatable {
    let id: UUID
    let sourceLink: TikTokLink
    let savedAt: Date
    var resolvedLink: TikTokLink? = nil
    var title: String? = nil
    var customTitle: String? = nil
    var creator: String? = nil
    var thumbnailURL: URL? = nil
    var notes: String? = nil
    var folderID: UUID? = nil
    // Other source URLs locally confirmed to identify this same video.
    // Optional so libraries written before backup support still decode.
    var sourceAliases: [TikTokLink]? = nil
    var enrichmentState: WorkoutEnrichmentState? = nil

    var displayTitle: String { customTitle ?? title ?? "TikTok workout" }

    var playbackLink: TikTokLink { resolvedLink ?? sourceLink }

    func thumbnailIsExpired(at date: Date) -> Bool {
        guard let thumbnailURL,
              let fields = URLComponents(url: thumbnailURL, resolvingAgainstBaseURL: false)?.queryItems,
              let value = fields.first(where: { $0.name == "x-expires" })?.value,
              let expires = TimeInterval(value), expires.isFinite else { return false }
        return expires <= date.timeIntervalSince1970
    }

    func matches(_ query: String) -> Bool {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return true }
        let searchable = [customTitle, title, creator, sourceLink.url.absoluteString, resolvedLink?.url.absoluteString]
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
    // Older terminal partial results were recorded before the public poster lookup.
    var checkedPublicPoster: Bool? = nil

    static func after(result: TikTokEnrichment, previous: Self?, now: Date) -> Self {
        let attempts = min((previous?.attemptCount ?? 0) + 1, maximumAttempts)
        switch result.outcome {
        case .success:
            let complete = result.resolvedLink?.videoID != nil &&
                result.metadata?.title != nil && result.metadata?.thumbnailURL != nil
            return Self(status: complete ? .complete : .partial,
                        attemptCount: attempts, nextAttemptAt: nil, checkedPublicPoster: true)
        case .permanentFailure:
            return Self(status: .permanentFailure, attemptCount: attempts, nextAttemptAt: nil, checkedPublicPoster: true)
        case .retryableFailure:
            guard attempts < maximumAttempts else {
                return Self(status: .permanentFailure, attemptCount: attempts, nextAttemptAt: nil, checkedPublicPoster: true)
            }
            // 1, 2, 4, 8 minutes. A server-specified delay can extend this.
            let backoff = now.addingTimeInterval(TimeInterval(60 * (1 << (attempts - 1))))
            return Self(status: .pending, attemptCount: attempts,
                        nextAttemptAt: max(backoff, result.retryAfter ?? backoff), checkedPublicPoster: true)
        }
    }
}

struct WorkoutCompletion: Codable, Identifiable, Equatable {
    let id: UUID
    let workoutID: UUID
    let title: String
    let completedAt: Date
    let timeZoneIdentifier: String

    func day(in calendar: Calendar) -> Date {
        var loggingCalendar = calendar
        loggingCalendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? calendar.timeZone
        let dateParts: Set<Calendar.Component> = [.era, .year, .month, .day]
        let components = loggingCalendar.dateComponents(dateParts, from: completedAt)
        return calendar.startOfDay(for: calendar.date(from: components) ?? completedAt)
    }
}

struct WorkoutFolder: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
}
