# Yarms

[![Repository Verify](https://github.com/joshuawyadao/yarms/actions/workflows/ci.yml/badge.svg)](https://github.com/joshuawyadao/yarms/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Yarms is a personal iPhone app for saving TikTok workouts and following along with them in one organized place.

> **Status:** The foundation and local library milestones are merged. The workout player and notes milestone is in progress; no release is available yet.

## Why this repository is public

This repository makes the product direction and development reviewable. Plans and examples here do not imply that Yarms is affiliated with TikTok.

## Intended experience

Share a TikTok workout to Yarms, or paste its link in the app. Yarms saves the link locally without an account or required typing. The local library supports search by title, creator, or link. Yarms requests available title, creator, and thumbnail from TikTok's oEmbed endpoint, and attempts to resolve short links for playback. The workout screen uses TikTok's official embedded player with play, pause, short seek, and replay controls. Optional notes stay with the workout on the iPhone. If a video cannot play in the embedded player, Open in TikTok remains available. See the [MVP roadmap](docs/MVP-Roadmap.md) for the staged feature work.

## Privacy and security

Do not commit TikTok account data, saved workout collections, personal health information, credentials, videos, or private screenshots. Use invented examples in issues, pull requests, and future tests. Report security concerns through the private process in [SECURITY.md](SECURITY.md).

GitHub secret scanning, push protection, Dependabot security updates, and private vulnerability reporting are enabled for this repository.

## Contributing

Issues and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md) first. The [issue forms](.github/ISSUE_TEMPLATE/) and [pull request template](.github/pull_request_template.md) ask for clear outcomes and privacy considerations.

Open `Yarms.xcodeproj` with Xcode. The app targets iOS 18 or later. A developer team with the `group.com.joshuawyadao.yarms` App Group is needed for a signed device build; the CI simulator build disables code signing. See [architecture and device checks](docs/Architecture.md).

The local checks are:

```sh
./scripts/verify-repository.sh
xcodebuild -project Yarms.xcodeproj -scheme Yarms -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Yarms.xcodeproj -scheme Yarms -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test
```

Choose an available iPhone simulator for the test command. CI runs repository verification, simulator build, and unit tests.

## License

Yarms is released under the [MIT License](LICENSE). TikTok is a trademark of its respective owner; this project is independent and unaffiliated.
