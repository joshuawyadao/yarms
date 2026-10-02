# Plan

Close the remaining Yarms device-validation gaps with reproducible evidence. Diagnose the Notes keyboard warning before changing layout, fix confirmed defects, and verify accessibility, playback, sharing, and backup flows while preserving the personal library and restoring device settings.

## Scope
- In: keyboard-warning diagnosis and confirmed fixes; native Reduce Motion and VoiceOver checks; live TikTok playback and completion pause; Share Sheet import; synthetic backup export/restore; focused regressions and testing documentation; saving to codex/gentle-app-motion.
- Out: new product features, unrelated refactors, changing personal workouts, publishing or merging a PR, treating automated audits or mocked playback as proof of live device behavior.

## Action items
- [x] Review the current app, test isolation, device-test results, and Architecture.md, Data-and-Privacy.md, Repository-Map.md, Development.md, and Testing.md.
- [x] Commit the resolved plan and record the initial phone settings. A new personal-library safety copy awaits explicit approval; continue independent work with synthetic data.
- [x] Build a repeatable Notes-focus warning check, minimize the trigger, and distinguish app layout from framework behavior with controlled experiments. A minimal native toolbar reproduces the warning on iOS 26.5 and 27.0; no speculative app-layout change is warranted.
- [ ] Fix confirmed app defects and add regressions at the relevant UI or integration boundary; preserve existing assertions and remove diagnostic instrumentation. The iOS 27 VoiceOver regression reproduced focus returning to Back after modal dismissal; a VoiceOver-scoped binding now restores Finish workout and passes the focused test. Wider validation is in progress.
- [ ] Verify native Reduce Motion and VoiceOver navigation, modal focus/dismissal, and save announcements; record human listening evidence separately from automated checks.
- [ ] Verify a real public TikTok video's playback, Finish pause, no automatic resume, and unavailable-video fallback; test Share Sheet delivery and deduplication without changing the personal library.
- [ ] Verify synthetic backup export through Files and restore into an isolated library, including notes, folders, and duplicate handling. Native Files export/restore/reimport passed on iOS 26.5 simulator with a synthetic workout, folder, and exact note text; physical-device verification remains.
- [ ] Update Testing.md with dated evidence and remaining limits; update Architecture.md, Development.md, Repository-Map.md, and user/design docs only where behavior or workflow changes.
- [ ] Run focused and full relevant tests, repository verification, and a simulator build; review screenshots, restore device settings, remove temporary runners, and verify the personal library.
- [ ] Review the final diff, commit coherent changes and the final plan status, and push the branch. Keep the goal open if required verification remains pending.

## Open questions
- None for planning. Device unlock, live service availability, and human confirmation of VoiceOver speech are execution dependencies; request assistance when needed and never count unverified behavior as passed.
