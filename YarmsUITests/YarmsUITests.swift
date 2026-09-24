import UIKit
import XCTest

final class YarmsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPasteSearchPlayerLayoutAndNotesPersistence() throws {
        let app = XCUIApplication()
        let videoID = pasteUniqueWorkout(into: app)
        let row = app.descendants(matching: .any).matching(identifier: "workout-\(videoID)").firstMatch
        if !row.waitForExistence(timeout: 10) {
            XCTFail("The pasted link should appear in the library. \(app.debugDescription)")
            return
        }

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.exists)
        search.tap()
        search.typeText(videoID)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The saved link should be searchable")
        row.tap()

        let back = app.buttons["Back 10 seconds"]
        let fallback = app.buttons["openInTikTokButton"]
        XCTAssertTrue(back.waitForExistence(timeout: 10))
        XCTAssertTrue(fallback.exists)
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
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        let note = "UI test: three rounds"
        editor.tap()
        editor.typeText(note)
        app.buttons["Save notes"].tap()
        XCTAssertTrue(app.staticTexts["Saved on this iPhone"].waitForExistence(timeout: 5))

        app.navigationBars.buttons["Yarms"].tap()
        row.tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertTrue((editor.value as? String)?.contains(note) == true,
                      "A saved note should remain after leaving and reopening the workout")
    }

    @MainActor
    func testBackupMenuShowsExportAndRestoreActions() throws {
        let app = XCUIApplication()
        app.launch()
        let backup = app.buttons["Backup and restore"]
        XCTAssertTrue(backup.waitForExistence(timeout: 10))
        backup.tap()
        XCTAssertTrue(app.buttons["Export backup"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Restore backup"].exists)
    }

    @MainActor
    private func pasteUniqueWorkout(into app: XCUIApplication) -> String {
        let videoID = "9\(Int(Date().timeIntervalSince1970 * 1000))"
        UIPasteboard.general.string = "https://www.tiktok.com/@yarms-test/video/\(videoID)"
        app.launch()
        let emptyPaste = app.buttons["emptyPasteLinkButton"]
        let paste = emptyPaste.waitForExistence(timeout: 3)
            ? emptyPaste : app.buttons["libraryPasteLinkButton"]
        XCTAssertTrue(paste.waitForExistence(timeout: 10))
        XCTAssertTrue(paste.isEnabled)
        paste.tap()
        return videoID
    }
}
