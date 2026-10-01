# Repository map

Use this map to find an owner before editing. The [README](../README.md) is the entry point; [Architecture](Architecture.md) explains data flow and storage, [Data and Privacy](Data-and-Privacy.md) explains stored data, [Design Language](Design-Language.md) defines UI decisions, [Design and Assets](Design-and-Assets.md) maps those decisions to assets, [User Guide](User-Guide.md) covers app tasks, and [Development](Development.md) and [Testing](Testing.md) cover contributor work. This page identifies files rather than repeating those guides.

## Application and shared code

| File | Responsibility |
| --- | --- |
| [YarmsApp.swift](../YarmsApp/YarmsApp.swift) | SwiftUI app entry point and root library window. |
| [YarmsTheme.swift](../YarmsApp/YarmsTheme.swift) | Shared semantic color roles, spacing, radii, size limits, and action button styles. |
| [YarmsUIComponents.swift](../YarmsApp/YarmsUIComponents.swift) | Folder badge/filter, workout card content, empty state, and component previews. |
| [LibraryShellView.swift](../YarmsApp/LibraryShellView.swift) | Library and folder screens; paste, search, row deletion, and backup presentation. |
| [EmbeddedPlayerView.swift](../YarmsApp/EmbeddedPlayerView.swift) | Workout screen, portrait embedded player and controls, notes editor, and workout deletion. |
| [TikTokPlayerBridge.swift](../YarmsApp/TikTokPlayerBridge.swift) | WebKit host, player messages, commands, and playback state. |
| [TikTokMetadataClient.swift](../YarmsApp/TikTokMetadataClient.swift) | TikTok metadata request and short-link resolution. |
| [WorkoutEnrichmentQueue.swift](../YarmsApp/WorkoutEnrichmentQueue.swift) | Limits concurrent metadata enrichment work. |
| [Workout.swift](../YarmsApp/Workout.swift) | Workout and folder record shapes, including workout text matching for search. |
| [WorkoutStore.swift](../YarmsApp/WorkoutStore.swift) | Local library persistence, inbox import, folders, notes, deduplication, and restore application. |
| [WorkoutBackup.swift](../YarmsApp/WorkoutBackup.swift) | Backup format, validation, and restore result. |
| [WorkoutBackupDocument.swift](../YarmsApp/WorkoutBackupDocument.swift) | Files document wrapper used for export; import UI loads through `WorkoutBackup.load`. |
| [SaveTikTokWorkoutIntent.swift](../YarmsApp/SaveTikTokWorkoutIntent.swift) | Optional App Intent/Shortcut capture path. |
| [TikTokLink.swift](../YarmsCore/TikTokLink.swift) | TikTok link recognition, validation, and canonical player URL. |
| [SharedInbox.swift](../YarmsCore/SharedInbox.swift) | File-based pending links and isolated UI-test storage selection. |
| [KeychainInbox.swift](../YarmsCore/KeychainInbox.swift) | Pending links in the app/extension shared Keychain access group. |
| [ShareViewController.swift](../YarmsShare/ShareViewController.swift) | Share Sheet input loading, link validation, Keychain save, and user feedback. |

`YarmsCore` Swift files compile into both the app and Share extension. The Share extension is embedded in the app, and the unit tests load the app module. Target wiring lives in the Xcode project.

## Tests

