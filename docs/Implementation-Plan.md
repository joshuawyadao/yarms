# Plan

Make TikTok Share → Save to Yarms work directly after installation, with no Shortcut creation. Restore a Share extension that uses a small shared Keychain queue for links, while the app keeps its workout library and notes in its own container; a Personal Team signing spike confirmed both targets can carry the same Keychain group.

## Scope
- In: direct Share Sheet target for TikTok URL or text, durable Keychain handoff, import into the app-local library, optional compatibility with existing Shortcut captures, focused tests, updated setup and architecture docs, signed-device validation, and PR review.
- Out: App Groups, app accounts, TikTok downloads, cloud storage, and automatic installation on another person's phone.

## Action items
- [ ] Add a bounded Keychain pending-link store with one shared access group and safe save, load, and remove behavior; keep the existing file inbox for current captures.
- [ ] Restore a Share extension that accepts TikTok URL or text and reports success only after the Keychain write succeeds.
- [ ] Import pending links from both stores into the local library without duplicates or data loss after an interrupted import.
- [ ] Replace the Shortcut-first onboarding with direct Share Sheet guidance in the app, README, architecture, roadmap, and device checklist; keep optional Shortcuts compatibility clear.
- [ ] Add focused tests for Keychain handoff, invalid input, and dual-inbox import; run repository verification, the full simulator suite, and a Personal Team signed iPhone build and tests.
- [ ] Install on the iPhone and verify direct TikTok sharing, library, player, notes, paste, and backup with user-assisted taps.
- [ ] Push the branch, re-run Codex and Brooks reviews and required CI checks on the new head, resolve actionable feedback, then merge only after the live flow passes.

## Open questions
- None. The user prefers direct Share Sheet capture; the Personal Team signing spike succeeded with a shared Keychain entitlement.
