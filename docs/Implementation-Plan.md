# Plan

Build the first reviewable Yarms iPhone milestone: an installable SwiftUI shell that receives a shared TikTok link without typing, stores it immediately in a local App Group inbox, and opens the official embedded player. Establish an iOS build and test gate before adding the full library in the next milestone.

## Scope
- In: Xcode app and share extension targets, approved app icon, TikTok URL parsing, atomic shared inbox, paste fallback, early embedded-player validation, unit tests, CI build/test, and developer/device-check documentation.
- Out: oEmbed enrichment, searchable library, workout notes, backup/export, account integration, and post downloads; these belong to later milestones.

## Action items
[ ] Add a reproducible Xcode project with app, share extension, shared core, unit tests, App Group entitlements, and the approved icon.
[ ] Implement TikTok URL recognition and an atomic file inbox that can accept shared links before the main app launches.
[ ] Implement the share extension's automatic URL capture and the app's paste-link fallback and pending-link display.
[ ] Validate the official TikTok embedded player in a SwiftUI screen with an Open in TikTok fallback.
[ ] Add unit tests for accepted/rejected links and inbox persistence, including duplicate and malformed inputs.
[ ] Update the README and focused architecture/device-verification docs for the current milestone and remaining MVP roadmap.
[ ] Extend CI to run repository verification plus an iOS simulator build and unit tests; run the same checks locally where available.
[ ] Review edge cases around unavailable App Group containers, share input types, embed availability, and simulator-only behavior.

## Open questions
- None. Use iOS 18 as the minimum OS, local-only storage, and an App Group shared by the app and extension; verify the actual iOS share sheet and TikTok playback on a device during release testing.
