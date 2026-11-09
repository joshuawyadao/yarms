# Plan

Prepare Yarms for a private external TestFlight beta with accessible privacy information, explicit release metadata, validated packaging, and a reproducible submission guide.

## Scope
- In: offline and public privacy policy, native privacy entry point, audited privacy manifests, export-compliance setting, project/generator resource wiring, Release packaging regressions, TestFlight instructions, validation and an unmerged PR.
- Out: uploading to Apple, accepting agreements, changing account credentials or signing identities, publishing a website, changing TikTok playback/data collection, and merging the PR.

## Action items
- [x] Inspect Development, Release, Data-and-Privacy, Testing, User-Guide, Repository-Map, project generation, Release host tests and UI isolation; branch from current origin/main.
- [x] Add a canonical bundled `PRIVACY.md` and accessible in-app privacy sheet with an online policy link; cover offline presentation/dismissal with an isolated UI regression.
- [x] Audit production APIs and dependencies, add accurate privacy manifests to both bundles, configure exempt-encryption metadata, and preserve these resources in the project generator.
- [x] Extend Release artifact checks and host regressions for missing/malformed manifests, encryption metadata and missing policy so packaging omissions fail before upload.
- [x] Write `docs/TestFlight.md` with paid-team/Keychain setup, backup-before-upgrade, Xcode archive/upload, compliance, reviewer instructions, private invitations and expiry; update canonical documentation links and behavior notes.
- [x] Run repository verification, focused privacy UI coverage, the full simulator suite and real Release check/unsigned archive; inspect the privacy screen and packaged resources, and record signing/device limits.
- [ ] Run Brooks review, save and push the branch, open a draft PR, request Codex review and handle actionable feedback and CI until terminal readiness or a concrete blocker.

## Open questions
- None. Use the public repository's main-branch `PRIVACY.md` as the policy URL; it becomes current after merge. Account-specific contact fields and a working public sample link are supplied by the account holder at submission.

## Validation and review ledger
- Discovery: clean detached checkout at `8a87ddf`; fetched origin/main and created `codex/testflight-readiness`. Historical device evidence is not a distribution-signing check. Installed Xcode is 27.2.
- Privacy scope: native code has no third-party SDKs, analytics, advertising identifier, UserDefaults or required-reason timestamp/disk/uptime API use found. File-size reads are not file-timestamp access. Embedded TikTok content requires separate disclosure and review; an empty required-reason list does not assert anonymous web playback or replace App Store privacy answers.
- Initial checks: 23 Release host tests and all 56 repository host checks passed. A real Xcode 27.2 Release simulator check passed with bundled policy/manifests and Boolean encryption metadata. Full simulator suite and unsigned device archive are running. The first sandboxed Xcode invocation could not read extension settings; rerunning with Xcode system access passed.
- Device archive: Xcode 27.2 produced an unsigned version 1.0.0/build 2 archive with matching targets and privacy resources; signing/distribution acceptance remains unchecked. The first simulator run failed during CoreSimulator catalog access before tests or simulator creation; an independent device inventory found no owned simulator left behind. A fresh iOS 27 attempt then stopped before XCTest because the simulator returned to Shutdown; cleanup succeeded. The full suite is now being attempted on installed iOS 26.5.

## Brooks-Lint Review

**Mode:** PR Review
**Scope:** Feature changes vs origin/main; 21 related files, sampled above 300 lines with UI, packaging, generator and tests prioritized. Generated Xcode project wiring skipped for design findings and checked by actual builds. Default configuration, all six risks enabled; no .brooks-lint.yaml present.
**Health Score:** 100/100
**Trend:** Stable at 100.

The scoped change preserves one canonical policy and keeps signing/account actions outside the app.

### Findings

No actionable findings from R1–R6 or the Quick Test Check. Resource duplication across executable bundles is required packaging, not duplicated policy ownership. The new UI regression exercises bundled disclosure/dismissal; host tests reject missing, malformed and drifted assets and invalid encryption values without mocking those checks.

### Summary

- No Brooks remediation required.
- Actual Release build and unsigned archive verify generated resource wiring; simulator UI verification is pending.
- Apple signing, service-terms/privacy answers and real TestFlight device acceptance remain explicit submission steps.

- Local privacy regression initially failed because the new test configured `isolatedApp()` without launching it; existing helpers launch during Paste. Added the missing `app.launch()` without weakening assertions. Other observed UI flows passed; final suite verification follows the fix.
- Corrected privacy regression passed on a fresh iPhone 17 Pro/iOS 26.5 (one passed, zero failed/skipped), with successful simulator/DerivedData cleanup. Exported and visually inspected its synthetic policy screenshot: readable layout, clear title and reachable Done. The earlier full run completed with 119 passed, one failure (the now-fixed missing launch), and four expected skips; final full coverage is delegated to CI on the corrected head, not claimed as a clean local full-suite pass.
- GitHub: pushed plan `944c53b`, implementation `8aba98c`, and review checkpoint `3b83cb3`; opened draft PR #18. Codex review completed on `3b83cb3` with no findings, and no inline comments. First-run Repository Verify, Release build and Release Verify passed; full CI tests were still running at this checkpoint. The final head's current review/check/mergeability state is reported on the PR and in the completion response, without merging.
- Follow-up Brooks pass: the test launch correction adds no production behavior, weakens no assertion and has focused passing UI evidence; no actionable maintainability finding. All 56 host checks passed again. No files intentionally excluded beyond ignored local build/test evidence.
