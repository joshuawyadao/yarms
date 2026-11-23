# Plan

Improve the iPhone-to-iPad workout flow with clearer capture, identifiable library cards, configurable playback, and a dated workout history.

## Scope
- In: Paste presentation, editable names, thumbnails, empty Unfiled filter, native iPad support, configurable skips, and calendar history.
- In: Assess iCloud sync and exercise TikTok’s existing fullscreen control on an iPad mini simulator.
- Out: Enabling CloudKit or changing TikTok’s fullscreen behavior before the device check.

## Action items
- [x] Inspect the current library, player, backup format, TestFlight requirements, and XCTest coverage. Start the feature branch from the latest origin/main in a separate worktree.
- [ ] Make Paste identifiable, offer naming after save and renaming from the library, preserve manual names across enrichment and restore, and hide the empty Unfiled filter.
- [ ] Strengthen thumbnail fetch and display for new and existing records without trusting imported image URLs. Check the official TikTok sample and provide a useful fallback.
- [ ] Add in-app playback skip settings with a 10-second default, and enable native iPad device families and supported orientations.
- [ ] Make Log workout record a separate, durable completion on each session, show confirmation, and add a calendar history. Preserve saved workouts, history across deletions, and repeat-safe backup restore.
- [ ] Record iCloud feasibility and signed-device prerequisites. Update User-Guide, Data-and-Privacy, Architecture, Development, Testing, and the bundled privacy policy where behavior or validation changes.
- [ ] Add XCTest coverage for names, thumbnails, history, backup compatibility, filter behavior, and skip controls. Run repository verification, the full iPhone suite, the unsigned Release check, and iPad mini simulator checks in portrait and landscape. Record live fullscreen evidence and physical-device limits.
- [ ] Checkpoint the implementation and push the verified feature branch.

## Open questions
- None.
