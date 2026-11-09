# Plan

Prepare Yarms for a private external TestFlight beta with accessible privacy information, explicit release metadata, validated packaging, and a reproducible submission guide.

## Scope
- In: offline and public privacy policy, native privacy entry point, audited privacy manifests, export-compliance setting, project/generator resource wiring, Release packaging regressions, TestFlight instructions, validation and an unmerged PR.
- Out: uploading to Apple, accepting agreements, changing account credentials or signing identities, publishing a website, changing TikTok playback/data collection, and merging the PR.

## Action items
- [x] Inspect Development, Release, Data-and-Privacy, Testing, User-Guide, Repository-Map, project generation, Release host tests and UI isolation; branch from current origin/main.
- [ ] Add a canonical bundled `PRIVACY.md` and accessible in-app privacy sheet with an online policy link; cover offline presentation/dismissal with an isolated UI regression.
- [ ] Audit production APIs and dependencies, add accurate privacy manifests to both bundles, configure exempt-encryption metadata, and preserve these resources in the project generator.
- [ ] Extend Release artifact checks and host regressions for missing/malformed manifests, encryption metadata and missing policy so packaging omissions fail before upload.
- [ ] Write `docs/TestFlight.md` with paid-team/Keychain setup, backup-before-upgrade, Xcode archive/upload, compliance, reviewer instructions, private invitations and expiry; update canonical documentation links and behavior notes.
- [ ] Run repository verification, focused privacy UI coverage, the full simulator suite and real Release check/unsigned archive; inspect the privacy screen and packaged resources, and record signing/device limits.
- [ ] Run Brooks review, save and push the branch, open a draft PR, request Codex review and handle actionable feedback and CI until terminal readiness or a concrete blocker.

## Open questions
- None. Use the public repository's main-branch `PRIVACY.md` as the policy URL; it becomes current after merge. Account-specific contact fields and a working public sample link are supplied by the account holder at submission.

## Validation and review ledger
- Discovery: clean detached checkout at `8a87ddf`; fetched origin/main and created `codex/testflight-readiness`. Historical device evidence is not a distribution-signing check. Installed Xcode is 27.2.
- Privacy scope: native code has no third-party SDKs, analytics, advertising identifier, UserDefaults or required-reason timestamp/disk/uptime API use found. File-size reads are not file-timestamp access. Embedded TikTok content requires separate disclosure and review; an empty required-reason list does not assert anonymous web playback or replace App Store privacy answers.
