# Plan

Add automated Release validation and a repeatable, versioned archive command for Yarms. Validate effective Xcode settings and the produced app and Share extension, retain readable build evidence, and keep signing inputs local.

## Scope
- In: Release checks, Debug-only test storage, archive tooling, host regression tests, CI, release instructions, and commit/push of this branch.
- Out: TestFlight or App Store upload, export, account setup, phone installation, and merging the pull request.

## Action items
- [x] Restrict temporary UI-test storage controls to Debug and verify both compilation modes.
- [x] Share the existing bounded subprocess executor without changing simulator-runner behavior.
- [x] Add a Release checker for effective settings, bundle metadata, extension embedding, and compiled test markers.
- [x] Add a versioned archive command with explicit version/build inputs, signed and unsigned modes, retained logs/report, and short release notes.
- [x] Cover configuration, artifact, signing, failure, and command boundaries with meaningful host tests.
- [x] Add an unsigned Release CI job and document the commands and signing limits.
- [x] Run repository checks, relevant Debug regressions, a real Release build, and a real versioned archive.
- [x] Record actual validation and checkpoint the completed implementation.
- [ ] Push the completed changes to the current branch.

## Open questions
- None. Signed archives use the caller's local signing configuration; unsigned validation remains available without account changes.

## Validation

- Repository verification: 40 host tests passed.
- Debug storage and reduced-motion Paste smoke on a disposable iOS 27 simulator: 8 passed, successful cleanup.
- Unsigned Release simulator build and app/Share artifact checks: passed.
- Signed and unsigned version 1.0.0/build 2 archives from clean commit `d680d02`: passed; signed teams/default shared Keychain group verified; archives retained and DerivedData removed.
- Apple-platform correctness review: no remaining blocking issues.
- Distribution readiness, upload, and phone installation remain outside this task.
