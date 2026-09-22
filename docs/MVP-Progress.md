# MVP progress

| Milestone | State | Branch | PR | Gates / next step |
| --- | --- | --- | --- | --- |
| 1. Foundation, share, player validation | Merged into `main` at `57e84c8` | `feat/foundation-share-player` | [#1](https://github.com/joshuawyadao/yarms/pull/1) | Codex review complete with no final findings; CI Verify and Repository Verify passed |
| 2. Saving and library | Local validation passed | `feat/saving-library-oembed` | Pending | Commit and push, then PR review and CI |
| 3. Player and notes | Pending | — | — | Start after milestone 2 merges |
| 4. Backup and polish | Pending | — | — | Start after milestone 3 merges; verify final `main` |

The active goal remains open until every PR is reviewed, green, merged, and the final app build and relevant tests pass.

## Review ledger

- PR #1 Brooks review: a shared text payload could contain another URL before the TikTok video URL. The parser now scans all URL candidates; the regression test and five existing tests pass.
- PR #1 Codex review: the shared Xcode scheme lacked a Run/Profile executable. The generator and checked-in scheme now select the Yarms app, and repository verification checks this invariant. CI Verify passed on `20bfcef`; the addressed comment received a thumbs-up reaction.
- PR #1 Codex review: the iPhone web view did not explicitly allow inline media playback. The player now enables it, six local tests pass, and the device checklist calls for live inline-playback validation. CI Verify passed on `4300018`; the addressed comment received a thumbs-up reaction.
- PR #1 Codex review: the extension plist used fixed version strings. Both versions now inherit build settings; the built app and extension match, and repository verification checks the source plist. The final `f3f5a12` review found no further issues, both checks passed, and the PR was squash-merged.
- Milestone 2 local validation: 16 simulator tests and repository verification pass. A signed simulator app opens the empty local library with App Group access. The unsigned test build cannot access the App Group directly; store tests use temporary directories.
