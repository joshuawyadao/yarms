# Plan

Build the first reviewable Yarms iPhone milestone: an installable SwiftUI shell that receives a shared TikTok link without typing, stores it immediately in a local App Group inbox, and opens the official embedded player. Establish an iOS build and test gate before adding the full library in the next milestone.

## Scope
- In: Xcode app and share extension targets, approved app icon, TikTok URL parsing, atomic shared inbox, paste fallback, early embedded-player validation, unit tests, CI build/test, and developer/device-check documentation.
- Out: oEmbed enrichment, searchable library, workout notes, backup/export, account integration, and post downloads; these belong to later milestones.

## Action items
[x] Add a reproducible Xcode project with app, share extension, shared core, unit tests, App Group entitlements, and the approved icon.
[x] Implement TikTok URL recognition and an atomic file inbox that can accept shared links before the main app launches.
[x] Implement the share extension's automatic URL capture and the app's paste-link fallback and pending-link display.
[x] Validate the official TikTok embedded player in a SwiftUI screen with an Open in TikTok fallback. The simulator launch displayed the app; live playback remains a device check.
[x] Add unit tests for accepted/rejected links and inbox persistence, including duplicate and malformed inputs. Five simulator tests pass.
[x] Update the README and focused architecture/device-verification docs for the current milestone and remaining MVP roadmap.
[x] Extend CI to run repository verification plus an iOS simulator build and unit tests; local build, tests, and repository verification pass.
[x] Review edge cases around unavailable App Group containers, share input types, embed availability, and simulator-only behavior. Document device checks in `docs/Architecture.md`.
[x] Address Brooks review's multi-URL share concern: scan every URL in shared text so a valid TikTok link is saved even when another link appears first; add a regression test and rerun the simulator suite. Six tests pass.
[ ] Address Codex review's scheme launch concern: set the Yarms app as the shared scheme's Run and Profile executable, verify the generated scheme, then rerun build and tests.

## Open questions
- None. Use iOS 18 as the minimum OS, local-only storage, and an App Group shared by the app and extension; verify the actual iOS share sheet and TikTok playback on a device during release testing.
