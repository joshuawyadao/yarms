# Plan

Make Yarms installable with a free Apple Personal Team while keeping a no-typing TikTok sharing flow. Replace the App Group share extension with a Yarms App Intent used by a one-time Shortcuts share-sheet action, store links in the app container, and validate the resulting build and capture path.

## Scope
- In: app-local inbox and library, Save TikTok Workout action for Shortcuts, clear one-time setup guidance, project and CI cleanup, tests, documentation, Personal Team build and device validation when connected.
- Out: paid Developer Program enrollment, a direct Yarms share extension, cloud sync, and TikTok video downloads.

## Action items
- [x] Move live inbox and library storage to the app's Application Support container and preserve durable, duplicate-safe link import.
- [x] Add a Shortcuts-visible Save TikTok Workout action that accepts shared text or a URL, rejects invalid links, and confirms a durable save.
- [x] Remove the share extension and App Group entitlement from the Xcode project and generator, and update repository and CI checks.
- [x] Explain the one-time share-sheet Shortcut setup in the app and update README, architecture, and roadmap documentation.
- [x] Add focused tests for Shortcut capture and app-local persistence; run targeted and full simulator tests plus repository verification.
- [x] Build with the Personal Team and verify its signed app metadata and entitlements.
- [x] Document a pre-upgrade backup and restore path for any earlier App Group build, since the free-team app cannot read that container after upgrading.
- [ ] Commit and push the implemented changes, then open a PR and clear Codex review, Brooks review, and CI checks.
- [ ] Install and run on the physical iPhone when it is reconnected; verify the Shortcut, paste, library, player, notes, and backup flows that can be exercised.
- [ ] Merge the reviewed PR after all checks pass and confirm the final `main` build and tests.

## Open questions
- None. The user chose Shortcut sharing over paste-only, and accepts the one-time Shortcut setup required by a free Personal Team.
