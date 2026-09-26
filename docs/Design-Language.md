# yarms design language

**Status: proposal v0.1, September 25, 2026.** The owner selected calm, focused native iPhone styling with restrained purple accents, and clarified that the app should also feel fun, playful, and exceptionally easy to return to. The existing icon and adaptive palette are retained. This is a foundation for discussion and future UI work, not a claim that the app already implements every rule. Component treatment and screen layouts remain proposals to refine through feedback from the intended user; no reference apps have been selected yet.

## Product character

**A friendly place to save a little inspiration and get moving.** yarms helps someone capture a workout, find it again, and follow along. The structure should feel calm and obvious; rounded shapes, soft purple, and friendly language supply a playful personality. Make returning feel welcoming and make saving feel easy. The video and the person's own organization remain central.

Use these principles in order when decisions conflict:

1. **Keep the workout usable.** Saving, finding, playback controls, and the external fallback take priority over decoration. A metadata or network failure must not make a saved link disappear.
2. **Make the next step obvious.** Give each action group one clear primary action. Use labels and hierarchy to distinguish saving, filtering, opening, and deleting.
3. **Make organization feel light.** Folders are optional. Unfiled is a useful destination, not an error or a task the person must clear.
4. **Be familiar on iPhone.** Use native navigation, search, sheets, menus, alerts, system type, and SF Symbols. Preserve their accessibility and platform behavior.
5. **Make encouragement feel personal.** Use plum actions, softly tinted backgrounds, generous rounding, and occasional friendly copy. Celebrate a completed action briefly and truthfully. Avoid competitive fitness language, guilt, and ornamental cards around every section.

These principles do not introduce workout tracking, streaks, recommendations, or additional navigation destinations.

### Playfulness without extra work

Let friendliness appear in a welcoming line such as “Ready when you are,” a rounded workout card, a familiar symbol, or a small saved confirmation. Keep instructional and error copy precise. A person should never need to dismiss a celebration to keep using the app. Mascots, confetti, points, and reminders are not part of this proposal; consider them only if user feedback reveals a real need.

Judge usability by whether someone can save without typing, find an appealing saved workout, and start following it with little hesitation. For an informal feedback session, ask the intended user to save a link, find it again, and open it; observe where labels or actions cause hesitation, then ask which details feel welcoming or distracting. Use that feedback to refine this guide before broad screen changes. There is no need to choose inspiration apps first.

## Foundations

### Color: choose by purpose

Keep the existing asset catalog as the color source of truth. The hex values below are rounded references derived from its sRGB components; views should use the named assets instead of copying hex values. Primary and secondary text use adaptive system foreground styles.

| Role / existing asset | Light reference | Dark reference | Use |
| --- | --- | --- | --- |
| Canvas / `YarmsCanvas` | `#FBF7FC` | `#18131C` | Main content background |
| Surface / `YarmsSurface` | `#FFFFFF` | `#29202D` | Workout cards and bottom action tray |
| Soft / `YarmsSoft` | `#F2E7F3` | `#3D2D42` | Unselected filters, quiet controls, image fallback |
| Accent / `AccentColor` | `#71317D` | `#E4B9EA` | Interactive text and symbols |
| Action / `YarmsAction` | `#71317D` | `#9752A2` | Filled action and selected filter, paired with white |
| Bloom / `YarmsBloom` | `#D8AEDC` | `#A76CAF` | Optional decorative detail; never essential text |

Accent and Action deliberately differ in dark mode. Do not use the light dark-mode Accent as a background for white labels. Calculated white-on-Action contrast is approximately **8.62:1 in light mode and 5.19:1 in dark mode**, using the stored asset components at full opacity. This checks those two pairs only, not the accessibility of the whole interface.

Use system destructive red with an explicit Delete label. Success and error messages require words or symbols as well as color. Disabled native controls should retain native treatment; a custom disabled control must remain identifiable and expose its disabled state. Never use Bloom or Soft alone to communicate selection.

