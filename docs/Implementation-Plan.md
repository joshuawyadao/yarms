# Plan

Turn a saved workout into a video-first follow-along screen. Use TikTok's documented embedded-player messages for simple playback controls, keep Open in TikTok visible, and store optional notes locally with the workout.

## Scope
- In: official-player host page and bridge, play/pause and short seek controls with state/error feedback, optional saved notes, tests and documentation.
- Out: video downloads, offline media, accounts, exercise programming, and backup/export (milestone 4).

## Action items
[x] Confirm PR #2 merged, fast-forward `main`, and create a fresh feature branch from the merge commit.
[x] Add a narrow host-to-player and player-to-host bridge for TikTok's documented `postMessage` interface; validate origin and message shape.
[x] Make the workout screen video-first with easy play/pause, seek, and replay controls plus a persistent Open in TikTok fallback.
[x] Add optional local notes to workout records; preserve them if duplicate links coalesce and ensure older library records decode.
[x] Test player message parsing and commands, note persistence, backward compatibility, and duplicate-note behavior.
[x] Update README, architecture, progress, and device checks; run simulator build, tests, repository verification, and signed-library visual inspection. Record the locked-Mac player-inspection limit.
[x] Review error states, playback availability, notes durability, accessibility labels, and privacy before PR review.

## Open questions
- None. Use the official player rather than downloading video, and keep notes optional and on device.

## PR #3 review follow-up
- [ ] Accept duration in either the ready or current-time event, and accept a current-time event that omits duration; preserve validation of malformed numbers.
- [ ] Cover both event shapes with focused tests, run the full simulator suite and repository verification, then push the fix and request a new Codex review.
