# Develop Yarms

Yarms is an iPhone app built from the checked-in [Xcode project](../Yarms.xcodeproj/project.pbxproj). Start with the [README](../README.md) for the product overview, [documentation index](README.md) for task guides, [repository map](Repository-Map.md) to find code, and [architecture](Architecture.md) for data flow. The project targets iOS 18.0 and uses Swift 5 language settings; use a Mac with an Xcode installation that includes an iOS 18 or newer SDK and an available iPhone simulator. The repository has no package-install step for the normal build.

## Get a simulator build running

1. Install and open Xcode once to complete its first-run setup and install an iPhone simulator if needed. Clone the repository and open `Yarms.xcodeproj` in Xcode. For command-line builds, check `xcodebuild -version`; if it resolves to Command Line Tools instead of the installed Xcode, select Xcode in **Settings → Locations → Command Line Tools** or with `xcode-select`.
2. Select the shared **Yarms** scheme and an available iPhone simulator. Build and run it. The scheme builds the app and its embedded Share extension; its Test action includes `YarmsTests` and `YarmsUITests`.
3. For a terminal check from the repository root, run:

   ```sh
   ./scripts/verify-repository.sh
   xcodebuild -project Yarms.xcodeproj -scheme Yarms \
     -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
     CODE_SIGNING_ALLOWED=NO build
   ```

The repository verifier checks required public files, the shared scheme, project references, Keychain entitlements, extension version settings, prohibited private or generated files, local Markdown links, whitespace errors and the portable test runner's host tests. It needs `python3` and Git. Run `python3 scripts/test-ios.py` for the full scheme on a disposable simulator, or `--suite feedback` / `--suite sharing` for focused checks. Options, retained results, cleanup and signed-device boundaries are in [Testing](Testing.md).

## Validate Release builds and create archives

Run `python3 scripts/release-ios.py check` for an unsigned Release app and Share extension check. Use the [Release guide](Release.md) for versioned archives, local signing requirements, retained reports, and release notes. The archive command sets version and build inputs for that invocation without changing the project.

## Install on an iPhone

1. Connect the iPhone to a Mac with Xcode, open the project, and select the **Yarms** scheme and that device.
2. In **Signing & Capabilities**, select a signing team for both **Yarms** and **YarmsShare**. Keep their bundle identifiers and `YARMS_KEYCHAIN_GROUP` settings aligned with the same team. The two checked-in entitlements use `$(YARMS_KEYCHAIN_GROUP)`, whose project value is `$(AppIdentifierPrefix)com.joshuawyadao.yarms.shared` for both targets.
3. Build and run the app on the device. Open a TikTok link through the Share Sheet and choose **Save to yarms**; open Yarms to import that pending link. See the [user guide](User-Guide.md) for the rest of the flow and [Testing](Testing.md) for device checks.

The app and Share extension require a shared Keychain access group; they do not have an App Group entitlement. An unsigned simulator build does not prove that the cross-process Keychain flow works on a signed iPhone. If signing fails, check the selected team, both target signatures, provisioning, and the expanded Keychain group. If the Share Sheet entry is absent, check that the extension was embedded in the installed app, then inspect **More** in the Share Sheet. The [sharing guide](Shortcut-Sharing.md) covers the user-facing steps. Under a free Personal Team, [Apple says provisioning profiles expire seven days after issuance](https://developer.apple.com/help/account/basics/about-your-developer-account); rebuild and reinstall the app from Xcode when its provisioning expires.

Before replacing an earlier signed installation, export its backup and read [Storage Migration](Storage-Migration.md). Earlier builds may have used a different storage location. A local source build is not an App Store distribution; each device needs its own installation from Xcode.

## Change source files and project settings

Edit the checked-in project for build settings, target membership, signing, and deployment settings. Swift sources live in `YarmsApp`, `YarmsCore`, `YarmsShare`, `YarmsTests`, and `YarmsUITests`. When adding or removing a Swift file, update its target membership in Xcode or use the optional generator:

```sh
gem install xcodeproj
ruby scripts/generate-project.rb
```

The generator requires the Ruby `xcodeproj` gem. With an existing `Yarms.xcodeproj`, it updates source references for the current top-level Swift files, removes stale source references, keeps existing target identifiers, refreshes the shared scheme, and sets the app/extension display names and shared Keychain group. Its separate bootstrap path creates a new project if the project file is absent. Review its diff after running it: the checked-in project is the build input, and regenerating can change project metadata. Add resources and any unusual target settings in Xcode rather than assuming the generator discovers them.

## Before a pull request

Run the repository check, build, and relevant tests from [Testing](Testing.md). Update the focused guide when behavior, data handling, assets, or setup changes. Use invented links and records in tests and issue reports; [Contributing](../CONTRIBUTING.md) and [Security](../SECURITY.md) describe the repository's public-data rules.
