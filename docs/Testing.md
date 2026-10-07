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
| [YarmsUITests.swift](../YarmsUITests/YarmsUITests.swift) | Thirteen UI flows: Paste and search, workout layout and notes editing/save/persistence feedback, backup menu/export, folders, accessibility-size folder picker and Paste access, deletion confirmation, new/duplicate/invalid paste feedback in normal and reduced motion, explicit completion-modal presentation/dismissal in ordinary and maximum-text reduced-motion configurations, and native VoiceOver modal navigation/focus restoration on iOS 27. Includes focused feedback contrast audits, full completion-copy bounds, and native swipe dismissal. |

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

Spoken results are posted through `AccessibilityNotification.Announcement` with `.low` priority from successful save-result handlers, independently of motion settings. With VoiceOver on a signed phone, verify new paste, duplicate paste, shared-link import, and notes-save announcements after current speech finishes, with focus staying put. Failed/invalid saves, relaunching an existing library, scrolling, and repeated unchanged notes saves must not announce success. The save-feedback UI tests verify visible results and action paths; they do not verify VoiceOver's announcement queue.

On Xcode 27 / iOS 27, `testVoiceOverCompletionRestoresFocusToFinish` enables native VoiceOver, checks the spoken headline → message → Done order inside the modal, and checks that dismissal returns spoken focus to Finish workout. It restores the initial VoiceOver setting and skips on older SDKs/runtimes. On October 2, 2026, the regression failed before the fix because dismissal left focus on the navigation Back button even after a five-second wait. A VoiceOver-scoped accessibility focus binding restored Finish workout in the passing simulator run. This automated speech/navigation result does not replace physical-device listening or comfort checks.

Use XCTest teardown for device-setting restoration: a fatal XCTest assertion can bypass a Swift `defer` in the test method. Keep ordinary tap-based tests on a simulator with VoiceOver off. The large-text picker test also scrolls its full frame clear of navigation and search before tapping; on iOS 27, the bottom search field can cover its center even while XCTest reports `isHittable`.

The October 2, 2026 follow-up passed repository verification, generic simulator and signed iPhone builds, and the complete iOS 27 simulator suite: 94 passed and two expected skips (signed-device Keychain and the opt-in benchmark), including all 13 UI tests. The final run used one active UI suite with VoiceOver initially off and restored it to off afterward. Earlier diagnostic failures from leftover VoiceOver and the covered picker tap were resolved in the test harness; a reduced-motion Paste failure did not recur in focused, ordered, and final full runs. The signed build was prepared but not installed during this follow-up because the phone was locked; native accessibility settings, Share Sheet delivery, and the other physical-device gaps remain open.

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

### Physical smoke evidence

On October 1, 2026, the signed iPhone 18 Pro Max / iOS 27.0 run passed the Keychain save/load/remove test and three focused UI flows: notes editing/save/relaunch, completion with unsaved-draft preservation and button/swipe dismissal, and maximum-text completion using the app's Reduce Motion override. The scoped notes contrast and completion contrast audits passed; screenshots showed readable copy and reachable Done controls. The personal library matched its pre-test bytes afterward.

The device UI runner could not write `UIPasteboard.general` while backgrounded. A temporary test copy supplied an invented fixed link through `devicectl device pasteboard copy` after each app launch, retaining the app code and UI assertions. The ordinary simulator clipboard fixture is not a reliable physical-device setup. The phone also locked during setup; a run waiting for unlock is not a completed test. Temporary test runners were removed afterward to release a free-profile app slot.

Those initial passes did not establish native Reduce Motion integration, VoiceOver speech/navigation, live TikTok playback, extension-to-app sharing, or a completed Files backup round trip. Track those as separate checks; the signed Keychain unit test alone does not exercise the Share extension.

### Native accessibility device evidence

On October 2, 2026, the signed iPhone 18 Pro Max / iOS 27.0 passed both targeted native accessibility tests with the actual system Reduce Motion setting enabled. A temporary diagnostic recorder confirmed that UIKit, SwiftUI, and the app's effective motion policy all reported the native setting. The earlier normal-motion save flow recorded all three as disabled. Neither run used the app's Reduce Motion test override.

Native VoiceOver navigation checked the completion headline → supporting message → Done order, then verified that dismissal returned focus to Finish workout. In both motion settings, iOS delivered successful announcement-completion notifications for “Saved for your next move.”, “Already in your library.”, and “Saved on this iPhone”. Notes focus stayed on Save notes, and saving unchanged notes again produced no additional completion notification during the observation window. These are device/API observations; human listening quality and visual motion comfort remain separate checks.

