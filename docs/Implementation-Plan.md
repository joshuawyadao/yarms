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
- [ ] Run focused and full iPhone simulator tests, an iPhone target build, repository checks, and a folder UI screenshot; commit, push, review, and merge the folder PR after green gates. Signed build currently needs Xcode account credentials refreshed; the unsigned iPhone target build passes.
- [ ] Start a fresh UI branch from updated main; restyle the library and workout screens around the approved icon palette while keeping video prominent, controls usable, and folders easy to scan.
- [ ] Validate accessibility, screenshots, UI flows, build, and tests; update docs, commit, push, review, and merge the UI PR after green gates.

## Open questions
- None. Working defaults are one folder per workout and the approved icon palette; these can be adjusted if the owner steers the design.
