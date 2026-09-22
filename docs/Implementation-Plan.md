# Plan

Finish the Yarms MVP with a user-owned JSON backup that can be exported to Files and restored into the local library. Validate the whole archive before changing storage, merge matching workouts without erasing current notes, and keep the flow accessible without an account or required typing.

## Scope
- In: versioned backup format, export and confirm-before-restore UI, additive library merge, empty/error/accessibility polish, tests, documentation, final main verification.
- Out: TikTok video files, cloud sync, accounts, automatic backup, or overwriting a current library from an import.

## Action items
[x] Confirm PR #3 merged and create `feat/backup-polish` from its `main` merge commit.
[ ] Add a versioned backup codec and validate imported TikTok links, schema, and size before any library write.
[ ] Add additive restore logic that keeps existing workouts and notes, fills missing details, and remains idempotent on repeated import.
[ ] Add Files export and import with a restore confirmation and clear success/error feedback in the SwiftUI library.
[ ] Add focused backup tests for round-trip data, invalid/unsupported archives, duplicate imports, and preserving current notes.
[ ] Polish library empty states and accessibility around backup, then update README, architecture, and progress docs.
[ ] Run repository verification, full iPhone simulator tests, and signed simulator build; review privacy and device-only limitations.
[ ] Commit and push the milestone, open PR #4, obtain Brooks and Codex reviews, clear all required checks, and merge after the gates pass.
[ ] Update `main`, verify its final commit, app build, relevant tests, and four merged PRs.

## Open questions
- None. Restore is additive so an imported file cannot erase the current on-device collection.