The temporary tests used isolated synthetic libraries and waited for a host clipboard-readiness file before Paste. The initial expired test-runner profile was renewed through Xcode; a code-signature check alone does not establish that a provisioning profile is unexpired. A controller interruption allowed one save flow to finish but prevented the following modal fixture from being supplied in time; that incomplete run was recovered and cleaned up. The subsequent uninterrupted reduced-motion run passed both tests. After each attempt, the clean app was installed over the diagnostic copy, the test runner was removed, and the original appearance and VoiceOver settings were verified restored. No personal-library copy or fresh byte comparison was performed during this follow-up.

### Files round-trip evidence

On October 2, 2026, a temporary UI harness on iPhone 17e / iOS 26.5 exported a uniquely named synthetic JSON backup through the native **On My iPhone** picker. It selected that exact file from **Recents** and restored into a different `-YarmsUITestStoreID` library. The test confirmed one added workout, the restored folder and its count, and the exact note text. Importing the same file again reported zero added workouts and retained one row and one folder. A separate check dismissed the restore confirmation through its native popover-dismiss region and verified that the destination stayed empty. The exact synthetic exports were removed afterward. These checks passed through the actual Files picker and backup confirmation UI, rather than calling the store directly. They do not establish physical-device Files-provider behavior.

Later that day, the corresponding signed iPhone 18 Pro Max / iOS 27.0 test passed through the real local Files provider. Before export, it required both the active local-storage root and its On My iPhone navigation title, preventing a sidebar label from being mistaken for the selected destination. It exported one synthetic workout with a folder and notes, relaunched into a different empty test library, cancelled restore without adding a workout, restored successfully with exact notes and folder count, and imported again with zero additions. The clean app and original settings were restored.

On October 3, 2026, automated cleanup of the exact synthetic export `yarms-backup-0A9F75DA.json` passed on the phone in 12.509 seconds. Native Files selection mode required no existing selection, selected only the exact file, verified that it was the sole selected item, and invoked the unique Delete control. Reopening Recents confirmed that the file was absent. This resolved the earlier import-picker and long-press synchronization failures. The run restored the clean app and original settings, removed the runner, and reported no cleanup errors. No manual deletion is needed.

### Live-player simulator evidence

On October 2, 2026, a disposable iPhone 17e / iOS 26.5 simulator played TikTok's official public sample `6718335390845095173` in an isolated library. The embed needed a tap on its own Play button before emitting `onPlayerReady`; disabled native controls before that gesture were not evidence of a failed player. Actual player time advanced from 0:02 to 0:03. Finish workout sent pause at about 6.3 seconds, and TikTok acknowledged paused state (`onStateChange: 2`). After Done, the app showed Play and held 0:06 for four seconds. The original host HTML/event ordering was used; only diagnostic logging was added in the disposable copy. The temporary simulator was deleted afterward. Playback, audio, and comfort on the physical phone remain separate checks.

### Live-player device evidence

On October 2, 2026, the signed iPhone 18 Pro Max / iOS 27.0 played the same public sample in an isolated test library. Time advanced from 0:02 to 0:03, the control showed Pause at 0:05 immediately before Finish, and Done left the control showing Play with time held at 0:06 throughout the four-second observation window. The targeted test passed. A separate physical-device test forced an unavailable-player state only inside an isolated test store and verified the fallback explanation, reachable Open in TikTok action, and disabled embedded Play control. That deterministic fallback check does not prove TikTok's delivery of a network error or an external TikTok app launch. Both runs restored the clean app and original settings. Human audio and motion-comfort feedback remains unconfirmed.

### Share Sheet simulator evidence

On October 2, 2026, a dedicated temporary harness passed on a fresh iPhone 17e / iOS 26.5 simulator. It invoked the actual Share extension through the native Share Sheet. An invalid non-TikTok URL first produced the marked extension's error alert and left its queue empty. Sharing one invented TikTok link as a URL then imported one workout; sharing the same link as plain text retained one workout. Each valid capture logged one queued link in the extension, and the normally relaunched app showed zero queued links after import. The synthetic library contained exactly one workout. The simulator was deleted afterward.

