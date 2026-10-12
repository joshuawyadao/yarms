# Plan

Finish the review of the Release tooling and close the remaining phone-test evidence gaps, then add the user-requested gentle heart loop to the completion sheet. Fix the discovered entitlements-validation gap, preserve isolated test storage and a verified clean rollback, and keep human observations distinct from automated assertions.

## Scope
- In: Release entitlements gate and regression tests, review feedback and CI, canonical verification docs, existing isolated phone diagnostics, brief assisted phone checks, and a completion-art loop limited to the visible foreground sheet.
- Out: PR merging under the review-cycle skill, TestFlight/App Store upload, personal-library exports, the human VoiceOver check declined by the user, and captures outside the already approved Share Sheet scope.

## Action items
- [x] Inspect current PR checks, relevant Release/Testing docs, and the retained phone-test controllers.
- [x] Validate each target's effective entitlement file and shared Keychain declaration in Release checks.
- [x] Add fail-closed regression cases for missing, redirected, malformed, and mismatched entitlements.
- [x] Run repository/host checks and a real unsigned Release build; update docs/Release.md and review notes.
- [x] Verify phone availability, signed candidate and clean rollback profiles, isolation, and bounded cleanup before installation.
- [x] Build a fresh UUID-isolated diagnostic library and Keychain service, guard against symlinks, and require a nonce-fresh empty library/folder/queue baseline without overwriting old test storage.
- [x] Complete two real native TikTok shares through the existing controller and record queue, duplicate, and library-audit results.
- [x] Finish the deterministic fallback check; record the user’s positive motion feedback and explicit VoiceOver-check skip. The final human reply arrived after the controller's bounded timeout and clean rollback; no post-observation audit is claimed.
- [x] Add a gentle heart loop to YarmsUIComponents.swift, keeping the entrance, static reduced-motion art and immediate dismissal, with no animation when backgrounded.
- [x] Update docs/Design-Language.md, docs/Design-and-Assets.md and docs/Testing.md for the requested motion contract and actual phone outcomes.
- [x] Repair the CI local-WebKit fixture’s observed five-second cold-start timeout with a bounded readiness wait and fail-fast setup, preserving playback assertions.
- [x] Run the existing completion/dismissal, maximum-text reduced-motion and native-focus simulator regressions plus Release/host checks; review the loop’s lifecycle and accessibility. Thirteen focused behavior tests, 42 host tests and unsigned Release passed. The first native-focus attempt failed on an automation command before completion opened; no speech/focus assertion was weakened.
- [ ] Save and push each review fix, acknowledge Codex findings if present, and wait for final review/CI/mergeability gates.
- [ ] Update docs/Testing.md with actual outcomes and leave PR #15 unmerged with current readiness reported.

## Open questions
- None for implementation. Phone checks require a reachable unlocked device and brief user feedback; independent review work continues while waiting.
