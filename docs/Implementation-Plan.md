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
- [ ] Commit and push the branch, then prepare a reviewed, green PR in keeping with the project's milestone workflow.

## Open questions
- None. The existing saved workout is useful for a device smoke check; deterministic simulator fixtures are better for repeatable tests.
