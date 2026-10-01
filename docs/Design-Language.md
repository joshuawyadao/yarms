# yarms design language

**Status: adopted foundation with gentle motion, October 1, 2026.** Cool-tone pink is the primary brand direction, reflecting the intended user’s preference. Pair it with calm native iPhone structure, playful details, and gentle invitations to save and try workouts. The adaptive palette includes light, dark, and increased-contrast variants; the app follows the system appearance. Shared tokens and components style the library, workout player, notes, and empty states. Native sheets, menus, alerts, and the Share extension retain system presentation. Feedback from the intended user will refine the shade and experience.

## Product character

**A friendly place to save a little inspiration and get moving.** yarms helps someone capture a workout, find it again, and follow along. The structure should feel calm and obvious; rounded shapes, cool pink, and friendly language supply a playful personality. Make returning feel welcoming and make saving feel easy. The video and the person's own organization remain central.

Use these principles in order when decisions conflict:

1. **Keep the workout usable.** Saving, finding, playback controls, and the external fallback take priority over decoration. A metadata or network failure must not make a saved link disappear.
2. **Make the next step obvious.** Give each action group one clear primary action. Use labels and hierarchy to distinguish saving, filtering, opening, and deleting.
3. **Make organization feel light.** Folders are optional. Unfiled is a useful destination, not an error or a task the person must clear.
4. **Be familiar on iPhone.** Use native navigation, search, sheets, menus, alerts, system type, and SF Symbols. Preserve their accessibility and platform behavior.
5. **Make encouragement feel personal.** Use deeper rose-pink actions, softly tinted backgrounds, generous rounding, and occasional friendly copy. Celebrate a completed action briefly and truthfully. Avoid competitive fitness language, guilt, and ornamental cards around every section.

The completion celebration is self-reported through Finish workout. It does not introduce workout history, streaks, recommendations, or additional navigation destinations.

### Playfulness without extra work

Let friendliness appear in an invitation such as “Find your feel-good move,” a rounded workout card, a familiar symbol, or a small saved confirmation. Keep instructional and error copy precise. Save confirmations stay inline and require no dismissal. The explicitly requested workout-completion celebration is a native modal opened only by Finish workout, with an immediately available Done action and swipe dismissal. Its smiling heart and small sparkles are confined to that moment; there are no ongoing mascots, confetti showers, points, or reminders.

Encourage a real next step: choose a saved workout to try, save a move that looks fun, or return when it suits the person. Frame movement as enjoyable and self-directed. Rest days and returning after a break need no apology. Keep exercise instructions with the original creator; do not invent routines or progress. Celebrate a workout only when the person taps Finish workout. Saving a video or reaching its end does not establish workout completion, and the app does not save a completion history. Avoid guilt, body/weight judgments, streak loss, and urgency.

Judge usability by whether someone can save without typing, find an appealing saved workout, and start following it with little hesitation. For an informal feedback session, ask the intended user to save a link, find it again, and open it; observe where labels or actions cause hesitation, then ask which details feel welcoming or distracting. Use that feedback to refine the implemented screens and this guide in the next iteration. There is no need to choose inspiration apps first.

## Foundations

### Color: choose by purpose

Use a blue-based rose pink with a slight lilac influence. Keep peach, coral, and warm salmon out of the core palette. Light appearance uses pale blush and white; dark appearance uses deep rose-charcoal with brighter pink accents. Pink is an inviting accent rather than a saturated full-screen background.

Keep the asset catalog as the color source of truth. The hex values below match its sRGB components; views should use the named assets instead of copying hex values. Primary and secondary text use adaptive system foreground styles.

| Role / existing asset | Light reference | Dark reference | Use |
| --- | --- | --- | --- |
| Canvas / `YarmsCanvas` | `#FFF7FC` | `#1C141B` | Main content background |
| Surface / `YarmsSurface` | `#FFFFFF` | `#2D202A` | Workout cards and bottom action tray |
| Soft / `YarmsSoft` | `#F9E4F1` | `#452B3D` | Unselected filters, quiet controls, image fallback |
| Accent / `AccentColor` | `#8C1D5E` | `#F3B5D7` | Interactive text and symbols |
| Action / `YarmsAction` | `#A92D76` | `#B3377E` | Filled action and selected filter, paired with white |
| Bloom / `YarmsBloom` | `#ECA6CD` | `#C977AA` | Optional decorative detail; never essential text |

