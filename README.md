# Yarms

[![Repository Verify](https://github.com/joshuawyadao/yarms/actions/workflows/ci.yml/badge.svg)](https://github.com/joshuawyadao/yarms/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Yarms is a personal iPhone app for saving TikTok workouts and following along with them in one organized place.

> **Status:** The iPhone MVP is implemented across four milestones. There is no App Store release yet; installation requires building from source.

## Why this repository is public

This repository makes the product direction and development reviewable. Plans and examples here do not imply that Yarms is affiliated with TikTok.

## Intended experience

After a one-time [Shortcut setup](docs/Shortcut-Sharing.md), share a TikTok workout to **Save to Yarms** from the iPhone share sheet, or paste its link in the app. The Shortcut runs Yarms's Save TikTok Workout action and saves the link locally without an app account or typing each time. The local library supports search by title, creator, or link. Yarms requests available title, creator, and thumbnail from TikTok's oEmbed endpoint, and attempts to resolve short links for playback. The workout screen uses TikTok's official embedded player with play, pause, short seek, and replay controls. Optional notes stay with the workout on the iPhone. If a video cannot play in the embedded player, Open in TikTok remains available. See the [MVP roadmap](docs/MVP-Roadmap.md) for the staged feature work.

The Backup menu exports a JSON copy of workout links, details, and notes to a location you choose in Files. Restoring a backup adds missing workouts, fills gaps in existing records, and appends distinct backed-up notes without erasing current notes. Import is limited to 10 MB; a larger local library can still be exported, and the app warns that this version cannot import the resulting file. Backup files include personal notes, so store them somewhere private. Yarms does not include or download video files in a backup.

## Privacy and security

Do not commit TikTok account data, saved workout collections, personal health information, credentials, videos, or private screenshots. Use invented examples in issues, pull requests, and future tests. Report security concerns through the private process in [SECURITY.md](SECURITY.md).

GitHub secret scanning, push protection, Dependabot security updates, and private vulnerability reporting are enabled for this repository.

## Contributing

Issues and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md) first. The [issue forms](.github/ISSUE_TEMPLATE/) and [pull request template](.github/pull_request_template.md) ask for clear outcomes and privacy considerations.

**Before upgrading an earlier signed Yarms build:** Export a backup from that build and keep the JSON file in Files. This free-team build uses a new app-local storage location and cannot read the old App Group library after installation. Follow the [upgrade and restore steps](docs/Storage-Migration.md) before replacing the old app.

Open `Yarms.xcodeproj` with Xcode. The app targets iOS 18 or later and can be built for a personal iPhone with a free Apple Personal Team. Select your team in Signing & Capabilities; the app has no App Group entitlement or share extension. Free Personal Team provisioning expires periodically, so Xcode may need to rebuild and reinstall the app. See [architecture and device checks](docs/Architecture.md).

The local checks are:

```sh
./scripts/verify-repository.sh
xcodebuild -project Yarms.xcodeproj -scheme Yarms -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Yarms.xcodeproj -scheme Yarms -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test
```

Choose an available iPhone simulator for the test command. CI runs repository verification, simulator build, and unit tests.

## License

Yarms is released under the [MIT License](LICENSE). TikTok is a trademark of its respective owner; this project is independent and unaffiliated.
