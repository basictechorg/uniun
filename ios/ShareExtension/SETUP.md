# iOS Share Extension — manual Xcode setup

These source files (`ShareViewController.swift`, `Info.plist`,
`ShareExtension.entitlements`) are ready, but the **Xcode target that references
them must be created by hand** — it cannot be scripted. Do this in
`ios/Runner.xcworkspace`:

1. **Create the target**: `File ▸ New ▸ Target… ▸ Share Extension`. Name it
   `ShareExtension`, bundle id `in.uniun.app.ShareExtension`, deployment target
   **iOS 16.0** (must match the Podfile). When asked to activate its scheme, click
   **Cancel** (keep the Runner scheme).
2. **Replace the generated files** with the ones already in this folder
   (`ShareViewController.swift`, `Info.plist`). Delete Xcode's auto-generated
   `MainInterface.storyboard` (not needed — `RSIShareViewController` has no UI).
3. **App Group on BOTH targets**: select `Runner` and `ShareExtension` →
   `Signing & Capabilities ▸ + Capability ▸ App Groups` → add `group.in.uniun.app`
   to each. The entitlements files in this folder and `Runner/Runner.entitlements`
   already declare it; make sure Xcode points each target's
   `CODE_SIGN_ENTITLEMENTS` at the right file.
4. **Signing/provisioning**: the extension is a new signing identity. With team
   `A86M9D5A43` and automatic signing, run once with
   `xcodebuild -allowProvisioningUpdates` so a profile is generated for
   `in.uniun.app.ShareExtension`. (Expect the "No profiles for …" prompt the first
   time — same class of fix as the main app.)
5. **Build Phases**: in the **Runner** target, drag **"Embed Foundation
   Extensions"** (Embed App Extensions) above the Flutter "Thin Binary" run-script
   phase, so the extension is embedded before the binary is thinned.
6. Run `flutter pub get` then `cd ios && pod install` so the
   `.symlinks/plugins/receive_sharing_intent/ios` path the Podfile references
   exists. Keep **SPM disabled** (CocoaPods only) to avoid duplicate-symbol issues.

## Warm-start caveat (SceneDelegate)

`Runner` uses `SceneDelegate.swift` (`FlutterSceneDelegate`). Cold-start share
works via the scene bridge. If a **warm-start** share (app already foregrounded)
does not surface, override `scene(_:openURLContexts:)` in `SceneDelegate.swift`
to forward the URL to the plugin, then retest. This is the most likely snag.
