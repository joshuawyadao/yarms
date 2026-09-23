import Foundation

// A restore may add thousands of records. Keep only a few metadata requests in
// flight, and advance through a snapshot instead of starting one task per row.
struct WorkoutEnrichmentQueue {
    static let maximumConcurrent = 3

    private var pending: [Workout] = []
    private var nextIndex = 0
    private var active = Set<UUID>()

    mutating func reset(with workouts: [Workout]) {
        pending = workouts.filter { workout in
            !active.contains(workout.id) &&
                (workout.title == nil || workout.playbackLink.videoID == nil ||
                 workout.thumbnailURL == nil)
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
