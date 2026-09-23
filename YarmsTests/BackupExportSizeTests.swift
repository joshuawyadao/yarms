import XCTest
@testable import Yarms

final class BackupExportSizeTests: XCTestCase {
    func testLocallyValidLargeLibraryCanStillBeExported() throws {
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        var workout = Workout(id: UUID(), sourceLink: link, savedAt: Date())
        workout.notes = String(repeating: "n", count: WorkoutBackup.maximumBytes)

        let exported = try WorkoutBackup(workouts: [workout]).encode()

        XCTAssertGreaterThan(exported.count, WorkoutBackup.maximumBytes)
    }
}
