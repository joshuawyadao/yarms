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

Implementation validation and PR review are in progress. Final results are recorded here before branch completion.
