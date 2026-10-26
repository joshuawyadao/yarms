import XCTest
@testable import Yarms

final class WorkoutEnrichmentQueueTests: XCTestCase {
    func testLargeRestoreKeepsAtMostThreeRequestsActiveAndDoesNotRetryImmediately() throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        let workouts = (0..<2_500).map { _ in
            Workout(id: UUID(), sourceLink: link, savedAt: Date())
        }
        var queue = WorkoutEnrichmentQueue()
        queue.reset(with: workouts)

        var scheduled = queue.takeAvailable()
        XCTAssertEqual(scheduled.count, WorkoutEnrichmentQueue.maximumConcurrent)
        XCTAssertTrue(queue.hasActiveRequests)
        XCTAssertTrue(queue.takeAvailable().isEmpty)

        var finished = 0
        while finished < scheduled.count {
            queue.finish(scheduled[finished].id)
            finished += 1
            let next = queue.takeAvailable()
            XCTAssertLessThanOrEqual(next.count, 1)
            scheduled.append(contentsOf: next)
        }
        XCTAssertEqual(scheduled.count, workouts.count)
        XCTAssertFalse(queue.hasActiveRequests)
        // After the queued snapshot drains, a failed request is not retried in a loop.
        XCTAssertTrue(queue.takeAvailable().isEmpty)
    }

    func testRefreshSelectsOnlyIncompleteWorkouts() throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        var complete = Workout(id: UUID(), sourceLink: link, savedAt: Date())
        complete.title = "Workout"
        complete.thumbnailURL = URL(string: "https://www.tiktok.com/thumbnail.jpg")
        var missingThumbnail = Workout(id: UUID(), sourceLink: link, savedAt: Date())
        missingThumbnail.title = "Workout"

        var queue = WorkoutEnrichmentQueue()
        queue.reset(with: [complete, missingThumbnail])
        XCTAssertEqual(queue.takeAvailable().map(\.id), [missingThumbnail.id])
    }

    func testRetrySchedulingAndTerminalStates() throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        let now = Date(timeIntervalSince1970: 100_000)
        var workout = Workout(id: UUID(), sourceLink: link, savedAt: now)
        let failure = TikTokEnrichment(resolvedLink: link, metadata: nil, outcome: .retryableFailure)
        workout.enrichmentState = WorkoutEnrichmentState.after(result: failure, previous: nil, now: now)
        XCTAssertEqual(workout.enrichmentState?.attemptCount, 1)
        var queue = WorkoutEnrichmentQueue()
        queue.reset(with: [workout], now: now)
        XCTAssertTrue(queue.takeAvailable().isEmpty)
        queue.reset(with: [workout], now: now.addingTimeInterval(60))
        XCTAssertEqual(queue.takeAvailable().map(\.id), [workout.id])
        queue.finish(workout.id)

        for attempt in 2...5 {
            workout.enrichmentState = WorkoutEnrichmentState.after(result: failure,
                previous: workout.enrichmentState, now: now)
            XCTAssertEqual(workout.enrichmentState?.attemptCount, attempt)
        }
        XCTAssertEqual(workout.enrichmentState?.status, .permanentFailure)
        queue.reset(with: [workout], now: .distantFuture)
        XCTAssertTrue(queue.takeAvailable().isEmpty)
    }

    func testPartialAndPermanentOutcomesAreQuietUntilCleared() throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        var workout = Workout(id: UUID(), sourceLink: link, savedAt: Date())
        workout.enrichmentState = WorkoutEnrichmentState.after(
            result: TikTokEnrichment(resolvedLink: link, metadata: nil), previous: nil, now: Date())
        XCTAssertEqual(workout.enrichmentState?.status, .partial)
        var queue = WorkoutEnrichmentQueue()
        queue.reset(with: [workout])
        XCTAssertTrue(queue.takeAvailable().isEmpty)
        workout.enrichmentState = nil
        queue.reset(with: [workout])
        XCTAssertEqual(queue.takeAvailable().count, 1)
    }

    func testLegacyWorkoutDecodesWithoutEnrichmentState() throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        let workout = Workout(id: UUID(), sourceLink: link, savedAt: Date())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(workout)) as? [String: Any])
        object.removeValue(forKey: "enrichmentState")
        let decoded = try JSONDecoder().decode(Workout.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.enrichmentState)
        XCTAssertEqual(decoded.id, workout.id)
    }

    func testSuccessRequiresCanonicalLinkTitleAndThumbnailToBeComplete() throws {
        let canonical = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        let short = try XCTUnwrap(TikTokLink(text: "https://vm.tiktok.com/ZMshort/"))
        let metadata = TikTokMetadata(title: "Strength", creator: nil,
                                      thumbnailURL: URL(string: "https://example.com/cover.jpg"))
        let now = Date(timeIntervalSince1970: 1_000)
        let complete = WorkoutEnrichmentState.after(result: TikTokEnrichment(
            resolvedLink: canonical, metadata: metadata), previous: nil, now: now)
        XCTAssertEqual(complete.status, .complete)
        let missingThumbnail = WorkoutEnrichmentState.after(result: TikTokEnrichment(
            resolvedLink: canonical, metadata: TikTokMetadata(title: "Strength", creator: nil,
                                                               thumbnailURL: nil)), previous: nil, now: now)
        XCTAssertEqual(missingThumbnail.status, .partial)
        let unresolved = WorkoutEnrichmentState.after(result: TikTokEnrichment(
            resolvedLink: short, metadata: metadata), previous: nil, now: now)
        XCTAssertEqual(unresolved.status, .partial)
    }

    func testNextRetryDateSkipsFullyPopulatedPendingWorkout() throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        let now = Date(timeIntervalSinceReferenceDate: 10_000)
        let early = now.addingTimeInterval(60)
        let later = now.addingTimeInterval(300)
        var complete = Workout(id: UUID(), sourceLink: link, savedAt: now)
        complete.title = "Workout"
        complete.thumbnailURL = URL(string: "https://www.tiktok.com/thumbnail.jpg")
        complete.enrichmentState = WorkoutEnrichmentState(status: .pending,
                                                          attemptCount: 1, nextAttemptAt: early)
        var incomplete = Workout(id: UUID(), sourceLink: link, savedAt: now)
        incomplete.enrichmentState = WorkoutEnrichmentState(status: .pending,
                                                            attemptCount: 1, nextAttemptAt: later)

        XCTAssertEqual(WorkoutEnrichmentQueue.nextRetryDate(in: [complete, incomplete], isActive: true), later)
        var queue = WorkoutEnrichmentQueue()
        queue.reset(with: [complete, incomplete], now: early)
        XCTAssertTrue(queue.takeAvailable().isEmpty)
        queue.reset(with: [complete, incomplete], now: later)
        XCTAssertEqual(queue.takeAvailable().map(\.id), [incomplete.id])
    }

    func testNextRetryDateIgnoresTerminalAndNonfiniteDeadlines() throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        let now = Date(timeIntervalSinceReferenceDate: 20_000)
        var terminal = Workout(id: UUID(), sourceLink: link, savedAt: now)
        terminal.enrichmentState = WorkoutEnrichmentState(status: .permanentFailure,
                                                          attemptCount: 5, nextAttemptAt: now)
        var infinite = Workout(id: UUID(), sourceLink: link, savedAt: now)
        infinite.enrichmentState = WorkoutEnrichmentState(
            status: .pending, attemptCount: 1,
            nextAttemptAt: Date(timeIntervalSinceReferenceDate: .infinity))
        let legacy = Workout(id: UUID(), sourceLink: link, savedAt: now)

        XCTAssertNil(WorkoutEnrichmentQueue.nextRetryDate(in: [terminal, infinite, legacy], isActive: true))
        var queue = WorkoutEnrichmentQueue()
        queue.reset(with: [terminal, infinite, legacy], now: now)
        XCTAssertEqual(queue.takeAvailable().map(\.id), [legacy.id])
    }

    func testRetryTimerCancelsWhileInactiveAndRearmsAfterFailure() throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        let now = Date(timeIntervalSinceReferenceDate: 30_000)
        var workout = Workout(id: UUID(), sourceLink: link, savedAt: now)
        let retryable = TikTokEnrichment(resolvedLink: link, metadata: nil,
                                         outcome: .retryableFailure)
        workout.enrichmentState = WorkoutEnrichmentState.after(result: retryable,
                                                               previous: nil, now: now)
        let firstDeadline = try XCTUnwrap(workout.enrichmentState?.nextAttemptAt)
        XCTAssertEqual(WorkoutEnrichmentQueue.nextRetryDate(in: [workout], isActive: true), firstDeadline)
        XCTAssertNil(WorkoutEnrichmentQueue.nextRetryDate(in: [workout], isActive: false))

        // The in-flight request finishes after the scene becomes inactive.
        workout.enrichmentState = WorkoutEnrichmentState.after(result: retryable,
            previous: workout.enrichmentState, now: now.addingTimeInterval(30))
        let persistedDeadline = try XCTUnwrap(workout.enrichmentState?.nextAttemptAt)
        XCTAssertNil(WorkoutEnrichmentQueue.nextRetryDate(in: [workout], isActive: false))
        XCTAssertEqual(WorkoutEnrichmentQueue.nextRetryDate(in: [workout], isActive: true),
                       persistedDeadline)

        var queue = WorkoutEnrichmentQueue()
        queue.reset(with: [workout], now: persistedDeadline.addingTimeInterval(-1))
        XCTAssertTrue(queue.takeAvailable().isEmpty)
        queue.reset(with: [workout], now: persistedDeadline)
        XCTAssertEqual(queue.takeAvailable().map(\.id), [workout.id])
    }
}
