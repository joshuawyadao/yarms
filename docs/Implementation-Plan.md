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
