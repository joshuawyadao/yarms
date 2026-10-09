# Plan

Add automated Release validation and a repeatable, versioned archive command for Yarms. Validate effective Xcode settings and the produced app and Share extension, retain readable build evidence, and keep signing inputs local.

## Scope
- In: Release checks, Debug-only test storage, archive tooling, host regression tests, CI, release instructions, and commit/push of this branch.
- Out: TestFlight or App Store upload, export, account setup, phone installation, and merging the pull request.

## Action items
[ ] Restrict temporary UI-test storage controls to Debug and verify both compilation modes.
[ ] Share the existing bounded subprocess executor without changing simulator-runner behavior.
[ ] Add a Release checker for effective settings, bundle metadata, extension embedding, and compiled test markers.
[ ] Add a versioned archive command with explicit version/build inputs, signed and unsigned modes, retained logs/report, and short release notes.
[ ] Cover configuration, artifact, signing, failure, and command boundaries with meaningful host tests.
[ ] Add an unsigned Release CI job and document the commands and signing limits.
[ ] Run repository checks, relevant Debug regressions, a real Release build, and a real versioned archive.
[ ] Record actual validation and any local signing limitation, then commit and push the completed changes.

## Open questions
- None. Signed archives use the caller's local signing configuration; unsigned validation remains available without account changes.
