# MVP progress

| Milestone | State | Branch | PR | Gates / next step |
| --- | --- | --- | --- | --- |
| 1. Foundation, share, player validation | Merged into `main` at `57e84c8` | `feat/foundation-share-player` | [#1](https://github.com/joshuawyadao/yarms/pull/1) | Codex review complete with no final findings; CI Verify and Repository Verify passed |
| 2. Saving and library | Second feedback fix validated locally | `feat/saving-library-oembed` | [#2](https://github.com/joshuawyadao/yarms/pull/2) | Push fix; await fresh Codex review and both required checks, then merge |
| 3. Player and notes | Pending | — | — | Start after milestone 2 merges |
| 4. Backup and polish | Pending | — | — | Start after milestone 3 merges; verify final `main` |

The active goal remains open until every PR is reviewed, green, merged, and the final app build and relevant tests pass.

## Review ledger

- PR #1 Brooks review: a shared text payload could contain another URL before the TikTok video URL. The parser now scans all URL candidates; the regression test and five existing tests pass.
- PR #1 Codex review: the shared Xcode scheme lacked a Run/Profile executable. The generator and checked-in scheme now select the Yarms app, and repository verification checks this invariant. CI Verify passed on `20bfcef`; the addressed comment received a thumbs-up reaction.
- PR #1 Codex review: the iPhone web view did not explicitly allow inline media playback. The player now enables it, six local tests pass, and the device checklist calls for live inline-playback validation. CI Verify passed on `4300018`; the addressed comment received a thumbs-up reaction.
- PR #1 Codex review: the extension plist used fixed version strings. Both versions now inherit build settings; the built app and extension match, and repository verification checks the source plist. The final `f3f5a12` review found no further issues, both checks passed, and the PR was squash-merged.
- Milestone 2 local validation: 16 simulator tests and repository verification pass. A signed simulator app opens the empty local library with App Group access. The unsigned test build cannot access the App Group directly; store tests use temporary directories.
- PR #2 Brooks review: 100/100 with no actionable findings. The diff adds over 500 lines across 12 related files (app, tests, and docs), so review size remains a change-propagation signal to watch; generated Xcode project wiring was excluded from the assessment.
- PR #2 Codex review of `c9f7c03`: found a duplicate-row case when two saved URL forms resolve to the same video. CI Verify and Repository Verify passed on that head. The store fix and a fresh review are pending.
- PR #2 feedback fix: resolved workouts with the same video ID now coalesce into the earliest saved record, retaining available metadata. Two new regression cases pass; the local simulator suite is 18/18.
- PR #2 Codex re-review of `86c9f07`: found that an in-flight metadata result for a removed duplicate ID can be dropped. Both required CI checks passed on this head. The late-result fix and fresh review are pending. An earlier re-review attempt failed with a Git ref lookup error and was retried; the successful review found this issue.
- PR #2 second feedback fix: late enrichment now locates the surviving workout by resolved video ID when its original record ID was coalesced away. The regression test passes; local simulator tests are 19/19.
