import XCTest
@testable import Yarms

final class BackupImportSecurityTests: XCTestCase {
    func testImportDropsUntrustedThumbnailResolutionAndAliases() throws {
        let short = try XCTUnwrap(TikTokLink(text: "https://vt.tiktok.com/ZMshort/"))
        let canonical = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        let secondShort = try XCTUnwrap(TikTokLink(text: "https://vm.tiktok.com/ZMsecond/"))
        var workout = Workout(id: UUID(), sourceLink: short, savedAt: Date())
        workout.resolvedLink = canonical
        workout.title = "Workout"
        workout.thumbnailURL = URL(string: "https://tracker.example/opened-backup")
        workout.sourceAliases = [secondShort]

        let exported = try WorkoutBackup(workouts: [workout]).encode()
        let imported = try XCTUnwrap(WorkoutBackup.decode(exported).workouts.first)

        XCTAssertEqual(imported.sourceLink, short)
        XCTAssertEqual(imported.title, "Workout")
        XCTAssertNil(imported.resolvedLink)
        XCTAssertNil(imported.thumbnailURL)
        XCTAssertNil(imported.sourceAliases)
    }

    func testTrustedBackupRejectsAliasForAnotherCanonicalVideo() throws {
        let canonical = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        let unrelated = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@other/video/456"))
        var workout = Workout(id: UUID(), sourceLink: canonical, savedAt: Date())
        workout.sourceAliases = [unrelated]

        XCTAssertThrowsError(try WorkoutBackup(workouts: [workout])) { error in
            XCTAssertEqual(error as? WorkoutBackup.BackupError, .invalidArchive)
        }
    }
}
