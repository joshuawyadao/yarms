# Plan

Finish the review of the Release tooling and close the remaining phone-test evidence gaps. Fix the discovered entitlements-validation gap, preserve isolated test storage and a verified clean rollback, and keep human observations distinct from automated assertions.

## Scope
- In: Release entitlements gate and regression tests, review feedback and CI, canonical verification docs, existing isolated phone diagnostics, and brief assisted phone checks.
- Out: PR merging under the review-cycle skill, TestFlight/App Store upload, personal-library exports, and captures outside the already approved Share Sheet scope.

## Action items
- [x] Inspect current PR checks, relevant Release/Testing docs, and the retained phone-test controllers.
- [x] Validate each target's effective entitlement file and shared Keychain declaration in Release checks.
- [x] Add fail-closed regression cases for missing, redirected, malformed, and mismatched entitlements.
- [x] Run repository/host checks and a real unsigned Release build; update docs/Release.md and review notes.
- [x] Verify phone availability, signed candidate and clean rollback profiles, isolation, and bounded cleanup before installation.
- [ ] Build a fresh UUID-isolated diagnostic library and Keychain service, guard against symlinks, and require a nonce-fresh empty library/folder/queue baseline without overwriting old test storage.
- [ ] Complete two real native TikTok shares through the existing controller and record queue, duplicate, and library-audit results.
- [ ] Check fallback reachability and collect human VoiceOver/motion observations on the phone, retaining explicit evidence limits.
- [ ] Save and push each review fix, acknowledge Codex findings if present, and wait for final review/CI/mergeability gates.
- [ ] Update docs/Testing.md with actual outcomes and leave PR #15 unmerged with current readiness reported.

## Open questions
- None for implementation. Phone checks require a reachable unlocked device and brief user feedback; independent review work continues while waiting.
