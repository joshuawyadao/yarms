# Move workouts from an earlier Yarms build

The original signed Yarms build kept its library and pending links in an App Group container. The free Personal Team build uses Yarms's own Application Support container. It cannot read the old App Group after the upgrade because it no longer has that entitlement. **Export a backup before installing this build over an older one.** This applies to anyone who ran and saved workouts with the earlier signed app; a fresh installation can proceed normally.

1. Open the earlier Yarms build while it is still installed and signed with the team that provided its App Group. Let it import any pending shared links into the library.
2. In **Backup**, tap **Export backup** and save the JSON file to Files. Keep it somewhere private because it includes workout links and notes. Check that the export completed and that the file is present.
3. If Yarms warns that the export exceeds this version's 10 MB restore limit, stop before upgrading. The current importer cannot restore that file; keep the old build and backup until an import path is available.
4. Install the new free-team build. Open **Backup** → **Restore backup**, choose the exported JSON file, and confirm the restore. On an empty library, **Restore a backup** is also shown on the main screen.
5. Compare the workout count and a few notes with the earlier library. Keep the backup until those checks pass. Then set up the [Save to Yarms Shortcut](Shortcut-Sharing.md) for future shares.

If the older build has already been replaced and no backup exists, do not delete the app or its data while investigating recovery. The previous signed build may be needed to access its App Group again; recovery depends on whether iOS retained that container and whether the original signing team can still sign it. The new build cannot read that location directly.