The disposable copy forced every app launch into one temporary library, used a fresh matching Keychain service in the app and extension, rejected other captures, and kept the production parsing/import path enabled. These safeguards and diagnostic controls are outside the repository. The test waited for extension completion before relaunching the host; terminating the host immediately after selection had interrupted an earlier capture attempt. The successful run proves the URL/text provider, extension, import, acknowledgement, and duplicate flow on that simulator. It does not prove signed-device Keychain access or the provider payloads emitted by Safari and TikTok, because the test's own app supplied the ShareLink. Inspect the physical Share Sheet before interacting; the simulator test's measured activity coordinates are not portable to the phone.

### Share Sheet physical-device evidence

The corresponding signed iPhone 18 Pro Max / iOS 27.0 test passed later on October 2, 2026. It required the marked extension's exact invalid-input title and message before submitting any valid link. A synthetic TikTok URL then imported one workout through the real extension and Keychain inbox; sharing the same link as plain text retained one workout. The app reported an empty queue after both imports. The 59.742-second run completed with no failures, restored the clean app and original accessibility settings, and removed the temporary runner. This establishes physical-device rejection, URL/text delivery, acknowledgement, and deduplication with the test host's ShareLink providers. Safari and TikTok provider payloads require separate coverage; follow-up automation is recorded below.

The user explicitly approved Share Sheet screenshot capture and inspection after an earlier approval denial. That evidence showed Yarms outside the initially visible horizontal app row, then showed that an accessibility cell tap had left the sheet open. The passing temporary harness used a bounded row swipe, required exactly one Yarms activity, checked its live frame against the observed app row, and tapped within that frame using screen coordinates. It retained the marked invalid-input gate before valid captures. The failed attempts were test-control failures; no application change was needed. No broader screenshot capture or fresh personal-library copy was authorized or performed.

### Safari provider and library integrity

On October 3, 2026, the signed iPhone 18 Pro Max / iOS 27.0 passed the Safari provider test in 125.659 seconds. After proving the marked extension with invalid input, Safari shared the fixed synthetic TikTok URL through its own native Share Sheet. Relaunching the isolated app imported one workout and cleared the queue. Sharing that URL again retained one workout and an empty queue. This extends the earlier test-host result to Safari's actual provider payload.

The temporary harness verified the complete fixture URL before sharing. Physical inspection of known accessibility controls distinguished the address field's `URL` identifier from its `Address` label and identified the keyboard's `go` control. Submitting only that verified fixture exited address editing; Page Menu then exposed Share. Earlier selector failures were test-control issues, and no production application change was needed. A disposable iOS 27 simulator had inconsistent Safari startup and did not validate this correction; it was removed. A separate 9.830-second cleanup check verified the exact synthetic URL, opened the known Tabs control's menu, and invoked its unique Close This Tab action. The test tab was closed; the clean app and settings were restored afterward.

The provider harnesses audit the normal on-device `Library.json` without writing it: decode with the app's record types, check supported schema, unique record IDs and valid folder references, and compare a SHA-256 digest before and after each isolated test. The Safari sharing pass and the completed provider attempts all validated the library at launch and confirmed the identical digest on a fresh teardown launch. Only validation results and the digest were exposed; no personal library contents were copied. This establishes current readability and preservation during these runs, not historical identity without a matching baseline. The clean app and original settings were restored, and each runner was removed without cleanup errors. Automatic screenshot attachments were discarded; explicit capture remains limited to the approved Share Sheet scope.

### Remaining TikTok provider check

Two physical attempts on October 3 launched the installed TikTok app with the public sample URL, but its native provider flow remains unverified. The first attempt exposed no exact Share control. A retry added a loading wait and narrow sharing-control queries; those queries timed out in TikTok before a valid share occurred. Both attempts passed the marked invalid-input gate and the on-device library audit, then restored the clean app and settings. These results establish an automation limitation, not an application defect or successful TikTok provider delivery.

The temporary TikTok harness permits only the public sample's concrete video ID. Its gate would reject a shortened link even though the production parser supports short links; that limitation was not reached and must not be reported as an application defect. When checking installation, `devicectl device info apps` needs `--include-default-apps` to include App Store apps; the default inventory lists developer apps only. A short manual TikTok share/re-share check remains, along with the previously noted human listening and animation-comfort judgments.

On October 6, 2026, a temporary assisted harness built successfully. It retains the isolated library/inbox, marked invalid-input gate, concrete public-sample guard, and fresh before/after normal-library audit. After opening the sample in TikTok, it waits for an explicit per-pass completion signal from the user before checking first import and duplicate acknowledgement. Native Share/More/Yarms taps are the manual boundary; the harness avoids the TikTok accessibility queries that previously timed out. Initial execution stopped before device changes because of a transient connection failure, followed by a locked-device preflight. Physical assisted sharing remains pending.

