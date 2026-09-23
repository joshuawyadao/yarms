# Architecture and verification

## Foundation and local library

The SwiftUI app and UIKit share extension both compile `YarmsCore`. They use the `group.com.joshuawyadao.yarms` App Group container. Every accepted share is written as a separate UUID JSON file in `Inbox` with an atomic write, so opening the app is not required to capture the link. The Paste link action uses the same inbox path. On app launch or foreground, `WorkoutStore` imports pending files into versioned `Library.json` in the App Group container. It writes the library atomically before deleting each pending file. Replaying a pending file after a crash does not create a duplicate. If the library cannot be decoded, pending links remain in the inbox for recovery rather than being discarded.

`TikTokLink` scans shared text for an HTTPS TikTok URL, including when another URL appears first. It accepts video URLs from the documented TikTok hosts and TikTok's `vm`/`vt` short-link hosts, then strips query and fragment data. Only a canonical numeric video ID builds a player URL. The app tries to resolve short links with bounded HEAD redirects, checking each redirect against the accepted TikTok URL set before following it. If resolution fails, the original link remains saved and Open in TikTok stays available. When multiple saved URLs resolve to the same video ID, the library keeps the earliest save and fills in its missing metadata. Metadata that returns after a duplicate record was removed is applied to the surviving record by video ID. The app requests title, creator, and thumbnail through TikTok's [oEmbed endpoint](https://developers.tiktok.com/docs/en/embed-videos). Metadata or network failure does not remove the workout. Search reads the on-device library. The embedded video uses TikTok's [official player URL](https://developers.tiktok.com/docs/en/embed-player) in `WKWebView`. No video bytes are persisted.

`scripts/generate-project.rb` adds new Swift source files to the checked-in Xcode project using the `xcodeproj` Ruby gem. Target settings live in the Xcode project. The app icon is a 1024-pixel package of the owner's approved PNG. The signed simulator build can open the App Group container; a build made with `CODE_SIGNING_ALLOWED=NO` cannot, so CI's unsigned tests validate the store with temporary directories rather than a live App Group container.

## Workout screen

The workout screen places TikTok's official iframe player first and keeps an explicit Open in TikTok action nearby. A local HTML host relays TikTok's documented [player messages](https://developers.tiktok.com/docs/en/embed-player) through a WebKit message handler. It accepts player events only from TikTok's HTTPS origin and the host's main frame, and tolerates duration arriving in either the ready or current-time event. It exposes play, pause, ten-second seek, and replay controls. TikTok's own player controls remain enabled. An unavailable post still offers the external fallback. Optional notes are stored in the same on-device workout record; the notes editor uses an explicit Save action and opens automatically when a note exists.

## User-owned backup

The library exports a versioned JSON backup through the system Files exporter. It contains workout IDs, TikTok links, available metadata, save times, and optional notes, but no video bytes or account credentials. The user chooses the backup file's location. Import is capped at 10 MB to bound untrusted file reads, while export retains every local record even if the file exceeds that cap; the exporter warns when this version cannot restore its own large file. Import validates the version and all TikTok links, normalizes blank optional text, then asks for confirmation. It discards imported thumbnail URLs, short-link resolutions, and source-alias claims: those values are refreshed through TikTok instead of being trusted from a selected file. Restore adds missing workouts and fills empty details in matching records; it retains current notes, appends distinct imported notes in save order, and coalesces records that are locally confirmed to resolve to the same video. Confirmed source aliases are persisted so later shares and restores still match the surviving record. Indexed matching keeps large valid imports responsive, and metadata refresh runs at most three requests at a time. Re-importing the same file does not create duplicates. Backup data is unencrypted, so the app tells the user to keep exported files private.

## Device checks before release

Automated checks cover URL parsing, durable inbox writes and imports, metadata response handling, bounded redirects, player-message parsing, note persistence, backup validation and merge behavior, simulator build, and unit tests. On a signed iPhone build, verify that Share → Save to Yarms from TikTok and Safari writes the link before the app opens; verify the app sees it when foregrounded. Confirm canonical posts play inline in the workout screen, the custom play/pause/seek/replay buttons control the official player, short links resolve when TikTok permits, unavailable/private posts show a usable Open in TikTok path, metadata and thumbnail load on network, notes survive app relaunch, and paste works with a copied TikTok URL. Export a backup to Files, import it on a second installation, and verify links, notes, and duplicate handling. The live TikTok share sheet, App Group entitlement provisioning, oEmbed availability, redirect behavior, web playback, and Files interaction need this device check because unit tests cannot prove their behavior.

## Restore scaling benchmark

`BackupScalingBenchmarkTests` measures a fresh restore of 1,000 and 4,000 distinct TikTok URLs that refer to one video. It prepares archives before timing, takes five samples per size, and compares medians. The 4,000-link median must stay below 10 times the 1,000-link median; the generous ratio detects a major scaling regression while tolerating normal simulator timing variation. The benchmark is skipped in the regular test suite and CI Verify. Run it after changing backup validation or merge logic with an available iPhone simulator:

```sh
TEST_RUNNER_YARMS_RUN_BACKUP_BENCHMARK=1 xcodebuild \
  -project Yarms.xcodeproj -scheme Yarms \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  '-only-testing:YarmsTests/BackupScalingBenchmarkTests' \
  CODE_SIGNING_ALLOWED=NO test
```
