# Use Yarms

[Documentation index](README.md) · [Install from source](Development.md)

Yarms keeps TikTok workout links, folders, and your notes on your iPhone. It has no Yarms account or built-in cross-device sync. Videos play through TikTok; they are not downloaded for offline use.

## Save your first workout

1. Install and open Yarms using the [setup guide](Development.md).
2. In TikTok, open a workout, tap **Share**, then choose **Save to yarms**. If necessary, use **More** in the iOS share sheet to find it.
3. Return to Yarms. New links are imported into **Unfiled**; title, creator, and thumbnail appear when TikTok provides them.

You can also copy a TikTok video link and tap **Paste** in Yarms. The paste action stays available when the library is empty or a search has no results. [Sharing from TikTok](Shortcut-Sharing.md) explains the handoff and optional Shortcut action.

The library offers a gentle invitation to choose a saved workout or save a new one. Saving a link does not mark a workout complete. You can celebrate finishing from the workout screen; Yarms does not store a completion history.

After a new save, an inline checkmark says **Saved for your next move**. Its small pink flourish ends on its own; the text stays until you change context. Pasting an already-saved video says **Already in your library** and selects All so you can find it. Opening your existing library does not celebrate old saves.

With VoiceOver, Yarms also requests a brief spoken save result after a new or duplicate paste, importing new shared links, or saving notes. It lets existing speech finish and keeps focus on your current control. Scrolling back to the confirmation does not repeat the announcement, and saving an unchanged, already-confirmed note stays quiet.

A saved link survives metadata or network failure. Saving the same recognized video again does not create another workout. Short links can appear separately until Yarms resolves them to the same video.

## Find and organize workouts

| Task | How |
| --- | --- |
| Browse everything | Select **All** above the library |
| See links without a folder | Select **Unfiled** |
| Create a folder | Tap **New folder**, or choose it in the toolbar's **Folders** menu |
| Move a workout | Swipe its row left and tap **Move**, or use the folder menu on the workout screen |
| Rename a folder | Select it, then use **Folders → Rename folder**; a long press on its chip also offers Rename |
| Delete a folder | Select it and choose **Folders → Delete folder**, then confirm; its workouts move to Unfiled |
| Search | Use **Search workouts** for a title, creator, or link; choose All to search the whole library |

A workout belongs to one folder at a time. Folder names must be nonempty, at most 80 characters, and distinct regardless of case or accents. Leading/trailing whitespace is removed; control characters are rejected. Folder counts show totals for each folder, not just search matches. Search does not include note text or folder names.

Folders normally appear as a horizontal row. With accessibility text sizes, more than six named folders, or a folder name longer than 24 characters, tap **Choose folder** to see All, Unfiled, and named folders in a sheet with full names and counts. The selected folder has a checkmark.

## Watch and take notes

Open a workout to see its title, creator, folder, and portrait video. Once TikTok's player is ready, use **Back 10 seconds**, **Play/Pause**, **Forward 10 seconds**, and **Replay from start**. Replay seeks to the beginning; use Play if the video is paused. TikTok's own controls remain available.

**Open in TikTok** is always available on the workout screen. It opens the saved or resolved link through iOS, which may use TikTok or the browser. Private, removed, or restricted posts may still be unavailable there.

Scroll to **Notes (optional)**, enter your notes, dismiss the keyboard with **Done** if needed, then tap **Save notes**. Done only dismisses the keyboard; notes require Save. To clear a note, delete its text and save again. Notes stay with the local workout and are included in backups. **Saved on this iPhone** confirms a successful save; editing again clears that confirmation until you save the new text.

## Finish a workout

When you are finished, scroll below the video and tap **Finish workout**. A modal says **Good Job BUNS!** with a smiling pink heart and one short sparkle animation. Tap **Done** or swipe down whenever you want to return to the workout; there is no timer to wait through.

