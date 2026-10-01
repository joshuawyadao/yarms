# Test Yarms

The shared **Yarms** scheme includes `YarmsTests` and `YarmsUITests`. Run from the repository root on a Mac with Xcode and an available iPhone simulator. Find a destination with `xcrun simctl list devices available`; substitute its name or ID below. The simulator suite uses invented TikTok-shaped links and controlled network responses for deterministic checks. External TikTok, Share Sheet, signing, and Files behavior also need [device checks](#signed-iphone-checks).

## Local and CI-matching commands

```sh
./scripts/verify-repository.sh
xcodebuild -project Yarms.xcodeproj -scheme Yarms \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Yarms.xcodeproj -scheme Yarms \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

Replace `iPhone 17 Pro` with an installed simulator. The [CI workflow](../.github/workflows/ci.yml) runs `verify-repository.sh` on Ubuntu, builds the simulator app with signing disabled, and chooses an available iPhone simulator on macOS for unit and UI tests with ad-hoc signing (`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`). It disables parallel testing, saves an `.xcresult` bundle, and prints test summaries on success and failure. The test command above mirrors its signing mode without prescribing CI's runner-specific simulator ID or output location. If a test fails, run it again with `-resultBundlePath /tmp/YarmsTests.xcresult` using a fresh path, then inspect it in Xcode or with `xcrun xcresulttool`.

To run one XCTest class, add `'-only-testing:YarmsTests/LibraryTests'` or `'-only-testing:YarmsUITests/YarmsUITests'` before `test`. The Xcode Test navigator is another way to run a selected case. When editing a feature, run its focused class and then the full scheme before proposing a merge.

## What the tests cover

| Test file | Main coverage |
| --- | --- |
| [FoundationTests.swift](../YarmsTests/FoundationTests.swift) | TikTok URL parsing, local file inbox, damaged inbox files, and isolated UI test container selection. |
| [ShortcutCaptureTests.swift](../YarmsTests/ShortcutCaptureTests.swift) | Shared-text capture, invalid text, and deduplication across file and share inboxes. |
| [KeychainInboxTests.swift](../YarmsTests/KeychainInboxTests.swift) | Real shared-Keychain save, load, and removal on a signed iPhone; intentionally skips on simulators. |
| [LibraryTests.swift](../YarmsTests/LibraryTests.swift) | Inbox import and crash recovery, search, metadata enrichment, short-link coalescing, notes, folders, deletion, and library-version compatibility. |
| [MetadataTests.swift](../YarmsTests/MetadataTests.swift) | oEmbed parsing, short-link resolution, failed requests, and redirect host restrictions through controlled URL loading. |
| [PlayerBridgeTests.swift](../YarmsTests/PlayerBridgeTests.swift) | Player-event parsing, origin/frame validation, WebKit command gating and state transitions, duration, error, and seek boundaries. |
| [WorkoutEnrichmentQueueTests.swift](../YarmsTests/WorkoutEnrichmentQueueTests.swift) | Bounded metadata concurrency and selection of incomplete workouts. |
| [BackupTests.swift](../YarmsTests/BackupTests.swift) | Backup round trips, legacy and folder-aware versions, validation, restore merging and idempotence, aliases, notes, and large-library behavior. |
| [BackupImportSecurityTests.swift](../YarmsTests/BackupImportSecurityTests.swift) | Discarding untrusted thumbnail/resolution/alias claims and rejecting conflicting aliases. |
| [BackupExportSizeTests.swift](../YarmsTests/BackupExportSizeTests.swift) | Export from a valid library larger than the import limit. |
| [BackupScalingBenchmarkTests.swift](../YarmsTests/BackupScalingBenchmarkTests.swift) | Opt-in restore scaling for 1,000 versus 4,000 aliases of one video. |
| [YarmsUITests.swift](../YarmsUITests/YarmsUITests.swift) | Twelve simulator UI flows: Paste and search, workout layout and notes editing/save/persistence feedback, backup menu/export, folders, accessibility-size folder picker and Paste access, deletion confirmation, new/duplicate/invalid paste feedback in normal and reduced motion, and explicit completion-modal presentation/dismissal in ordinary and maximum-text reduced-motion configurations. Includes focused feedback contrast audits, full completion-copy bounds, and native swipe dismissal. |

Each UI test starts with a distinct `-YarmsUITestStoreID` UUID, selecting a temporary library and file inbox. That mode does not read the normal Keychain queue; an invalid ID fails closed rather than selecting the normal library. This keeps UI tests separate from an installed personal library. The simulated link is not a live TikTok post, so the UI suite does not prove production playback or metadata availability.

## Motion verification

The confirmation regressions check a successful new paste, an existing-video paste without duplication, an invalid paste clearing prior success feedback, and relaunch without celebrating existing records. The notes flow checks successful-save feedback, clearing on edit, resaving, and persistence. The large-text flow also checks a visible paste result and that its complete wrapped frame can scroll onto the screen. Existing folder, deletion, and large-text flows remain coverage for control reachability and state changes.

`-YarmsUITestReduceMotion` enables the app’s shared reduced-motion policy only in a debug build with `-YarmsUITestStoreID`. It does not change the simulator’s system preferences. This keeps UI tests deterministic; it is not proof of system-setting integration or animation comfort. The app normally reads the native Reduce Motion environment, and the internal preview/test override cannot disable an enabled system preference.

Use the interactive **Save confirmation · action and Reduce Motion** preview to compare save, duplicate, clearing, and rapid repeated actions. On a device, toggle the actual accessibility setting and check that custom scaling, bloom, count transitions, and fades disappear while static feedback remains. Check normal/dark appearance and large text; confirm the bloom stays behind its checkmark, confirmation text remains readable, and controls do not shift. Scroll away/back and background/foreground the app without a new share: neither should replay a celebration. Verify that typing, playback time updates, and ordinary result-list changes stay steady. Confirm a failed persistence operation never claims success; simulator invalid-input coverage alone does not prove every filesystem failure path.

The October 1, 2026 motion change passed the full suite on iPhone 17e / iOS 26.5: 91 passed and two expected skips. After refining empty confirmation spacing at accessibility sizes, three focused dark-mode checks (large text, reduced motion, and notes) and a strengthened light-mode full-message visibility check passed. Simulator screenshots were inspected for light/dark confirmation styling, notes, and large-text wrapping. The existing keyboard/frame diagnostic described below also appeared in these passing notes runs.

## Workout-completion verification

The completion UI tests use an isolated synthetic workout and assert that the modal is absent before Finish workout, shows the exact “Good Job BUNS!” headline when requested, dismisses with Done, and can be opened again. The ordinary-size case checks that unsaved note text survives the modal; the reduced-motion case uses maximum accessibility text and verifies that the title and dismiss action remain reachable. Inspect attached screenshots and the component previews for smiling-heart layout and wrapping.

The October 1, 2026 completion change passed the generic simulator build, both focused completion tests in light mode, and the full suite in dark mode on iPhone 17e / iOS 26.5: 93 passed and two expected skips. Ordinary and maximum-text modal screenshots were inspected in both appearances. The tests scroll Finish completely above the fixed playback tray before tapping; a partially visible button can report `isHittable` while its center is covered by that tray. The existing keyboard/frame diagnostic below appeared again in the passing notes and draft-preservation tests.

On a signed phone, check that the heart/sparkles animate only once per presentation, actual Reduce Motion makes the art static, the modal can be dismissed immediately by button or swipe, and a playing embedded video pauses when Finish workout is tapped. Dismissal must not resume playback. Test unavailable video and external TikTok use; ending a clip, saving notes, and returning to the app must not trigger completion. Simulator UI tests do not prove live TikTok playback or animation comfort.

## Accessible feedback regressions

The UI suite audits contrast for new/duplicate paste and notes-save confirmation text, and for the visible completion modal. The save-screen audit is deliberately limited to the expected result text/identifier; unrelated screen elements are outside that regression, while a contrast issue without an identifiable element still fails. The modal contrast audit has no issue filter. These checks are not a whole-app accessibility certification.

The completion regressions also check native swipe dismissal and require the maximum-text headline and supporting message to fit fully above Done. Apple's broader audit reported possible clipping for these labels, although inspected maximum-text screenshots showed the complete copy. Keep the physical-device Dynamic Type check; do not dismiss future clipping warnings without inspecting the actual layout.

Spoken results are posted through `AccessibilityNotification.Announcement` with `.low` priority from successful save-result handlers, independently of motion settings. With VoiceOver on a signed phone, verify new paste, duplicate paste, shared-link import, and notes-save announcements after current speech finishes, with focus staying put. Failed/invalid saves, relaunching an existing library, scrolling, and repeated unchanged notes saves must not announce success. The UI suite verifies visible results and action paths, not synthesized speech or VoiceOver's announcement queue.

The October 1, 2026 accessibility feedback fixes passed repository checks, a generic simulator build, all five focused feedback tests in ordinary light appearance, and the full suite in dark appearance with Increase Contrast enabled on iPhone 17e / iOS 26.5: 93 passed and two expected skips. The scoped save-result and unfiltered completion-modal contrast audits passed, including maximum-text reduced motion. Updated light/dark screenshots were inspected; the previously documented notes keyboard/frame warning still appeared in passing tests. Simulator appearance and contrast settings were restored afterward.

## Opt-in checks

The restore benchmark skips in ordinary runs and CI. Run it after changing backup validation or restore merging:

```sh
TEST_RUNNER_YARMS_RUN_BACKUP_BENCHMARK=1 xcodebuild \
  -project Yarms.xcodeproj -scheme Yarms \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  '-only-testing:YarmsTests/BackupScalingBenchmarkTests' \
  CODE_SIGNING_ALLOWED=NO test
```

The test runner must receive `YARMS_RUN_BACKUP_BENCHMARK=1`; the `TEST_RUNNER_` prefix passes it into that process. The benchmark builds the archives before timing, takes five samples at each size, and checks that the larger median is less than ten times the smaller median. Substitute an available simulator.

`KeychainInboxTests` intentionally skips on simulator because it verifies the entitlement on a signed physical device. With both app and extension signed for the same team, select the connected iPhone as the Xcode destination and run that class from the Test navigator, or use:

```sh
xcodebuild -project Yarms.xcodeproj -scheme Yarms \
  -destination 'platform=iOS,id=YOUR_DEVICE_ID' \
  '-only-testing:YarmsTests/KeychainInboxTests' test
```

Find the device ID in Xcode or `xcrun xctrace list devices`. Signing and any device trust or developer-mode setup must succeed before the test can exercise Keychain. A simulator pass with this test skipped is not evidence of the signed entitlement working.

## Signed iPhone checks

Use an invented test link where possible, and use a real publicly available post only for behavior that needs TikTok. Check the following before release:

1. From TikTok's Share Sheet, choose **Save to yarms** while Yarms is closed. Launch Yarms and confirm the link appears once. Repeat with Safari and with invalid shared text; the invalid input should report failure.
2. Save canonical and short TikTok links. Check metadata and thumbnails when the network provides them, inline playback and its play/pause/seek/replay controls, and the **Open in TikTok** fallback for an unavailable post.
3. Write notes, close and reopen the app, and confirm persistence. Create, rename, and delete folders; move and delete a workout. Confirm current folder counts, Unfiled behavior after deleting a folder, and deletion confirmation.
4. Export a backup through Files, restore it on another installation or clean library, and check folders, links, notes, and duplicate handling. Backup files contain personal notes; keep test data synthetic and handle real exports privately.
5. Inspect light, dark, and increased-contrast appearances; large text; long titles and folder names; missing metadata; keyboard focus; scrolling; and VoiceOver labels and actions on the library and workout screens. At accessibility text sizes and with long or many folder names, check the folder picker and confirm Paste remains reachable after a search with no matches.

On September 28, 2026, verification recorded an unresolved `Invalid frame dimension (negative or non-finite).` diagnostic on iOS 27 when the notes editor gained focus. The September 30 UI integration run also recorded this diagnostic on iOS 26.5. The recorded player layout assertions and note save/relaunch checks passed, and the diagnostic did not identify an app source location. Recheck keyboard focus and layout on a physical device before attributing or changing geometry.