The [test guide](Testing.md#what-the-tests-cover) explains coverage and commands. These files are organized by the behavior they exercise:

| File | Area |
| --- | --- |
| [FoundationTests.swift](../YarmsTests/FoundationTests.swift) | Links, file inbox, UI-test storage. |
| [ShortcutCaptureTests.swift](../YarmsTests/ShortcutCaptureTests.swift) | Shared text and pending-link import. |
| [KeychainInboxTests.swift](../YarmsTests/KeychainInboxTests.swift) | Signed-device Keychain access. |
| [LibraryTests.swift](../YarmsTests/LibraryTests.swift) | Store, folders, search, notes, deletion. |
| [MetadataTests.swift](../YarmsTests/MetadataTests.swift) | oEmbed and redirect behavior. |
| [PlayerBridgeTests.swift](../YarmsTests/PlayerBridgeTests.swift) | WebKit/player command behavior. |
| [WorkoutEnrichmentQueueTests.swift](../YarmsTests/WorkoutEnrichmentQueueTests.swift) | Enrichment scheduling. |
| [BackupTests.swift](../YarmsTests/BackupTests.swift) | Backup validation and restore. |
| [BackupImportSecurityTests.swift](../YarmsTests/BackupImportSecurityTests.swift) | Imported-claim trust boundaries. |
| [BackupExportSizeTests.swift](../YarmsTests/BackupExportSizeTests.swift) | Large-library export. |
| [BackupScalingBenchmarkTests.swift](../YarmsTests/BackupScalingBenchmarkTests.swift) | Opt-in restore scaling. |
| [YarmsUITests.swift](../YarmsUITests/YarmsUITests.swift) | Twelve simulator user flows, including completion-modal presentation/dismissal, save/error feedback with reduced motion, note persistence, accessibility-size folder selection, and Paste access. |

## Project, resources, and automation

| Path | Responsibility |
| --- | --- |
| [project.pbxproj](../Yarms.xcodeproj/project.pbxproj) and [Yarms.xcscheme](../Yarms.xcodeproj/xcshareddata/xcschemes/Yarms.xcscheme) | Checked-in target settings, resources, dependencies, launch/test configuration. |
| [YarmsApp/Yarms.entitlements](../YarmsApp/Yarms.entitlements) and [YarmsShare/Yarms.entitlements](../YarmsShare/Yarms.entitlements) | Shared Keychain access group for app and extension. |
| [YarmsShare/Info.plist](../YarmsShare/Info.plist) | Share extension identity, activation for URL/text input, and version settings. |
| [Assets/Assets.xcassets](../Assets/Assets.xcassets/) | App icon PNG and asset catalog metadata; `AccentColor`, `YarmsAction`, `YarmsBloom`, `YarmsCanvas`, `YarmsSoft`, and `YarmsSurface` color sets. See [Design and Assets](Design-and-Assets.md). |
| [generate-project.rb](../scripts/generate-project.rb) | Optional Ruby `xcodeproj` updater for Swift source membership and scheme; also has new-project bootstrap logic. |
| [verify-repository.sh](../scripts/verify-repository.sh) | Public-file, scheme, signing-config, link, privacy-file, and whitespace checks. |
| [ci.yml](../.github/workflows/ci.yml) | GitHub Actions repository verification, simulator build, and unit/UI test jobs. |
| [.gitignore](../.gitignore) | Excludes local credentials, build products, personal data, and editor files. |
| [.brooks-lint-history.json](../.brooks-lint-history.json) | Checked-in history for the repository's Brooks lint tooling. |

## Documentation and community files

| Path | Purpose |
| --- | --- |
| [README.md](../README.md) | Product overview and navigation. |
| [docs/README.md](README.md) | Task-oriented documentation index. |
| [CONTRIBUTING.md](../CONTRIBUTING.md), [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md), [SECURITY.md](../SECURITY.md), [LICENSE](../LICENSE) | Contribution process, community rules, private vulnerability reporting, and MIT license. |
| [.github/ISSUE_TEMPLATE/](../.github/ISSUE_TEMPLATE/) and [pull_request_template.md](../.github/pull_request_template.md) | Bug/feature forms, issue-template config, and PR reporting prompts. |
| [Architecture.md](Architecture.md), [Data-and-Privacy.md](Data-and-Privacy.md), [Design-Language.md](Design-Language.md), [Design-and-Assets.md](Design-and-Assets.md), [User-Guide.md](User-Guide.md) | Current system, data, UI design rules, assets, and user task references. |
| [Development.md](Development.md), [Testing.md](Testing.md), [Repository-Map.md](Repository-Map.md) | Setup, verification, and this file index. |
| [Shortcut-Sharing.md](Shortcut-Sharing.md), [Storage-Migration.md](Storage-Migration.md) | Share Sheet behavior and upgrade/backup steps. |
| [MVP-Roadmap.md](MVP-Roadmap.md), [MVP-Progress.md](MVP-Progress.md), [Implementation-Plan.md](Implementation-Plan.md) | Milestone history and current implementation plan. |

## Where to make a change

| If you are changing… | Start with… | Then check… |
| --- | --- | --- |
| Library rows, folders, search controls, or backup UI | `LibraryShellView.swift` | `Workout.swift`, `WorkoutStore.swift`, `YarmsUITests.swift` |
| Workout screen, notes editor, or player layout | `EmbeddedPlayerView.swift` | `WorkoutStore.swift`, `YarmsUITests.swift` |
| Saved data, migration, deduplication, or restore | `WorkoutStore.swift`, `Workout.swift`, `WorkoutBackup.swift` | `LibraryTests.swift`, `BackupTests.swift`, [Data and Privacy](Data-and-Privacy.md) |
| Share Sheet input or pending delivery | `ShareViewController.swift`, `KeychainInbox.swift` | Both entitlements, `ShortcutCaptureTests.swift`, signed-device checks |
| Link acceptance or metadata | `TikTokLink.swift`, `TikTokMetadataClient.swift` | `FoundationTests.swift`, `MetadataTests.swift` |
| Inline playback | `EmbeddedPlayerView.swift`, `TikTokPlayerBridge.swift` | `PlayerBridgeTests.swift`, device playback checks |
| Visual colors, components, or icon | `YarmsTheme.swift`, `YarmsUIComponents.swift`, `Assets.xcassets` | [Design Language](Design-Language.md), [Design and Assets](Design-and-Assets.md), simulator light/dark/high-contrast checks |
| Build settings, scheme, or CI | `project.pbxproj`, `Yarms.xcscheme`, `ci.yml` | `generate-project.rb`, `verify-repository.sh`, [Development](Development.md) |
