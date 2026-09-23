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
}
