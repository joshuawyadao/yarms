# Plan

Make removing a saved workout easy to find from both the library and the workout screen. Ask for confirmation before deleting the local link, its notes, and folder assignment, while keeping other workouts and folders intact.

## Scope
- In: a confirmed delete action for saved workouts, persistent removal, focused tests, and current user and architecture documentation.
- Out: deleting the TikTok post, downloading video files, bulk deletion, and changing backup restore behavior.

## Action items
- [x] Confirm the existing `WorkoutStore.remove` behavior, library row actions, workout toolbar, and relevant docs and tests.
- [x] Make removal report whether the workout existed and preserve unrelated library and folder data in `WorkoutStore`.
- [x] Add confirmed Delete actions to the library row and workout screen, with clear copy and safe error handling.
- [x] Extend `YarmsTests/LibraryTests.swift` and `YarmsUITests/YarmsUITests.swift` for persistence, cancellation, folder counts, and both delete entry points.
- [x] Update `README.md` and `docs/Architecture.md` to describe local workout removal and its effect on notes and backups.
- [x] Run focused and full simulator tests, an iPhone build, repository verification, and a signed install on the connected iPhone if available; review empty-library and stale-record behavior. The iOS 27 suite passed 73 unit cases (two expected skips) and seven UI cases; the signed build installed and launched on the iPhone.
- [x] Commit the tested change and push `codex/remove-saved-workout` for review.

## Open questions
- None. Use confirmation before removal and keep the existing backup restore semantics.

## PR #11 review follow-up

Both Brooks and Codex review found that enrichment can coalesce the selected workout while a delete confirmation is open. Honor a missing-record removal result so the app never reports success or dismisses the workout without deleting it.

- [ ] Refresh the library and report failure when `WorkoutStore.remove` returns false; give retry guidance from both delete entry points.
- [ ] Add a deterministic `LibraryTests` regression for coalescing between selecting a workout and confirming deletion, then deleting the surviving record.
- [ ] Document the stale-record behavior in `docs/Architecture.md` and record Brooks review findings.
- [ ] Run focused library and deletion UI tests, repository verification, and await final-head CI and Codex re-review.
- [ ] Save and push the reviewed fix on `codex/remove-saved-workout`.

No open questions or schema changes. Existing README deletion instructions remain valid.
