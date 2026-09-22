# Yarms

Yarms is an early-stage personal iPhone app idea for saving TikTok workouts and following along with them in one organized place.

> **Status:** Planning and repository setup. There is no usable app, release, or supported TikTok integration yet.

## Why this repository is public

This repository makes the product direction and future development reviewable from the start. It also establishes privacy, security, and contribution expectations before app code arrives. Plans and examples here do not imply that Yarms is affiliated with TikTok.

## Intended experience

The goal is to give a person one place to collect workouts they find on TikTok, organize them, and follow a workout without losing their place. The exact save flow, playback behavior, data model, and supported iPhone versions have not been decided.

## Privacy and security

Do not commit TikTok account data, saved workout collections, personal health information, credentials, videos, or private screenshots. Use invented examples in issues, pull requests, and future tests. Report security concerns through the private process in [SECURITY.md](SECURITY.md).

## Contributing

Issues and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md) first. The [issue forms](.github/ISSUE_TEMPLATE/) and [pull request template](.github/pull_request_template.md) ask for clear outcomes and privacy considerations.

The current repository check is:

```sh
./scripts/verify-repository.sh
```

It uses Git and Python's standard library. Application tests and build instructions will be added when application code exists.

## License

Yarms is released under the [MIT License](LICENSE). TikTok is a trademark of its respective owner; this project is independent and unaffiliated.