Opening the celebration dismisses the keyboard and asks the embedded player to pause if it is ready. Closing it does not start playback or save/change your notes. The button also works when the video is unavailable or you followed along in TikTok. You decide when you are finished: saving a link, opening a workout, or reaching the end of a clip never opens the celebration automatically.

This is an encouraging moment, not a workout log: it does not store completion dates, counts, or streaks. You can use it again after another session.

## Delete a saved workout

Swipe a library row left and tap **Delete**, or tap the trash button on the workout screen. Confirm **Delete workout** to remove its link, notes, and folder assignment from this installation. Cancel keeps it saved. The folder and other workouts remain, and the TikTok post is unaffected.

There is no in-app undo. A later share or restoring an older backup can bring the workout back. If Yarms reports that the selection changed, return to the library and select it again: background link resolution may have combined it with an earlier save.

## Export and restore

To export, open **Backup → Export backup**, choose a Files location, and finish saving. A library containing only folders can also be exported. The file contains links, details, notes, and folders, with no video files. It is **unencrypted**; keep it private.

To restore:

1. Open **Backup → Restore backup** (or **Restore a backup** in an empty library).
2. Choose a Yarms JSON backup in Files.
3. Review and confirm the restore. Yarms adds missing workouts and combines matching records while retaining current notes and folder assignments.
4. Check the added/updated result and a few workouts and notes. Select All and clear search if the restored items are hidden by your current filters.

Restore is additive: it does not replace your library or remove items that are absent from the backup. Distinct backed-up note paragraphs are appended; repeated restore does not keep adding the same paragraphs. Folders are matched by name. Thumbnails and short-link resolutions may need a network refresh. The exact rules are in [Data and privacy](Data-and-Privacy.md).

Import is limited to **10 MB** (10,485,760 bytes). Export keeps the whole library even above that limit, but warns that this version cannot import the resulting file. Do not remove or replace the old installation when its only backup is too large to restore. Current builds read older schema 1 backups; older builds reject new schema 2 backups.

For the former App Group build, follow [Storage migration](Storage-Migration.md) **before upgrading**. For another iPhone, install Yarms separately and transfer a private backup through Files; there is no automatic Yarms sync.

## Gentle motion

Buttons, folder choices, and save confirmations use brief animation. Save feedback stays inline. The workout-completion modal opens only when you choose Finish workout and can be dismissed immediately. To remove custom motion, enable **Settings → Accessibility → Motion → Reduce Motion** on your iPhone; checkmarks, confirmation text, selected folders, and the static completion heart remain available.

## Troubleshooting

| What you see | What to try |
| --- | --- |
| Save to yarms is missing | Confirm Yarms is installed and opens; check More in the iOS share sheet. Use Paste as a fallback. |
| Shared workout seems missing | Open/foreground Yarms, choose All or Unfiled, and clear search. An existing recognized video is kept instead of duplicated. |
| Invalid-link error | Copy a TikTok video link. Profile URLs, other services, and non-HTTPS URLs are not supported. |
| Generic title or missing thumbnail | The link is still saved. Check connectivity and reopen Yarms to retry incomplete metadata. TikTok may not provide it. |
| Player unavailable or controls disabled | Allow time for TikTok to load; try Open in TikTok. An unresolved short link cannot yet build an inline player. |
| Notes did not change | Tap Save notes after editing. If the record changed, reopen it from the library and retry. |
| Unsupported backup or Backup too large | Use an intact Yarms export within the limit. See the compatibility and validation rules in Data and Privacy; do not alter the original backup. |
| App stops opening after a period of use | A free Personal Team signing profile may need renewal. Follow the rebuild/reinstall guidance in Development; preserve your data and backup. |
| Library cannot be read | Keep the installation and any backups. Avoid deleting the app as a troubleshooting step; report the issue with a synthetic reproduction and no personal library files. |

For build/signing failures see [Development](Development.md); for a bug, use the [issue forms](../.github/ISSUE_TEMPLATE/). Report security problems privately through [SECURITY.md](../SECURITY.md).
