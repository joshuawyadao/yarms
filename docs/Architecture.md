# Architecture and verification

## Foundation milestone

The SwiftUI app and UIKit share extension both compile `YarmsCore`. They use the `group.com.joshuawyadao.yarms` App Group container. Every accepted share is written as a separate UUID JSON file in `Inbox` with an atomic write, so opening the app is not required to capture the link. The app lists these pending files and offers an explicit Paste link action. A later milestone will import them into the searchable library.

`TikTokLink` accepts HTTPS video URLs from the documented TikTok hosts and TikTok's `vm`/`vt` short-link hosts. It strips query and fragment data. Only a canonical numeric video ID builds a player URL; a short link remains saved and can be opened in TikTok until the resolver arrives. The embedded video uses TikTok's [official player URL](https://developers.tiktok.com/docs/en/embed-player) in `WKWebView`. The next milestone will use TikTok's [oEmbed endpoint](https://developers.tiktok.com/docs/en/embed-videos) for metadata. No video bytes are persisted.

`scripts/generate-project.rb` adds new Swift source files to the checked-in Xcode project using the `xcodeproj` Ruby gem. Target settings live in the Xcode project. The app icon is a 1024-pixel package of the owner's approved PNG.

## Device checks before release

Automated checks cover URL parsing, durable inbox writes, simulator build, and unit tests. On a signed iPhone build, verify that Share → Save to Yarms from TikTok and Safari writes the link before the app opens; verify the app sees it when foregrounded. Confirm canonical posts play, short links use the fallback, unavailable/private posts show a usable Open in TikTok path, and paste works with a copied TikTok URL. The live TikTok share sheet, App Group entitlement provisioning, and web playback need this device check because unit tests cannot prove their behavior.
