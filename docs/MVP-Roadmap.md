# MVP roadmap

[Documentation index](README.md) · [Current user guide](User-Guide.md) · [Merge and review history](MVP-Progress.md)

Yarms keeps workout links and personal notes on the iPhone without a Yarms account. The four original MVP milestones below are delivered; this page describes their scope, not a list of unfinished features.

| Delivered milestone | Outcome |
| --- | --- |
| Foundation, share, and player validation | SwiftUI app, approved icon, Share extension, durable link capture, paste fallback, official player for canonical video links, and CI build/tests |
| Saving and library | Short-link resolution, available oEmbed title/creator/thumbnail, durable local collection, and search; metadata failure preserves the link |
| Workout player and notes | Video-focused screen, playback controls, optional saved notes, and Open in TikTok fallback |
| Backup and polish | User-owned JSON export/restore, empty/error/accessibility states, and automated verification |

## Delivered follow-ups

- Direct Share Sheet saving with a shared Keychain handoff that supports the owner's free Personal Team build. This replaces the original App Group requirement; follow the [migration guide](Storage-Migration.md) for old libraries.
- Compact player controls, simulator UI journeys, and lowercase `yarms`/`Save to yarms` display names.
- Named folders, moving workouts, and schema 2 files to preserve organization across upgrades.
- A refreshed library/workout layout with light/dark colors and large-text scrolling.
- Confirmed deletion from the library and workout screen, including safe retry when a selected duplicate has been coalesced.
- Note merging that preserves distinct paragraphs across repeated restore and short-link enrichment, plus stronger redirect and player-controller tests.

See [MVP progress](MVP-Progress.md) for merged PRs and recorded checks. The [implementation plan](Implementation-Plan.md) tracks the active repository task; it is not the product roadmap.

## Current boundaries

Yarms has no App Store release, automatic cross-device sync, offline video library, or TikTok download bypass. Playback depends on TikTok's official player and the post remaining available. Restore has a 10 MB import limit even though larger libraries can be exported.

Live Share Sheet, Files, playback, and accessibility checks remain part of [device verification](Testing.md#signed-iphone-checks). The iOS 27 notes-focus layout diagnostic is recorded in [Testing](Testing.md); its cause is not established. Future features should be proposed as focused issues using the [contribution process](../CONTRIBUTING.md).