Design each appearance deliberately. Native sheets, menus, navigation materials, and alerts keep their system surfaces. App content uses the brand surfaces. Verify custom pairs under Increase Contrast; appearance variants alone do not establish an increased-contrast design. Apple recommends adaptive semantic colors for appearance changes in its [Dark Mode guidance](https://developer.apple.com/design/human-interface-guidelines/dark-mode).

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

The following are **proposed tokens**, not existing Swift symbols. Values are in points. Native component metrics take precedence inside system controls.

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

The 44-point target is a yarms baseline for all custom controls. A compact glyph can sit inside that target. Prefer a minimum height over a fixed height for labeled actions, so larger text can wrap. Keep the library's save section, folders, and results in one vertical scrolling region. At larger sizes, use wrapping filters or a labeled folder picker instead of compressing labels or hiding workouts behind fixed chrome. These are future layout options, not implemented behaviors.

### Icons and motion

Use SF Symbols with consistent weight relative to adjacent text. A folder represents a named folder; a tray represents Unfiled everywhere. Keep labels on ambiguous actions. Icon-only controls need an accessible action name, such as “Back 10 seconds,” and a selected trait where appropriate.

Prefer system transitions. Custom state changes should be brief and purposeful; use 150–250 ms as a starting range, then verify on device. Honor Reduce Motion and avoid looping decoration, bouncing cards, animated gradients, or an animated loading placeholder. Haptics, if later added, should acknowledge meaningful actions and never be the only feedback.

## Component contracts

Build only components used by actual screens. Keep the visual API small and let the screen own navigation, persistence, and side effects.

| Component | Visual / interaction contract | Required states |
| --- | --- | --- |
| Save section | Concise heading, one helpful sentence, native `PasteButton` with Action tint. Keep it reachable in every library state. | Paste available/unavailable, saving, invalid link, saved, failed write |
| Folder filter | Label and count; selected Action fill plus selected accessibility trait. Unselected Soft fill. Show full name in the picker when truncation is unavoidable. | All, Unfiled, named, selected, empty, long name |
| Folder badge | Quiet icon and label. Visually lighter than a filter; never pretend a static label is a button. | Named folder, Unfiled, long name |
| Workout row | Thumbnail or neutral fallback, title, creator if available, folder. Make the whole row open the workout. Use a distinguishing source link when the title is missing. | Complete/missing metadata, long title, missing image, accessibility text |
| Primary action | Action fill, white label, 44-point minimum height; allow growth. One highest-emphasis action in a given action group. | Default, pressed, disabled, in progress |
| Secondary / tertiary action | Soft treatment for related controls; accent text for low-emphasis actions. Native menus for occasional operations. | Default, pressed, disabled |
| Playback control group | Native player controls plus compact custom controls. Keep custom targets at least 44 points; preserve explicit accessibility labels. | Loading, ready, playing, paused, failed |
| External fallback | Full-content-width “Open in TikTok” below transport controls. Keep it visible and usable when embedded playback fails. | Ready or unavailable embed, unresolved link |
| Notes panel | Optional disclosure; native text editing; keyboard Done; explicit Save notes; clear saved/error feedback. | Empty, existing note, editing, saving, saved, failed write |
| Empty state | Plain title, concise explanation, relevant next step. Keep save/search/folder controls available as appropriate. | First save, empty folder, empty Unfiled, no matches |
| Confirmation / feedback | Native confirmation for destructive or consequential operations. Use inline feedback for local state; an alert for failures that need attention. | Cancel, confirm, success, retryable failure |

Do not visually elevate Open in TikTok above the video itself. Its prominent button treatment provides a dependable alternative while the player remains the dominant content.

## Screen patterns and content

### Library

Hierarchy: native `yarms` navigation and utility menus → search → save section → folder selection → workout results. Preserve native search placement where the OS manages it. Put backup and folder administration in predictable menus rather than adding competing hero actions.

The populated library should be easy to scan without interpreting badges. Use consistent row anatomy. Thumbnails help recognition but must not be required to identify a workout. Preserve newly saved content visibility, including the current switch to Unfiled for new shares.

### Workout

Hierarchy: back navigation and contextual actions → title, creator, folder → portrait player → optional notes. Keep transport controls and the full-width external fallback in the bottom safe-area tray. Maintain the player's portrait framing and useful width; avoid wasting space on decorative headings. The notes editor and its focused text must remain reachable with the keyboard open. Short screens, landscape, and large text need device review rather than blindly applying a fixed height.

### Language and trust

Use `yarms` for the product name in visible copy. Use sentence case, direct verbs, and concrete nouns: “New folder,” “Move workout,” “Save notes,” “Export backup.” Be encouraging without pressure, calorie language, streaks, or judgments about exercise habits.

| Situation | Example copy / required meaning |
| --- | --- |
| Returning to the library | “Ready when you are.” / keep this welcome brief so saved workouts remain easy to reach |
| First save | “Your next move starts here.” / “Share a TikTok to yarms, or paste a link to start.” |
| Empty folder | “This folder is empty.” / “Move a saved workout here.” |
| No matches | “No matching workouts.” / “Try a different title, creator, or link.” |
| Failed playback | “This video couldn't play here.” / keep “Open in TikTok” available |
| Note saved | “Saved on this iPhone.” only after the write succeeds |
| Delete workout | Explain that the saved link and notes are removed from this iPhone; the TikTok post remains |
| Delete folder | Explain that workouts move to Unfiled and remain saved |
| Restore backup | Explain the additive merge before confirmation; do not imply the current library is replaced |

Never report success before persistence succeeds. On a stale or failed deletion, keep the person in context and explain how to retry. Do not describe a saved link as a downloaded or offline video. Use invented data in visual examples, tests, and review screenshots.

## SwiftUI adoption framework

Use **Apple's native controls + yarms semantic tokens + a small set of shared components + screen-specific composition**. No third-party UI framework is needed for this proposal.

1. Keep named colors in the existing asset catalog. Add a small proposed `YarmsApp/DesignSystem/YarmsTheme.swift` only when implementing the first screen: give spacing, radius, and target-size values semantic names; use SwiftUI text styles directly.
2. Extract one repeated component at a time under a proposed `YarmsApp/DesignSystem/Components/` directory. Likely first candidates are `FolderBadge`, `FolderFilter`, and the workout row. These files and symbols do not exist yet.
3. Keep store access, backup operations, player messages, and navigation out of styling components. Components receive content, state, and callbacks; action styles do not write data.
4. Start with the library as one coherent screen, then the workout/player screen, then notes and secondary flows. Each adoption change should work in both appearances before continuing.
5. Add previews for representative content and states. Use existing UI tests to protect saving, filtering, playback layout, notes, and deletion; extend coverage when the implementation changes those behaviors. A browser concept cannot prove SwiftUI or VoiceOver behavior.
6. Update this document when a proposal is adopted or revised. Record intentional exceptions near the relevant rule so another contributor can make the same decision.

The current implementation keeps most visual values inside [LibraryShellView.swift](../YarmsApp/LibraryShellView.swift) and [EmbeddedPlayerView.swift](../YarmsApp/EmbeddedPlayerView.swift). It uses several nearby spacing and radius values; the proposed scale consolidates them. Existing architecture and behavior remain described in [Architecture.md](Architecture.md).

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
- Run repository checks and relevant unit/UI tests after executable changes. Verify live TikTok playback, the Share Sheet, and Files on a physical device as described in Architecture.

Apple's [Accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility) informs the platform checks. The acceptance criteria here are project requirements to verify during implementation, not a statement that the existing app or this proposal has passed an accessibility audit.

## Proposal validation

The first proposal is documentation only. Its asset references and two white-on-Action contrast ratios were checked against the repository. App test files are unchanged because no executable app behavior changes. Repository/link verification and the conversation concept are checked separately; simulator and device acceptance checks remain work for UI adoption.
