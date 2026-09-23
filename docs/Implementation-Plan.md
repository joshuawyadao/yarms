# Plan

Make Yarms installable with a free Apple Personal Team while keeping a no-typing TikTok sharing flow. Replace the App Group share extension with a Yarms App Intent used by a one-time Shortcuts share-sheet action, store links in the app container, and validate the resulting build and capture path.

## Scope
- In: app-local inbox and library, Save TikTok Workout action for Shortcuts, clear one-time setup guidance, project and CI cleanup, tests, documentation, Personal Team build and device validation when connected.
- Out: paid Developer Program enrollment, a direct Yarms share extension, cloud sync, and TikTok video downloads.

## Action items
- [ ] Move live inbox and library storage to the app's Application Support container and preserve durable, duplicate-safe link import.
- [ ] Add a Shortcuts-visible Save TikTok Workout action that accepts shared text or a URL, rejects invalid links, and confirms a durable save.
- [ ] Remove the share extension and App Group entitlement from the Xcode project and generator, and update repository and CI checks.
- [ ] Explain the one-time share-sheet Shortcut setup in the app and update README, architecture, and roadmap documentation.
- [ ] Add focused tests for Shortcut capture and app-local persistence; run targeted and full simulator tests plus repository verification.
- [ ] Build with the Personal Team, then install and run on the physical iPhone when it is reconnected; verify the Shortcut, paste, library, player, notes, and backup flows that can be exercised.
- [ ] Commit and push reviewable checkpoints, then shepherd a PR through review and green checks before merging this follow-up milestone.

## Open questions
- None. The user chose Shortcut sharing over paste-only, and accepts the one-time Shortcut setup required by a free Personal Team.
