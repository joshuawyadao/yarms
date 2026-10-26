# Efficiency implementation

[Documentation index](README.md) · [Architecture](Architecture.md) · [Testing](Testing.md)

The October 2026 audit identified repeated device work and CI work in a local-first app. This implementation keeps JSON/Keychain storage and official TikTok playback with no added subscription, backend or dependency.

| Audit item | Implementation |
| --- | --- |
| F01 persistence | One-read revisioned snapshots, one atomic write for both pending inbox batches, commit before acknowledgement, indexed duplicate checks and background serialized UI operations. No retained library cache; App Intent writes remain visible. |
| F02 metadata | Persist optional retry state, bounded attempts/backoff, Retry-After, quiet partial results, due retries only while active and explicit manual retry. |
| F03/F04 CI | Remove duplicate Debug build; gate expensive jobs after fast checks and skip macOS only for known Markdown-only PRs. Required names remain CI Verify and Release Verify. |
| F05 UI checks | Explicit isolated Debug metadata/player fixtures, no remote frames, CSP denying external resources; retain native VoiceOver and behavior assertions. |
| F06 evidence | Compact CI reports for 14 days, detailed failures/manual evidence for seven days, elapsed/log-size metrics and dry-run local pruning. |
| F08 notes | Maintain paragraph occurrence counts/fragments per keeper, including repeated intentional paragraphs and current-note precedence. |
| F09 restore | Reuse import normalization without JSON re-decoding; preserve sanitization, atomic merge and exact encoded-size cap for typed inputs. |
| F10 redirects | Stop HEAD traversal when a validated redirect already supplies a canonical numeric video ID. |

## Measurements and limits

An optimized host Swift harness restoring 1,000/4,000 same-video aliases with distinct notes measured 0.269s/4.231s before and 0.035s/0.097s after note accumulation. These single host samples show the algorithmic improvement; they are not iPhone battery, memory or release performance guarantees. The opt-in simulator benchmark now covers this note-heavy shape. A deterministic I/O-observer regression requires one read and one write for 100 new pending links.

F07 remains a growth follow-up: exports can exceed the defensive 10 MiB import limit and retain the existing warning. A new bounded split/streaming backup format requires compatibility design; the limit is not raised. Thumbnail downsampling, player publication throttling and a local database migration remain profile-dependent. Live Share Sheet signing, Files providers, human comfort and actual TikTok accessibility are not certified by local fixtures.

## Validation and review ledger

- Host repository verification: 54 tests passed, including a real source-to-docs Git rename regression; source renames cannot bypass macOS checks.
- Unsigned Release app/Share verification passed locally. Debug fixture controls were excluded from the inspected Release executables.
- Initial iOS 27 run passed the app tests and ordinary UI journeys through notes/relaunch, then native VoiceOver hit `kAXErrorServerNotFound` during app launch. A later launch stalled; the owned run was interrupted with its failed evidence preserved. A focused run also timed out booting iOS 27. Both runners removed their owned simulators/DerivedData with no cleanup errors. No native assertion was weakened or skipped to obtain a pass.
- The full local iOS 26.5 run passed 113 tests with zero failures, four expected skips and successful owned cleanup; native VoiceOver remains capability-gated there. All five hosted checks passed on `465d030`. Current commit readiness is recorded on [PR #16](https://github.com/joshuawyadao/yarms/pull/16). This document does not claim a passing iOS 27 accessibility run.
- Codex review completed on `490053c` without major issues. Follow-up review on `465d030` identified P2 comment 4355584117: a transient short-link HEAD failure could become a quiet partial or permanent outcome when oEmbed succeeded or rejected the URL. The fix retains both classifications, lets transient work retry within the existing caps, preserves returned metadata, and honors the later Retry-After. Controlled-network regressions cover timeout/success, server failure/404 and both delay orderings; final validation and acknowledgement are tracked on the PR.
- October 26 follow-up validation: 103 app tests passed with zero failures, three expected skips and successful cleanup on iOS 26.5; all 54 host checks passed. The focused Brooks pass found no new actionable concern in failure composition, preserved redirect boundaries or regression coverage. Final hosted full-suite and Release gates remain tracked on the PR.
- Codex's follow-up review of `9ea7ade` found no major issues and P2 comment 4355584117 received its thumbs-up acknowledgement after the fix was pushed. Hosted run 40402742467 passed repository/Release checks and 115 tests, but one maximum-text completion assertion failed immediately after Done (0.02s after tap completion). Both Done journeys now use the same five-second disappearance condition already used by swipe/VoiceOver dismissal. Production code, content/accessibility assertions and test inclusion are unchanged; focused validation and final hosted results are tracked on the PR.
- The focused feedback suite subsequently passed five tests with zero failures and one expected VoiceOver skip on iOS 26.5, including both Done journeys and preserved notes. Owned cleanup succeeded. No production change, repeat tap, test retry or new skip was added for the CI failure.
- Review of `ca4c0e2` identified P2 comment 4382833738: a fully populated pending record's early deadline could mask later eligible retries because the view and queue used different eligibility. Next-retry selection now belongs to the queue and shares its missing-detail/state policy with request selection. Fixed-date regressions cover the excluded blocker and later work; final validation, acknowledgement and current-head CI are tracked on the PR.
- The integrated app suite passed 105 tests with zero failures, three expected skips and successful owned cleanup after that scheduling fix on iOS 26.5. The superseded `ca4c0e2` CI test run was canceled to avoid unnecessary runner use; its repository/Release checks had passed. The three-request concurrency and five-attempt retry bounds remain unchanged.

### Brooks review concerns

PR review sampled the high-risk storage, retry, fixture and CI diff (over 500 changed lines); the size increases review effort, so app and CI checkpoints are separate. R1–R6 and the quick test check were considered. These concrete concerns were fixed:

| Concern | Consequence | Fix / regression |
| --- | --- | --- |
| Partial metadata marked complete; stale terminal state on coalescing | Manual recovery could remain blocked | Classify partial results and give the survivor the fresh attempt state; fixed-date and alias regression tests |
| Stale refresh still changed selection/feedback | Older results could override newer user-visible state | Reject all stale snapshot effects using monotonic revisions |
| Manual retry overlapped an active request | Earlier results could overwrite retry reset | Disable retry while requests/reset are active; add a UI retry/persistence journey |
| Colliding pending UUID treated as an existing link | A different capture could be acknowledged without saving | Reject the conflicting identity, preserve queue/library; regression test |
| Rename-aware diff hid deleted source under a docs destination | A source removal could skip expensive checks | Disable rename detection for classification; real temporary Git repo regression |

No remaining actionable local-review concern was identified after these fixes. CI/review terminal state is read freshly from the PR; the PR remains unmerged. Conditional F07/profile-dependent follow-ups above remain explicitly deferred.
