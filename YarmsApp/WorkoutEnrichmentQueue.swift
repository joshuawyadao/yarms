import Foundation

// A restore may add thousands of records. Keep only a few metadata requests in
// flight, and advance through a snapshot instead of starting one task per row.
struct WorkoutEnrichmentQueue {
    static let maximumConcurrent = 3
    var hasActiveRequests: Bool { !active.isEmpty }

    private var pending: [Workout] = []
    private var nextIndex = 0
    private var active = Set<UUID>()

    // The timer and queue must agree on which records still need details.
    private static func needsDetails(_ workout: Workout, now: Date) -> Bool {
        workout.title == nil || workout.playbackLink.videoID == nil ||
            workout.thumbnailURL == nil || workout.thumbnailIsExpired(at: now)
    }

    private static func mayEnrich(_ workout: Workout, now: Date) -> Bool {
        switch workout.enrichmentState?.status {
        case nil, .pending: return true
        case .complete:
            return workout.thumbnailIsExpired(at: now) ||
                (workout.thumbnailURL == nil && workout.enrichmentState?.checkedPublicPoster == nil)
        case .partial:
            return workout.thumbnailIsExpired(at: now) ||
                (workout.thumbnailURL == nil && workout.playbackLink.videoID != nil &&
                 workout.enrichmentState?.checkedPublicPoster == nil)
        case .permanentFailure: return false
        }
    }

    static func nextRetryDate(in workouts: [Workout], isActive: Bool) -> Date? {
        guard isActive else { return nil }
        let now = Date()
        return workouts.compactMap { workout in
            guard needsDetails(workout, now: now), mayEnrich(workout, now: now),
                  let date = workout.enrichmentState?.nextAttemptAt,
                  date.timeIntervalSinceReferenceDate.isFinite else { return nil }
            return date
        }.min()
    }

    mutating func reset(with workouts: [Workout], now: Date = Date()) {
        pending = workouts.filter { workout in
            !active.contains(workout.id) && Self.needsDetails(workout, now: now) &&
                Self.mayEnrich(workout, now: now) &&
                (workout.enrichmentState?.nextAttemptAt ?? .distantPast) <= now
        }
        nextIndex = 0
    }

    mutating func takeAvailable() -> [Workout] {
        var selected: [Workout] = []
        while active.count < Self.maximumConcurrent && nextIndex < pending.count {
            let workout = pending[nextIndex]
            nextIndex += 1
            guard active.insert(workout.id).inserted else { continue }
            selected.append(workout)
        }
        return selected
    }

    mutating func finish(_ id: UUID) {
        active.remove(id)
    }
}
