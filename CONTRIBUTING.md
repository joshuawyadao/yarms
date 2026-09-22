# Contributing to Yarms

Thanks for helping shape Yarms. This is an early-stage iPhone app project; no usable application has been published yet.

## Before proposing work

1. Read the [README](README.md) and search existing issues and pull requests.
2. Open an issue before adding a third-party service, requesting an iPhone permission, storing personal data, or choosing how TikTok content is accessed.
3. Keep each change focused on one outcome. State what works now and what remains a proposal.

## Development workflow

1. Create a descriptive branch from `main`.
2. Add focused tests when executable behavior changes; use invented data and respect any future app-specific verification guide.
3. Update the README or relevant documentation when behavior, setup, data handling, or supported environments change.
4. Run `./scripts/verify-repository.sh` and include the result in the pull request.
5. Describe the user-visible result, privacy and security implications, verification, and known limitations.

## Public-data rules

Do not commit or attach account credentials, tokens, personal workout collections, health information, downloaded videos, local databases, device logs, private configuration, or unredacted screenshots. Use synthetic examples and remove machine-specific paths. Report vulnerabilities privately through [SECURITY.md](SECURITY.md); report conduct concerns through the [Code of Conduct](CODE_OF_CONDUCT.md).
