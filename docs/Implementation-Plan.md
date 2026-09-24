# Plan

Keep the full-width TikTok video while reducing Yarms's four custom playback buttons to compact 44-point targets. Make Open in TikTok fill the content width, then add repeatable UI automation for the core save-and-follow-along flow on an isolated iPhone simulator.

## Scope
- In: workout-screen layout, accessibility needed for reliable UI automation, an XCUITest target and CI wiring, automated paste/search/notes/backup entry checks, signed-device build, and architecture/progress documentation.
- Out: TikTok downloading, changing the official embed's own controls, an app account, changes to workout or backup file formats, and a test that depends on a particular live TikTok post remaining online.

## Action items
- [x] Reduce Yarms's custom play/pause/seek/replay row to compact, accessible targets while preserving the full-width portrait video; make Open in TikTok a full-width action.
- [x] Add an XCUITest target and stable app-flow tests for paste-link saving, searching, opening a workout, saving and reopening notes, and exposing backup export/restore actions. Use an isolated simulator and a deterministic TikTok-shaped link rather than depending on live network content.
- [x] Keep Files export/restore archive behavior covered by existing unit tests; document the system picker and live TikTok flows as device-only gaps. The UI test checks that both backup actions are present.
- [x] Run the focused UI tests, full simulator suite, repository verification, and signed generic iPhone build; inspect screenshots or UI hierarchy for the control and button layout. Avoid overwriting the user's library during automation.
- [x] Update Architecture and MVP Progress with the layout, test coverage, results, and any live TikTok or Files behavior automation could not prove.
- [x] Commit and push the branch, then open PR #6 for the project's milestone workflow. Review and CI gates remain in progress.

## PR #6 feedback
- [x] Keep Paste available when a nonempty library has zero search matches. Reuse one system PasteButton implementation across empty, filtered, and populated library states.
- [x] Add a UI regression test for the zero-match search state, run the focused and complete simulator suite plus repository checks, and update the review ledger.
- [x] Save and push the fix, acknowledge the addressed Codex comment, and request a fresh review. Required checks remain in progress.

## CI diagnosis
- [x] Record an Xcode result bundle during CI Verify and print the failure summary when simulator tests fail. A superseded macOS 15 run reported a UI test failure after nearly ten minutes without its assertion details in the quiet log.
- [x] Print the failing test's detailed Xcode result. It still omitted the assertion line, so label each assertion in the failing UI flow and print its recent XCTest activities on the next CI failure.
- [x] Remove the transient save-confirmation assertion that fails on iOS 18.5 while retaining the reopen-and-read persistence assertion. The next CI run exposed a stale library row when reopening on that OS.
- [x] Refresh the parent library after a successful note save so navigation reuses the persisted workout. The local full simulator suite, repository checks, and signed build pass; CI still needs to validate the older iOS behavior.
- [x] On iOS 18.5, the reopened detail still hides its editor. Make the UI test open Notes explicitly on return, then verify the saved text to distinguish a collapsed DisclosureGroup from a failed write. The focused local test passes.
- [x] Scroll to Notes after reopening before checking whether its editor is present; older iOS may omit offscreen TextEditor elements from the accessibility tree. The focused local UI test passes and the saved-text assertion remains.
- [x] Restart Yarms after saving a note and verify the persisted text in a newly loaded library record. Include the observed text on failure; the focused local UI test passes.
- [x] Add a Done control for the notes keyboard and verify the editor contains typed text before saving; dismiss the keyboard, save, and read back the note after relaunch. The local full suite and signed iPhone build pass.
- [x] Verify that the same note flow passes on iOS 18.5 CI. At `8a0c9b0`, CI Verify passed all 60 runnable tests with 2 expected opt-in skips.
- [x] Check fresh Codex review and mergeability for `8a0c9b0`: no new findings, both checks green, no conflicts.
- [ ] Recheck CI, Codex review, and mergeability on the final documentation commit before merging PR #6.

## PR #6 second review
- [x] Launch each UI test with a unique temporary workout store and disable normal Keychain inbox import for that launch; invalid test-store arguments must never fall back to the normal library.
- [x] Verify the store-routing contract and rerun UI, unit, repository, signed-build, review, and CI gates on `8a0c9b0`. Local and remote tests, review, and build pass.

## Open questions
- None. The existing saved workout is useful for a device smoke check; deterministic simulator fixtures are better for repeatable tests.
