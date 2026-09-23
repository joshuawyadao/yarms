import XCTest
@testable import Yarms

final class BackupScalingBenchmarkTests: XCTestCase {
    func testManyAliasRestoreScalesWhenOptedIn() throws {
        guard ProcessInfo.processInfo.environment["YARMS_RUN_BACKUP_BENCHMARK"] == "1" else {
            throw XCTSkip("Set YARMS_RUN_BACKUP_BENCHMARK=1 to run the restore scaling benchmark")
        }

        // This is the same many-URLs/one-video shape as the alias regression test.
        // Build archives before timing so only restore work contributes to the ratio.
        let small = try makeBackup(aliasCount: 1_000)
        let large = try makeBackup(aliasCount: 4_000)
        var smallSamples: [Double] = []
        var largeSamples: [Double] = []

        _ = try elapsedRestore(small) // Warm up the test process and file system.
        for _ in 0..<5 {
            smallSamples.append(try elapsedRestore(small))
            largeSamples.append(try elapsedRestore(large))
        }

        let smallMedian = median(smallSamples)
        let largeMedian = median(largeSamples)
        let ratio = largeMedian / smallMedian
        print("Restore scaling (1,000 → 4,000 aliases): \(smallMedian)s → \(largeMedian)s, \(ratio)x")

        // Four times as many aliases should stay well below quadratic growth (16x).
        // A median and generous limit reduce sensitivity to simulator noise.
        XCTAssertLessThan(ratio, 10, "Restore scaling regressed beyond the 10x limit")
    }

    private func makeBackup(aliasCount: Int) throws -> WorkoutBackup {
        let entries = try (0..<aliasCount).map { number in
            let link = try XCTUnwrap(TikTokLink(
                text: "https://www.tiktok.com/@coach\(number)/video/123"
            ))
            return Workout(id: UUID(), sourceLink: link,
                           savedAt: Date(timeIntervalSince1970: Double(number)))
        }
        return try WorkoutBackup(workouts: entries)
    }

    private func elapsedRestore(_ backup: WorkoutBackup) throws -> Double {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WorkoutStore(
            fileURL: directory.appendingPathComponent("Library.json"),
            inbox: SharedInbox(directory: directory.appendingPathComponent("Inbox"))
        )

        let start = DispatchTime.now().uptimeNanoseconds
        let result = try store.restoreBackup(backup)
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        XCTAssertEqual(result, BackupRestoreResult(added: 1, updated: 0))
        return Double(elapsed) / 1_000_000_000
    }

    private func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}
