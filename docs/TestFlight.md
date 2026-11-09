# Private TestFlight release

Use this guide to make Yarms available to one external tester through Apple's TestFlight beta. [Release](Release.md) describes the checked-in build checker; [Development](Development.md) covers source installs. Finish signing, upload, and App Store Connect declarations using an Apple account with the required team access.

## Before opening Xcode

- Export and inspect a backup of any existing library, then read [Storage migration](Storage-Migration.md). Changing signing teams or replacing an old build can prevent access to its data. Keep the backup private; it contains workout links and notes.
- Merge this branch before submitting, then confirm that the public [privacy policy](https://github.com/joshuawyadao/yarms/blob/main/PRIVACY.md) displays the released text. The app bundles the same policy for offline reading and links to that public copy. Use that URL in App Store Connect. An unmerged branch URL is temporary.
- Choose an unused build number and check the tester's iPhone runs iOS 18 or newer. Do not put a team ID, certificate, profile, API key, tester email, personal workout data, or private screenshot in Git.
- Check any current Apple agreements or account prompts in [App Store Connect](https://appstoreconnect.apple.com). You must answer the account's actual prompts before uploading or inviting.

## Sign both targets

1. Open `Yarms.xcodeproj`, sign into Xcode **Settings → Accounts**, and select the paid Developer Program team.
2. For **Yarms** and **YarmsShare**, open **Signing & Capabilities**. Select that same team and automatic signing. Keep the bundle IDs `com.joshuawyadao.yarms` and `com.joshuawyadao.yarms.share`, and register them under that team if needed. Do not change only one target's ID or team.
3. Both checked-in entitlements use `$(YARMS_KEYCHAIN_GROUP)`; its project value is `$(AppIdentifierPrefix)com.joshuawyadao.yarms.shared`. Confirm the paid team's profiles and resolved signatures grant the same Keychain access group to the app and embedded extension. [Development](Development.md#install-on-an-iphone) explains the device check. A simulator build cannot prove that handoff.
4. Install a signed build on your own iPhone. In TikTok, use **Share → More → Save to yarms**, launch Yarms, and confirm that the link imports once. Test a second share and try a real public video's player and **Open in TikTok** fallback. The test suite uses invented links and cannot prove live provider behavior.

## Create and upload the build

1. In App Store Connect, [add an iOS app record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/) for `com.joshuawyadao.yarms`. Choose the app name, language, SKU, and access appropriate to your account. Use your real contact information where Apple requests it.
2. Run `./scripts/verify-repository.sh`, `python3 scripts/test-ios.py`, and `python3 scripts/release-ios.py check`. The [Release guide](Release.md) also supports an optional local archive, for example `python3 scripts/release-ios.py archive --version 1.0.0 --build-number 2 --team YOUR_TEAM_ID`. The script needs working local signing and profiles; it does not download profiles or upload to Apple. Organizer can re-sign an archive for distribution during upload. Use a fresh build number for each candidate.
3. In Xcode, select the **Yarms** scheme and **Any iOS Device (arm64)** or another generic iOS device destination. Set the marketing version and build number to match the candidate on both Yarms and YarmsShare. Each target has its own version settings; the extension Info.plist reads its target's values. Choose **Product → Archive**. In Organizer, inspect the archive, select **Distribute App → App Store Connect → Upload**, and complete validation and signing prompts. Select a distribution method eligible for external TestFlight testing; **TestFlight Internal Only** builds cannot go to external testers. [Apple upload help](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/) explains that processing must finish before a build appears.
4. Check the processed build's bundle IDs, version/build, app icon, embedded extension, privacy policy resource, privacy manifests, and export compliance status. Fix any upload or processing error, increment the build number, and upload again. The repository's unsigned checks and archives do not prove App Store acceptance.

## Complete the beta information

In **TestFlight → Test Information**, provide the required beta description, feedback email, and review contact details. Add a privacy policy URL and any other metadata the account requests. [Apple's test-information guide](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/) distinguishes this beta information from a later App Store product page.

Suggested **Beta App Description**:

> Save TikTok workout links, organize them into folders, watch available posts through TikTok's embedded player, add personal notes, and export or restore a local backup. No Yarms account is required. Playback and metadata depend on TikTok and on each post remaining available.

Suggested **What to Test**:

> Save a public TikTok workout through the Share Sheet or paste its link in Yarms. Confirm it appears in Unfiled, move it to a folder, add notes, open the embedded player, and try Export backup. Share the same post again to check that it is not duplicated. If a post cannot play inside the app, try Open in TikTok.

Suggested **review notes** (replace the bracketed item with a real public, usable sample link):

> No account or login is needed. Paste [PUBLIC_TIKTOK_VIDEO_URL] on the library screen or use TikTok's Share → More → Save to yarms extension. Yarms saves links and notes locally; it does not save video files. It loads TikTok's documented embed player and oEmbed metadata. A post may become unavailable outside Yarms; Open in TikTok is the fallback. The privacy policy is available from the app's Privacy policy toolbar button.

Use a post you are permitted to share, verify it on the actual submitted build, and replace it if unavailable. Do not place a personal library, private video, or backup in review notes. Apple [may request authorization](https://developer.apple.com/app-store/review/guidelines/#legal) for third-party site and service use; TikTok documents the [embed player](https://developers.tiktok.com/docs/en/embed-player). Documentation of the player does not itself resolve every service-terms question.

The project declares `ITSAppUsesNonExemptEncryption = NO` for the current use of Apple's operating-system encryption. Review the processed build and answer [Apple's export compliance questions](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/) truthfully; if the app later adds nonexempt cryptography, change the declaration and supply any required documentation. Before filling App Privacy answers, inspect what the embedded TikTok web content and thumbnail hosts collect. Local library storage does not imply anonymous playback. The native privacy manifest records the audited required-reason API use; it does not replace App Store Connect's privacy answers or the public policy.

## Invite one external tester

1. In **TestFlight**, create an internal testing group and add your own account and processed build. Install it through TestFlight and repeat the Share extension, duplicate, live player, backup, and privacy-policy checks on your iPhone.
2. Create an **External Testing** group, add the processed build, provide **What to Test**, and choose **Submit Review**. Apple says the first submitted build gets full TestFlight App Review; later builds for the same version may not. If rejected, read the beta review details, correct the issue, increment the build number, and resubmit. [External tester steps](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)
3. After approval, invite your girlfriend **by email** to that external group. She installs Apple's TestFlight app and accepts the invitation on an iPhone with iOS 18 or newer. An email invitation keeps this one-person test private; a public link can be forwarded by anyone who receives it.
4. Check her first install with a real share, import, player, and backup. TestFlight builds [expire after 90 days](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/), so upload a newer build before expiry if she should keep testing. Keep the TestFlight build number higher for each upload.

Completing external TestFlight review does not submit the app to the public App Store. Do not press the separate App Store release submission controls unless you intend a public release.
