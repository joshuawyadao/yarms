# Plan

Improve the iPhone-to-iPad workout flow with clearer capture, identifiable library cards, configurable playback, and a dated workout history.

## Scope
- In: Paste presentation, editable names, thumbnails, empty Unfiled filter, native iPad support, configurable skips, and calendar history.
- In: Assess iCloud sync and exercise TikTok’s existing fullscreen control on an iPad mini simulator.
- Out: Enabling CloudKit or changing TikTok’s fullscreen behavior before the device check.

## Action items
- [x] Inspect the current library, player, backup format, TestFlight requirements, and XCTest coverage. Start the feature branch from the latest origin/main in a separate worktree.
- [x] Make Paste identifiable, offer naming after save and renaming from the library, preserve manual names across enrichment and restore, and hide the empty Unfiled filter.
- [x] Strengthen thumbnail fetch and display for new and existing records without trusting imported image URLs. Check the official TikTok sample and provide a useful fallback.
- [x] Add in-app playback skip settings with a 10-second default, and enable native iPad device families and supported orientations.
- [x] Make Log workout record a separate, durable completion on each session, show confirmation, and add a calendar history. Preserve saved workouts, history across deletions, and repeat-safe backup restore.
- [x] Record iCloud feasibility and signed-device prerequisites. Update User-Guide, Data-and-Privacy, Architecture, Development, Testing, and the bundled privacy policy where behavior or validation changes.
- [x] Add XCTest coverage for names, thumbnails, history, backup compatibility, filter behavior, and skip controls. Run repository verification, the full iPhone suite, the unsigned Release check, and iPad mini simulator checks in portrait and landscape. Record live fullscreen evidence and physical-device limits.
- [x] Checkpoint the implementation and push the verified feature branch.

## Validation

- Repository verification passed all 56 host tests. The unsigned Release check passed for Yarms and the Share extension.
- The final unit run executed 120 tests on iPadOS 27.0. Three expected skips cover signed-device Keychain and opt-in benchmarks.
- The full iPhone run covered the new naming, folder, skip, and repeat-history flows. Focused reruns passed both completion tests after updating the expected confirmation text and improving maximum-text reachability.
- The largest-text folder test passed in the first full run. After shortening the save card, an older scroll gesture overshot the picker. The focused check with smaller scroll gestures stalled during the app launch, and a fresh simulator retry stalled during boot. This last layout check remains open.
- Native VoiceOver automation failed twice when sending `moveForward`, before it could verify focus restoration. The focus assertion remains active.
- The iPad mini layout test passed in portrait and landscape. TikTok’s public sample played and paused in landscape with no tappable fullscreen control in the tested states. The physical-device check is pending.
- The official public sample supplied the poster through its public page after oEmbed omitted a thumbnail. Its poster URL returned a JPEG, and metadata tests cover the fallback and trust boundary.

## PR review follow-up

Keep TikTok poster recovery working after signed URLs expire or TikTok responds with a temporary error. Preserve the existing network trust boundary and verify the 10-second setting default.

- [x] Inspect Codex and Brooks findings at `3bc5467` and map them to the metadata, retry queue, and player tests.
- [x] Reproduce expired selected posters and retryable public-page failures with controlled HTTP responses.
- [x] Filter expired candidates before selection and pass transient public-page failures to the bounded enrichment queue.
- [x] Assert the current playback default and update the poster retry contract in Data and Privacy.
- [ ] Run the metadata regressions and monitor both required GitHub checks and the latest Codex review.

Both new metadata cases reproduced the bugs before the fix and passed afterward. All 20 metadata tests passed in the isolated SwiftPM harness using the app’s actual metadata source. The iPhone UI regression checks the initial 10-second labels through the player, in addition to the separate five-second persistence and seek test.

## Open questions
- None.
