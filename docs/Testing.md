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
| [YarmsUITests.swift](../YarmsUITests/YarmsUITests.swift) | Paste, search, workout layout, notes persistence, backup menu/export, folder flow, and deletion confirmation in the simulator UI. |

Each UI test starts with a distinct `-YarmsUITestStoreID` UUID, selecting a temporary library and file inbox. That mode does not read the normal Keychain queue; an invalid ID fails closed rather than selecting the normal library. This keeps UI tests separate from an installed personal library. The simulated link is not a live TikTok post, so the UI suite does not prove production playback or metadata availability.

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
5. Inspect light and dark appearances, large text, long titles and folder names, missing metadata, keyboard focus, scrolling, and VoiceOver labels and actions on the library and workout screens.

On September 28, 2026, verification recorded an unresolved `Invalid frame dimension (negative or non-finite).` diagnostic on iOS 27 when the notes editor gained focus. The recorded player layout assertions and note save/relaunch checks passed, and the diagnostic did not identify an app source location. Recheck keyboard focus and layout on a physical device before attributing or changing geometry.