Two later unlocked attempts on October 6 timed out while enabling XCTest automation mode before any test case started. Both restored the clean app and settings and removed the runner without cleanup errors. These initialization failures provide no new application behavior evidence. A temporary direct-launch fallback now emits a nonce-gated aggregate report after the real isolated library refresh/import path. The host copies only that fixed diagnostic report; it checks the sample count, unexpected-record count, queue acknowledgement, store isolation, and on-device normal-library digest. It requires the marked extension rejection before valid sharing and explicit completion of each manual native TikTok share.

The signed direct-launch build passed. An initial launch-command argument error was corrected by separating app arguments with `--`; that attempt restored the clean app and settings. The subsequent physical run passed its fresh baseline: the actual isolated load/import path completed, the workout and expected-sample counts were zero, no unexpected records were present, the queue was readable and empty, and the normal-library audit was valid. It then waited 180 seconds for confirmation of the marked invalid-input alert and timed out without that confirmation. No valid provider share or duplicate check ran, no Share Sheet screenshot was captured, and no final digest comparison was established. The controller restored the clean app, removed the runner, verified unchanged appearance/VoiceOver settings, and recorded no cleanup errors. Native TikTok delivery remains unverified; the direct report and explicit manual-completion boundary are ready for a later assisted run.

On October 7, another direct run passed the same fresh baseline, but its five-minute marked-alert response window expired before confirmation. It restored the normal app and settings with no cleanup errors. The later report that the diagnostic button was absent arrived after that restoration. The temporary harness now places a short Start share test control in the first library row and permits a bounded 15-minute response window per stage, with the user prompted immediately after setup.

Rebuilding exposed 27 missing tracked files in the temporary source folder, including the project and isolation guards. The parent reconstructed the diagnostic from current public repository inputs and surviving diagnostic Swift files, explicitly restored the forced temporary library, validation-only Keychain service, strict concrete-sample save guards, and marked alert, and regenerated source membership. A read-only Apple contract review confirmed those safeguards and aggregate report path. The signed app build passed, and a fresh physical launch again confirmed an empty isolated library, readable empty queue, and valid normal-library audit. The reconstructed source, host controller, derived build, and verified signed rollback live in ignored `.build/device-validation`; they are local diagnostics and are not committed. Only `-ValidationRunNonce` is used for direct app launches; the legacy URL/text diagnostic launch flags refer to a different fixture and must not be used in this run. Native TikTok sharing remains pending until the marked gate and both actual shares complete. No production behavior changed, so the completed full suite was not repeated.

### Notes keyboard warning diagnosis

The `Invalid frame dimension (negative or non-finite).` diagnostic occurs when the Notes keyboard first appears. It was seen on iOS 26.5 and 27.0 before the motion changes; physical notes and completion tests still passed. On October 2, 2026, a temporary focused UI harness checked keyboard appearance, typing, and fresh app launches, and counted this exact warning separately from XCTest success.

| Controlled experiment | Result |
| --- | --- |
| Full workout screen, two editor-focus runs on iOS 26.5 | UI assertions passed; one frame warning |
| Same screen with only the keyboard toolbar removed | UI assertions passed; no frame warning |
| Native `NavigationStack` + `TextEditor` + keyboard toolbar, without Yarms layout or WebKit | Typing and Done dismissal passed; one frame warning |
| Minimal screen with the toolbar spacer removed | Same warning |
| Minimal screen with one `ToolbarItem` instead of `ToolbarItemGroup`, iOS 26.5 and 27.0 | Typing and Done dismissal passed; same warning on both runtimes |

This isolates a native SwiftUI keyboard-toolbar trigger without the app's player sizing, notes container, safe-area tray, or animation code. It does not establish Apple's internal cause, and no speculative player-frame fix was applied. Keep the accessible keyboard Done action. A future visible keyboard/layout regression must still be investigated even if its console warning has the same text.

The minimal view used for the final experiment is equivalent to:

```swift
struct KeyboardDiagnosticScreen: View {
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .focused($focused)
                .toolbar {
                    ToolbarItem(placement: .keyboard) {
                        Button("Done") { focused = false }
                    }
                }
        }
    }
}
```

Use a disposable app/test copy for this diagnostic; do not replace the production screen. Focus the editor, assert that the keyboard appears, type and verify text, tap Done, and assert keyboard dismissal. A clean diagnostic requires both successful UI assertions and zero matching runtime warnings; simply suppressing or ignoring the warning is not a fix.
