# Plan

Add named folders so saved workouts can be organized without changing Share Sheet capture or video playback. Deliver that as one reviewed milestone, then refresh the library and workout UI in a second milestone using the approved yarms icon's pink and purple palette.

## Scope
- In: one folder per workout, Unfiled for new shares, folder create/rename/delete, moving workouts, folder browsing and search, backup/restore preservation, accessible library and player UI polish, tests, and current docs.
- Out: downloaded video files, app accounts, cloud sync, nested folders, multiple folders on one workout, and changes to TikTok's official player controls.

## Action items
- [x] Add durable folder records and workout assignments in `WorkoutStore`, with safe decoding of existing libraries, folder deletion that keeps workouts, and deterministic assignment when duplicate links merge.
- [x] Include folders in backup export/import with validation, stable restore mapping, and compatibility with older backups.
- [x] Add library and workout controls for creating, renaming, deleting, browsing, and assigning folders; keep saving a shared TikTok link immediate and Unfiled by default.
- [x] Add meaningful unit and UI tests for legacy data, folder operations, duplicate resolution, backup round trips, and the main folder flow; update README and architecture docs.
- [x] Address Brooks review: index folder names and IDs during backup restore so a large archive does not repeatedly scan the growing folder list; verify the mapping and document the review result.
- [x] Address Codex review: allow a folder-only library to export a backup, with a UI regression test.
- [x] Address Codex review: foregrounding after a new share must reveal it in Unfiled even when the current library is empty, with a focused selection regression test.
- [x] Address Codex review: count workouts by folder in one pass before rendering folder chips, with focused count tests.
- [x] Address final Codex review: export folder-aware backups as schema 2 so older apps reject them, continue importing schema 1 backups, and test both compatibility directions.
- [x] Address local-library downgrade risk: write schema 2 libraries, read legacy schema 1 libraries, and prove folder data cannot be silently rewritten by an older build.
- [x] Run focused and full iPhone simulator tests, an iPhone target build, repository checks, and a folder UI screenshot; commit, push, review, and merge the folder PR after green gates. PR #8 merged at `e3a2045`. A signed local build still needs refreshed Xcode account credentials; CI Verify built and tested the app successfully.
- [x] Start a fresh UI branch from updated `main` at `e3a2045`.
- [x] Apply an accessible palette derived from the approved icon, with light and dark colors; simplify the library save action, folder navigation, workout cards, and empty states.
- [x] Restyle the workout screen while preserving full-width portrait playback, 44-point controls, optional notes, folder movement, and the full-width Open in TikTok fallback.
- [x] Add or update UI assertions for the new library hierarchy and player accessibility, keeping isolated fabricated TikTok links; update README and architecture docs. Update the progress ledger with final review and merge evidence.
- [x] Address PR #9 Codex feedback: keep selected chips and filled actions readable in dark mode, make the save/folder/library hierarchy one scrolling region at large text sizes, and give metadata-free rows a unique link label. The full simulator suite passed in dark mode at accessibility-large text size, and inspected screenshots show readable filled actions and reachable workout cards. A UI assertion checks that an unavailable video's row retains its unique ID. Push, acknowledge the comments, and request final review in the next action.
- [ ] Validate screenshots, the full simulator suite, an iPhone target build, and repository checks; commit and push the UI branch, complete Codex and Brooks reviews and CI, then merge the green PR. Local light-mode and dark accessibility-large suites each passed 72 unit and 5 UI tests (2 expected opt-in skips), as did the unsigned iPhone build, repository verification, and screenshot inspection. A PR self-review fixed a duplicate-folder-ID trap in the new label index. Final review and CI remain pending.

## Open questions
- None. Working defaults are one folder per workout and the approved icon palette; these can be adjusted if the owner steers the design.