Accent and Action deliberately differ in dark mode. Do not use the light dark-mode Accent as a background for white labels. Calculated white-on-Action contrast is **6.32:1 in light mode and 5.58:1 in dark mode**, using the stored sRGB components. The increased-contrast variants provide **8.56:1 and 7.07:1**, respectively. Accent on Canvas, Surface, and Soft exceeds 4.5:1 in all four appearances. Calculated pressed primary and secondary label treatments also exceed 4.5:1 on the brand backgrounds; the lowest checked pair is 4.70:1 for a pressed secondary action in ordinary light appearance. These measurements cover the defined custom pairs, not system materials, disabled controls, images, or the whole interface.

Use system destructive red with an explicit Delete label. Success and error messages require words or symbols as well as color. Disabled native controls should retain native treatment; a custom disabled control must remain identifiable and expose its disabled state. Never use Bloom or Soft alone to communicate selection.

Follow the system appearance without forcing a scheme or adding a separate appearance preference. Each brand asset includes an Increase Contrast variant: stronger foreground/action colors and adjusted surfaces in dark appearance. Keep the existing increased-contrast outlines on secondary controls and folder filters. Native sheets, menus, navigation materials, alerts, and the Share extension keep their adaptive system surfaces. Review these combinations on device as well as measuring the custom pairs. Apple recommends adaptive semantic colors for appearance changes in its [Dark Mode guidance](https://developer.apple.com/design/human-interface-guidelines/dark-mode).

### Typography: system styles with clear roles

Use the iOS system font. Prefer the default system design; avoid mixing rounded and default system type in the same hierarchy. The existing lowercase `yarms` wordmark is text, not a second display font.

| Content role | SwiftUI style | Treatment |
| --- | --- | --- |
| Navigation title | Native navigation title | Let the navigation container size it |
| Workout detail title | `.title2` | Bold; wrap to show the complete title |
| Section heading / workout row title | `.headline` | Standard headline emphasis |
| Notes, form input, main explanation | `.body` | Regular; no fixed-height text boxes |
| Creator / secondary description | `.subheadline` | Secondary foreground |
| Folder badge / supporting metadata | `.caption` | Secondary or accent; never essential instructions |
| Action label | `.headline` or native control style | Sentence case |

Use monospaced digits for counts and player time, not ordinary prose. Avoid all-caps section headings as the default. Row titles may use two lines at ordinary sizes, with the complete title available on the workout screen and in the accessibility label; at accessibility sizes allow additional lines and vertical reflow. Folder names must remain identifiable when long or similar, including in the folder picker.

Use semantic text styles and Dynamic Type instead of fixed font sizes. This follows Apple's [Typography guidance](https://developer.apple.com/design/human-interface-guidelines/typography). Do not shrink text to force a layout to fit.

### Spacing, shape, and size

These roles are implemented in `YarmsTheme`: `space.*` maps to `Spacing.*`, `radius.*` to `Radius.*`, and the size roles to `minimumTarget` and `maximumContentWidth`. Values are in points. Native component metrics take precedence inside system controls; the UIKit Share extension keeps its own native layout constants.

| Token | Value | Default use |
| --- | --- | --- |
| `space.xs` | 4 | Closely related label lines |
| `space.sm` | 8 | Icon/label gaps and compact control gaps |
| `space.md` | 12 | Row content and filter gaps |
| `space.lg` | 16 | Screen gutter and card padding |
| `space.xl` | 24 | Separation between content groups |
| `space.xxl` | 32 | Deliberate breaks, such as an empty-state group |
| `radius.control` | 12 | Custom buttons, thumbnails, notes field |
| `radius.surface` | 20 | Friendly, rounded workout cards and notes container |
| `radius.media` | 20 | Outer player container, if clipping does not obscure controls |
| `shape.filter` | Capsule | Interactive folder filters only |
| `target.minimum` | 44 × 44 | Effective custom interactive target |
| `content.maximum` | 600 | Shared reading width on larger layouts |

Cards separate independent tappable workouts. Use spacing and headings to group related content rather than nesting cards. Default to flat surfaces without shadows. Use a system separator when an edge is necessary; low-contrast decorative borders cannot be the only cue that a control exists.

The 44-point target is a yarms baseline for all custom controls. A compact glyph can sit inside that target. Prefer a minimum height over a fixed height for labeled actions, so larger text can wrap. Keep the library's save section, folders, and results in one vertical scrolling region. At accessibility text sizes, with more than six named folders, or when a folder name exceeds 24 characters, show the labeled folder picker. It opens a native sheet with wrapping names, counts, and explicit selection. Smaller collections use horizontal filter chips. At accessibility sizes, stack the folder heading and New folder action, and stack each workout card's thumbnail and text; the player stacks creator/folder metadata and note actions.

### Icons and motion

Use SF Symbols with consistent weight relative to adjacent text. A folder represents a named folder; a tray represents Unfiled everywhere. Keep labels on ambiguous actions. Icon-only controls need an accessible action name, such as “Back 10 seconds,” and a selected trait where appropriate.

Prefer system transitions. `YarmsMotion` supplies 160 ms ease-out press feedback and 220 ms ease-in-out local transitions. Custom buttons compress to 98% while pressed without overshoot; the outer hit target stays at least 44 points. Folder chips reserve the checkmark space so selection does not shuffle their labels and touch targets. Their selection and counts transition locally, folder badges fade when changed, and thumbnail images fade into their existing frame when they arrive.

A successful new save shows an inline checkmark and one small pink bloom behind it (160 ms in, 220 ms out). The confirmation text remains available after the flourish, needs no dismissal, and clears when the context changes or another attempt begins. Ordinary text sizes reserve its footprint to keep adjacent controls steady; accessibility sizes collapse an empty status instead of reserving several blank lines, and allow a visible result to wrap fully. Duplicate pastes say “Already in your library” without a celebration and select All so the existing workout remains visible. Notes show “Saved on this iPhone” only after persistence succeeds and clear that status on the next edit; repeated saves of an unchanged, already-confirmed note do not replay the flourish. Loading existing records and scrolling a confirmation back into view do not trigger a celebration.

Read the system Reduce Motion preference through `yarmsReduceMotion`. When enabled, custom scaling, bloom, count motion, and fades are disabled; words, checkmarks, selection, and pressed color feedback remain. Its internal override is for previews and isolated debug UI tests, and cannot turn off the real system preference. See Apple's [Reduce Motion environment documentation](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion).

Keep animations local to controls and confirmation symbols. Search typing, full library result changes, background metadata text updates, playback time, navigation, keyboard movement, and the Share extension use their existing behavior. No looping decoration, bouncing cards, animated gradients, loading shimmer, sounds, haptics, added completion delays, or startup choreography. The completion modal is the explicit exception: a smiling pink heart makes one brief hop/pop with soft sparkles after the person taps Finish workout. It settles in under a second, never repeats while the modal is open, and becomes static with Reduce Motion. It never waits to enable dismissal.

## Component contracts

Build only components used by actual screens. Keep the visual API small and let the screen own navigation, persistence, and side effects.

| Component | Visual / interaction contract | Required states |
| --- | --- | --- |
| Save section | Concise heading, one helpful sentence, native `PasteButton` with Action tint. Keep it reachable in every library state. | Paste available/unavailable, saving, invalid link, saved, failed write |
| Folder filter | Label and count; selected Action fill, checkmark, and selected accessibility trait. Unselected Soft fill. Use the sheet picker for large text or long/many folders. | All, Unfiled, named, selected, empty, long name |
| Folder badge | Quiet icon and label. Visually lighter than a filter; never pretend a static label is a button. | Named folder, Unfiled, long name |
| Workout row | Thumbnail or neutral fallback, title, creator if available, folder. Make the whole row open the workout. Use a distinguishing source link when the title is missing. | Complete/missing metadata, long title, missing image, accessibility text |
| Primary action | Action fill, white label, 44-point minimum height; allow growth. One highest-emphasis action in a given action group. | Default, pressed, disabled, in progress |
| Secondary / tertiary action | Soft treatment for related controls; accent text for low-emphasis actions. Native menus for occasional operations. | Default, pressed, disabled |
| Playback control group | Native player controls plus compact custom controls. Keep custom targets at least 44 points; preserve explicit accessibility labels. | Loading, ready, playing, paused, failed |
| External fallback | Full-content-width “Open in TikTok” below transport controls. Keep it visible and usable when embedded playback fails. | Ready or unavailable embed, unresolved link |
| Notes panel | Optional disclosure; native text editing; keyboard Done; explicit Save notes; clear saved/error feedback. | Empty, existing note, editing, saving, saved, failed write |
| Empty state | Plain title, concise explanation, relevant next step. Keep save/search/folder controls available as appropriate. | First save, empty folder, empty Unfiled, no matches |
| Confirmation / feedback | Native confirmation for destructive or consequential operations. Use inline feedback for local state; an alert for failures that need attention. | Cancel, confirm, success, retryable failure |
| Workout completion | Explicit Finish workout below the player opens a native modal with “Good Job BUNS!”, a smiling pink heart, one short sparkle animation, and Done. No stored completion record. | Ready/unavailable video, reduced motion, large text, immediate dismissal, reopening |

Do not visually elevate Open in TikTok above the video itself. Its prominent button treatment provides a dependable alternative while the player remains the dominant content.

## Screen patterns and content

### Library

Hierarchy: native `yarms` navigation and utility menus → search → save section → folder selection → workout results. Preserve native search placement where the OS manages it. Put backup and folder administration in predictable menus rather than adding competing hero actions. Hide the welcome and introductory copy while a search query is active so search results and Paste remain easier to reach, especially at large text sizes.

The populated library should be easy to scan without interpreting badges. Use consistent row anatomy. Thumbnails help recognition but must not be required to identify a workout. Preserve newly saved content visibility, including the current switch to Unfiled for new shares.

### Workout

Hierarchy: back navigation and contextual actions → title, creator, folder → portrait player → Finish workout → optional notes. Keep transport controls and the full-width external fallback in the bottom safe-area tray. Maintain the player's portrait framing and useful width; avoid wasting space on decorative headings. The notes editor and its focused text must remain reachable with the keyboard open. Short screens, landscape, and large text need device review rather than blindly applying a fixed height.

The Finish workout button is available even when an embedded video cannot play, so someone who followed along externally can use it. Opening the celebration dismisses the keyboard and requests a pause from a ready embedded player. Dismissing it returns to the current workout without auto-resuming or changing notes. It uses medium/large native sheet sizes, or a full-height sheet at accessibility text sizes; content can scroll and Done remains reachable.

### Language and trust

Use `yarms` for the product name in visible copy. Use sentence case for controls, direct verbs, and concrete nouns: “New folder,” “Move workout,” “Save notes,” “Export backup.” Be encouraging without pressure, calorie language, streaks, or judgments about exercise habits.

| Situation | Example copy / required meaning |
| --- | --- |
| Returning to the library | “Find your feel-good move.” / “Pick a workout to try today, or save a new one for later.” |
| First save | “Your next move starts here.” / “Share a TikTok to yarms, or paste a link to keep it here.” |
| Empty folder | “This folder is empty.” / “Move a saved workout here.” |
| No matches | “No matching workouts.” / “Try a different title, creator, or link.” |
| Failed playback | “This video couldn't play here.” / keep “Open in TikTok” available |
| Note saved | “Saved on this iPhone.” only after the write succeeds |
| Workout finished | Exact requested headline “Good Job BUNS!” after the person taps Finish workout; encouragement does not claim saved completion history |
| Delete workout | Explain that the saved link and notes are removed from this iPhone; the TikTok post remains |
| Delete folder | Explain that workouts move to Unfiled and remain saved |
| Restore backup | Explain the additive merge before confirmation; do not imply the current library is replaced |

Never report success before persistence succeeds. On a stale or failed deletion, keep the person in context and explain how to retry. Do not describe a saved link as a downloaded or offline video. Use invented data in visual examples, tests, and review screenshots.

## SwiftUI component framework

Use **Apple's native controls + yarms semantic tokens + shared content components + screen-specific composition**. There is no third-party UI framework.

| Source | Responsibility |
| --- | --- |
| [YarmsTheme.swift](../YarmsApp/YarmsTheme.swift) | Adaptive color roles, spacing, radii, target/content sizes, motion timing, Reduce Motion policy, and action styles |
| [YarmsUIComponents.swift](../YarmsApp/YarmsUIComponents.swift) | `FolderBadge`, `FolderFilter`, `WorkoutCardContent`, `YarmsSaveConfirmation`, `WorkoutCompletionView`, `YarmsEmptyState`, and interactive/light/dark/large-text previews |
| [LibraryShellView.swift](../YarmsApp/LibraryShellView.swift) | Save/search/folder composition, adaptive folder sheet, navigation, move/delete/backup operations |
| [EmbeddedPlayerView.swift](../YarmsApp/EmbeddedPlayerView.swift) | Workout/player composition, explicit completion presentation, notes, compact transport controls, and bottom fallback |
| [ShareViewController.swift](../YarmsShare/ShareViewController.swift) | Native progress indicator and scalable “Saving to yarms…” status during capture |

Keep these two small shared Swift files alongside the app's existing sources so the current Xcode project generator can discover them. A deeper directory hierarchy is unnecessary until the component set grows. Components receive content, state, and callbacks; action styles never write data. Persistence, backup operations, and player messages stay with their existing owners.

Use an existing token or component before adding a new one. Extend component previews for new states, and keep the existing UI contracts for saving, selected folders, notes, deletion, and the visible full-width TikTok fallback. System PasteButton retains its native size, wording, and paste permission behavior. The illustrated concept's custom full-width Paste treatment is intentionally represented with a native Paste control in the app.

The Share extension uses system colors rather than linking app-only assets. Its spinner reports work in progress; completion still occurs only after the shared inbox write succeeds, without a celebration delay. Native navigation, sheets, alerts, and Files pickers remain system-managed. Custom motion is confined to the main app’s shared controls, inline feedback, and explicitly opened workout-completion modal; no haptics were introduced.

## Decision checklist

For every proposed element, answer these questions before adding a new visual rule:

1. Which user action does this support: save, find, organize, follow along, or recover?
2. Can a native component or an existing shared component do it well?
3. Which existing semantic color, type, spacing, and shape roles apply?
4. Is the action hierarchy clear without depending on color alone?
5. What happens with long text, missing metadata, no results, loading, and failure?
6. Does it stay usable with large text, VoiceOver, dark appearance, and one-handed touch?
7. If it changes data, does the copy describe the real effect and acknowledge only a successful write?

If a new token or component is still necessary, document its purpose and where it is reused. Do not add a one-off value because a single screenshot looks better.

## Acceptance checks for UI adoption

- Review light and dark appearance on a small and large supported iPhone, with ordinary and maximum accessibility text, Bold Text, Increase Contrast, and Reduce Motion.
- Use 4.5:1 as the project target for ordinary text, 3:1 for qualifying large text, and 3:1 for meaningful custom control boundaries/icons. Measure actual foreground/background pairs, including pressed and selected states. Do not treat the two Action measurements above as full coverage.
- Verify 44-point effective targets and usable layout in landscape and with the keyboard open. No primary action or note content may become unreachable.
- Check VoiceOver order, labels, selected/disabled state, full titles, and helpful feedback. Do not announce every playback-time update.
- Exercise empty library, empty folder, zero matches, long/similar folder names, missing creator/title/image, unresolved link, unavailable video, write failure, and stale deletion.
- Preserve current test contracts: distinguish metadata-free workouts, keep Paste accessible with zero matches, retain compact transport controls and the visible full-width fallback, persist notes, and confirm deletion.
- Run repository checks and relevant unit/UI tests after executable changes. Verify live TikTok playback, the Share Sheet, and Files on a physical device as described in [Testing](Testing.md).

Apple's [Accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility) informs the platform checks. The acceptance criteria here are project requirements to verify during implementation, not a statement that the existing app or this proposal has passed an accessibility audit.

## Validation history

The September 25 concept established the initial purple palette and checked two white-on-Action contrast pairs. It did not validate native layout. The September 30 implementation adds native component previews and a UI regression for large-text folder selection and zero-result Paste access. Existing UI tests retain save, note persistence, folder movement, backup access, deletion confirmation, and compact player-control assertions.

The UI adoption passed 80 tests with two expected skips before integration with newer main changes, plus three dark-mode UI checks. The pink refinement passed four focused folder/large-text executions across light and dark appearance. See [Testing](Testing.md) for repeatable checks and [Implementation-Plan.md](Implementation-Plan.md) for the active integration results. Simulator checks do not establish live TikTok playback, cross-process sharing, physical-device comfort, or a full VoiceOver/accessibility audit.

The cool-pink refinement adds explicit increased-contrast assets and an invitation to choose a workout in the populated library. Contrast calculations use the current asset values, including pressed custom button treatments. The app icon remains the approved artwork.
