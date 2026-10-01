# Plan

Add a user-triggered workout-completion modal with the exact headline “Good Job BUNS!” and a cute, brief smiling-heart animation. Place a Finish workout action on the workout screen, reuse the app’s motion/accessibility system, and keep the celebration separate from saving a link or a video ending.

## Scope
- In: explicit Finish workout action, native dismissible modal, one-shot pink heart/sparkles, Reduce Motion and large-text behavior, UI regressions, current docs, validation, and saving to codex/gentle-app-motion.
- Out: automatic completion detection, workout history/streaks, persistence/schema changes, sounds/haptics, blocking timers, third-party graphics/dependencies, and a pull request.

## Action items
- [x] Inspect workout/player controls, shared motion components, UI tests, design language, user guide, testing guide, and repository map.
- [x] Commit this resolved plan as a local checkpoint on the existing approved branch.
- [x] Add a scrollable native completion sheet with the exact headline, smiling pink heart, one short sparkle animation, and an immediately available Done action.
- [x] Add Finish workout to the workout screen; dismiss the keyboard and request player pause when opened, preserve unsaved notes, and avoid automatic presentation or resume.
- [x] Add UI coverage for explicit trigger, exact copy, dismissal/reopening, preservation of notes, and reduced motion with maximum text; capture synthetic modal screenshots.
- [x] Update Design-Language.md, Design-and-Assets.md, User-Guide.md, Testing.md, and Repository-Map.md to describe explicit completion celebrations and the absence of completion history.
- [x] Run repository checks, simulator build, focused UI tests, and the full scheme; inspect modal screenshots and record device-only verification limits.
- [x] Review changes, commit the validated implementation and docs, and push the existing branch.

## Open questions
- None. Completion is explicitly self-reported through Finish workout; video playback ending does not establish workout completion. The user’s request authorizes this dismissible celebration as an exception to the previous inline-only celebration guidance.
