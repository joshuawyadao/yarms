# Contributing to Yarms

Yarms is an implemented iPhone MVP available to build from source. Issues and focused pull requests are welcome; there is no published app release yet.

## Get oriented

1. Read the [README](README.md), [documentation index](docs/README.md), and [repository map](docs/Repository-Map.md).
2. Follow [Development](docs/Development.md) to build and [Testing](docs/Testing.md) to select the appropriate checks.
3. Search existing issues and PRs. Open an issue before adding a third-party service, requesting an iPhone permission, storing new personal data, or changing how TikTok content is accessed.

## Make a change

1. Create a descriptive feature branch from current `main`. Keep each change focused on one outcome.
2. Add focused tests when executable behavior changes, using invented data. The [coverage map](docs/Testing.md) helps locate existing cases.
3. Update the relevant guides using the table below. Describe implemented behavior separately from proposals and unverified assumptions.
4. Run `./scripts/verify-repository.sh` and the checks appropriate to the change. If Swift files or target wiring change, also run the build and simulator suite described in [Testing](docs/Testing.md).
5. Commit coherent checkpoints with concrete messages. Review the staged diff and leave local signing settings, generated output, and private data out of the commits.
6. Open a PR using the [template](.github/pull_request_template.md). Report the user-visible result, privacy/security effects, checks actually run, and any limitations. Wait for **Repository Verify** and **CI Verify** and address review feedback before merging.

## Update documentation with the code

| Change | Update |
| --- | --- |
| Saving, folders, playback, notes, or backup UI | [User guide](docs/User-Guide.md); sharing guide when relevant |
| Module responsibility, capture path, or player protocol | [Architecture](docs/Architecture.md) and its diagrams |
| Stored fields, schema, restore rules, or network access | [Data and privacy](docs/Data-and-Privacy.md); [migration guide](docs/Storage-Migration.md) when upgrading needs action |
| Xcode, signing, scripts, CI, or test coverage | [Development](docs/Development.md) and [Testing](docs/Testing.md) |
| Source files or folders | [Repository map](docs/Repository-Map.md); run the project generator when adding/removing Swift files |
| Colors, icons, layout, or accessibility | [Design and assets](docs/Design-and-Assets.md) |
| New guide or major delivered feature | [Docs index](docs/README.md), README entry points, and [progress](docs/MVP-Progress.md) as appropriate |

For documentation-only changes, check relative links, heading anchors, image paths, and rendered diagrams. The repository script checks local Markdown page links, but does not validate heading anchors, images, Mermaid syntax, or remote URLs. Test files need no changes when executable behavior is unchanged.

## Public-data rules

Do not commit or attach credentials, tokens, personal workout collections, health information, downloaded videos, local databases, device logs, private configuration, or unredacted screenshots. Use synthetic examples and remove machine-specific paths. Exported backup JSON also contains private links and notes; it is not a test fixture.

Report vulnerabilities privately through [SECURITY.md](SECURITY.md), and follow the [Code of Conduct](CODE_OF_CONDUCT.md).
