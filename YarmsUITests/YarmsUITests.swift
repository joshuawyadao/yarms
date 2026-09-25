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
        XCTAssertTrue(row.label.contains(videoID),
                      "A workout without TikTok metadata should retain its unique video link in the row label")

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.exists, "Search should appear after a workout is saved")
        search.tap()
        search.typeText(videoID)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The saved link should be searchable")
        row.tap()

        let back = app.buttons["Back 10 seconds"]
        let fallback = app.buttons["openInTikTokButton"]
        XCTAssertTrue(app.staticTexts["WORKOUT"].waitForExistence(timeout: 5),
                      "The player should show the workout heading above the video")
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
    func testFolderOnlyLibraryAllowsBackupExport() throws {
        let app = isolatedApp()
        app.launch()
        app.buttons["newFolderButton"].tap()
        let editor = app.alerts["New folder"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "An empty library should allow a folder")
        editor.textFields["Folder name"].tap()
        editor.textFields["Folder name"].typeText("Yoga")
        editor.buttons["Create"].tap()

        app.buttons["Backup and restore"].tap()
        let export = app.buttons["Export backup"]
        XCTAssertTrue(export.waitForExistence(timeout: 5), "Backup should remain visible")
        XCTAssertTrue(export.isEnabled, "A folder-only library should be exportable")
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
    func testCreateFolderAndMoveSavedWorkout() throws {
        let app = isolatedApp()
        let videoID = pasteUniqueWorkout(into: app)
        let row = app.descendants(matching: .any).matching(identifier: "workout-\(videoID)").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The shared link should appear before filing")

        app.buttons["newFolderButton"].tap()
        let editor = app.alerts["New folder"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "New folder should open a name editor")
        let name = editor.textFields["Folder name"]
        name.tap()
        name.typeText("Leg day")
        editor.buttons["Create"].tap()
        XCTAssertTrue(app.staticTexts["This folder is empty"].waitForExistence(timeout: 5),
                      "A newly created folder should start empty")

        app.buttons["folder-all"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The unfiled workout should remain in All")
        row.swipeLeft()
        app.buttons["Move"].tap()
        let destination = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "moveToFolder-")
        ).firstMatch
        XCTAssertTrue(destination.waitForExistence(timeout: 5), "Move should list the new folder")
        XCTAssertTrue(destination.label.contains("Leg day"), "The destination should have the entered name")
        destination.tap()

        let filedChip = app.buttons["Leg day, 1 workouts"]
        XCTAssertTrue(filedChip.waitForExistence(timeout: 5), "The folder count should update after moving")
        filedChip.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The folder should show its filed workout")
        let libraryScreenshot = XCTAttachment(screenshot: app.screenshot())
        libraryScreenshot.name = "Library save action, folders, and filed workout card"
        libraryScreenshot.lifetime = .keepAlways
        add(libraryScreenshot)
        app.buttons["folder-unfiled"].tap()
        XCTAssertFalse(row.exists, "The moved workout should leave Unfiled")
    }

    @MainActor
    func testDeleteFromLibraryRequiresConfirmation() throws {
        let app = isolatedApp()
        let videoID = pasteUniqueWorkout(into: app)
        let row = app.descendants(matching: .any).matching(identifier: "workout-\(videoID)").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))

        row.swipeLeft()
        let delete = app.buttons["deleteWorkoutSwipeButton"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "A library row should expose Delete")
        delete.tap()
        let alert = app.alerts["Delete saved workout?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Cancel"].tap()
        XCTAssertFalse(alert.exists, "Cancel should close the delete confirmation")
        XCTAssertTrue(row.exists, "Cancel should keep the saved workout")

        if !delete.exists { row.swipeLeft() }
        delete.tap()
        alert.buttons["Delete workout"].tap()
        XCTAssertTrue(app.staticTexts["No workouts yet"].waitForExistence(timeout: 5))
        XCTAssertFalse(row.exists, "Confirming should remove the library row")
    }

    @MainActor
    func testDeleteFromWorkoutReturnsToLibrary() throws {
        let app = isolatedApp()
        let videoID = pasteUniqueWorkout(into: app)
        let row = app.descendants(matching: .any).matching(identifier: "workout-\(videoID)").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()

        let delete = app.buttons["deleteWorkoutDetailButton"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "The workout screen should expose Delete")
        delete.tap()
        let alert = app.alerts["Delete saved workout?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Delete workout"].tap()

        XCTAssertTrue(app.staticTexts["No workouts yet"].waitForExistence(timeout: 5),
                      "Deleting from the workout screen should return to the empty library")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["No workouts yet"].waitForExistence(timeout: 10),
                      "A deleted workout should stay gone after relaunch")
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
        XCTAssertTrue(app.staticTexts["Save a workout"].waitForExistence(timeout: 10),
                      "The library should make its save action clear")
        XCTAssertTrue(app.staticTexts["Folders"].exists,
                      "Folder browsing should have a visible section heading")
        let paste = app.buttons["emptyPasteLinkButton"]
        XCTAssertTrue(paste.waitForExistence(timeout: 10), "An isolated UI test should start with an empty library")
        XCTAssertTrue(paste.isEnabled, "Paste should accept the prepared TikTok link")
        paste.tap()
        XCTAssertTrue(app.buttons["libraryPasteLinkButton"].waitForExistence(timeout: 10),
                      "Pasting should populate the isolated library")
        XCTAssertTrue(app.staticTexts["Saved workouts"].exists,
                      "Saved videos should appear under a distinct library heading")
        return videoID
    }
}
