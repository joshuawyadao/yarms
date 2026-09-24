import UIKit
import XCTest

final class YarmsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPasteSearchPlayerLayoutAndNotesPersistence() throws {
        let app = isolatedApp()
        let videoID = pasteUniqueWorkout(into: app)
        let row = app.descendants(matching: .any).matching(identifier: "workout-\(videoID)").firstMatch
        if !row.waitForExistence(timeout: 10) {
            XCTFail("The pasted link should appear in the library. \(app.debugDescription)")
            return
        }

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.exists, "Search should appear after a workout is saved")
        search.tap()
        search.typeText(videoID)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The saved link should be searchable")
        row.tap()

        let back = app.buttons["Back 10 seconds"]
        let fallback = app.buttons["openInTikTokButton"]
        XCTAssertTrue(back.waitForExistence(timeout: 10), "The workout should show playback controls")
        XCTAssertTrue(fallback.exists, "The workout should offer Open in TikTok")
        XCTAssertTrue(fallback.isHittable, "Open in TikTok should remain visible at the bottom")
        XCTAssertLessThanOrEqual(back.frame.width, 56, "Playback buttons should stay compact")
        XCTAssertGreaterThan(fallback.frame.width, app.frame.width * 0.75,
                             "Open in TikTok should span the content width")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Portrait player, compact controls, and bottom TikTok action"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let notes = app.buttons["Notes (optional)"]
        app.swipeUp()
        app.swipeUp()
        notes.tap()
        let editor = app.textViews["Workout notes"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "Opening Notes should reveal its editor")
        let note = "UI test: three rounds"
        editor.tap()
        editor.typeText(note)
        let typedValue = editor.value as? String
        XCTAssertTrue(typedValue?.contains(note) == true,
                      "Typing should update the notes editor; observed \(String(describing: typedValue))")
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "Notes should offer a keyboard Done control")
        done.tap()
        app.buttons["Save notes"].tap()

        app.terminate()
        app.launch()
        let reopenedRow = app.descendants(matching: .any).matching(identifier: "workout-\(videoID)").firstMatch
        XCTAssertTrue(reopenedRow.waitForExistence(timeout: 10), "The saved workout should survive app relaunch")
        reopenedRow.tap()
        XCTAssertTrue(fallback.waitForExistence(timeout: 5), "Reopening should display the workout screen")
        app.swipeUp()
        app.swipeUp()
        let reopenedEditor = app.textViews["Workout notes"]
        if !reopenedEditor.exists {
            let notesButton = app.buttons["Notes (optional)"]
            XCTAssertTrue(notesButton.waitForExistence(timeout: 5), "Reopening should keep Notes available")
            notesButton.tap()
        }
        XCTAssertTrue(reopenedEditor.waitForExistence(timeout: 5), "Opening Notes again should reveal its editor")
        let reopenedValue = reopenedEditor.value as? String
        XCTAssertTrue(reopenedValue?.contains(note) == true,
                      "A saved note should survive app relaunch; observed \(String(describing: reopenedValue))")
    }

    @MainActor
    func testBackupMenuShowsExportAndRestoreActions() throws {
        let app = isolatedApp()
        app.launch()
        let backup = app.buttons["Backup and restore"]
        XCTAssertTrue(backup.waitForExistence(timeout: 10), "The library should expose Backup and restore")
        backup.tap()
        XCTAssertTrue(app.buttons["Export backup"].waitForExistence(timeout: 5),
                      "The backup menu should offer Export")
        XCTAssertTrue(app.buttons["Restore backup"].exists, "The backup menu should offer Restore")
    }

    @MainActor
    func testPasteStaysAvailableWhenSearchHasNoMatches() throws {
        let app = isolatedApp()
        _ = pasteUniqueWorkout(into: app)

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), "A saved workout should expose search")
        search.tap()
        search.typeText("no-workout-matches-this-search")

        XCTAssertTrue(app.staticTexts["No matching workouts"].waitForExistence(timeout: 5),
                      "The unique query should produce no results")
        let paste = app.buttons["noMatchesPasteLinkButton"]
        XCTAssertTrue(paste.waitForExistence(timeout: 5), "Paste should remain in the zero-result state")
        XCTAssertTrue(paste.isEnabled, "A zero-result search should still offer Paste")
    }

    @MainActor
    private func isolatedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-YarmsUITestStoreID", UUID().uuidString]
        return app
    }

    @MainActor
    private func pasteUniqueWorkout(into app: XCUIApplication) -> String {
        let videoID = "9\(Int(Date().timeIntervalSince1970 * 1000))"
        UIPasteboard.general.string = "https://www.tiktok.com/@yarms-test/video/\(videoID)"
        app.launch()
        let paste = app.buttons["emptyPasteLinkButton"]
        XCTAssertTrue(paste.waitForExistence(timeout: 10), "An isolated UI test should start with an empty library")
        XCTAssertTrue(paste.isEnabled, "Paste should accept the prepared TikTok link")
        paste.tap()
        XCTAssertTrue(app.buttons["libraryPasteLinkButton"].waitForExistence(timeout: 10),
                      "Pasting should populate the isolated library")
        return videoID
    }
}
