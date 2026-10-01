# Plan

Address the animation review’s confirmed light-mode contrast issue and missing explicit spoken save feedback. Use adaptive primary text for save results and the completion message, and post low-priority VoiceOver announcements from successful save actions without changing focus or replaying them on redraw.

## Scope
- In: readable save/completion feedback, polite announcements for new/duplicate/imported saves and successful notes saves, focused contrast and large-text regressions, current docs, simulator validation, and saving to codex/gentle-app-motion.
- Out: new animation effects, persistence changes, redesigning unrelated metadata, adding dependencies, a pull request, and claiming physical-device VoiceOver verification.

## Action items
- [x] Inspect the shared feedback components, save handlers, existing UI tests, Apple announcement API, and design/user/testing documentation.
- [x] Commit this resolved plan as a local checkpoint.
- [x] Use adaptive primary text for inline save confirmations and the completion modal’s supporting message.
- [x] Add one low-priority announcement per successful save-result event; keep failures, opening existing records, scrolling, and redundant unchanged notes saves silent.
- [x] Extend existing UI regressions with focused contrast audits, maximum-text bounds, and native swipe dismissal; preserve existing save/error/relaunch assertions.
- [x] Update Design-Language.md, Design-and-Assets.md, User-Guide.md, Repository-Map.md, and Testing.md with feedback semantics, audit scope, and device-only checks.
- [x] Run repository checks, simulator build, five focused tests in light mode, then the full suite in dark mode with Increase Contrast; inspect updated screenshots and investigate any regression.
- [x] Review the final diff, commit the implementation and completed plan, and push the existing branch.

## Open questions
- None. The system announcement uses low priority so existing speech can finish. Real-device VoiceOver speech and native Reduce Motion integration remain explicitly documented checks; temporary audit warnings will not be described as fixed without evidence.
