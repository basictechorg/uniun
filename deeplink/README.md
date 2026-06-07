# Deep-link domain verification files (`www.uniun.in`)

These two files prove to Android and iOS that the UNIUN app is allowed to open
`https://www.uniun.in/...` links directly (instead of the browser). They are **not** part of the
Flutter build — they live here only so you can host them yourself on the `www.uniun.in` web server.

| File | Platform | Must be served at |
|------|----------|-------------------|
| `.well-known/assetlinks.json` | Android (Digital Asset Links) | `https://www.uniun.in/.well-known/assetlinks.json` |
| `.well-known/apple-app-site-association` | iOS (Universal Links / AASA) | `https://www.uniun.in/.well-known/apple-app-site-association` |

The app is already configured for this host:
- Android: `android/app/src/main/AndroidManifest.xml` intent-filter `android:host="www.uniun.in"` (`autoVerify="true"`).
- iOS: `ios/Runner/Runner.entitlements` → `applinks:www.uniun.in`.
- Dart: `lib/core/router/deep_link.dart` → `kDeepLinkHost = 'www.uniun.in'`.

## Before hosting: fill in the Android fingerprint

`assetlinks.json` ships with a placeholder `REPLACE_WITH_YOUR_SHA256_FINGERPRINT`. Replace it with
the SHA-256 fingerprint of the certificate that signs the app:

- **Debug / testing builds** (the release build currently signs with the debug key):
  ```bash
  keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey \
    -storepass android -keypass android
  ```
  Copy the `SHA256:` line (the colon-separated hex, e.g. `AB:CD:...:EF`).

- **Production (Google Play)**: Play Console → your app → **Test and release ▸ App integrity ▸
  App signing** → copy the **SHA-256 certificate fingerprint** of the *app signing key*.

You can list more than one fingerprint in the `sha256_cert_fingerprints` array (e.g. debug + Play),
so the same file works for both test and production installs:
```json
"sha256_cert_fingerprints": ["AB:CD:...:DEBUG", "12:34:...:PLAY"]
```

The iOS file (`apple-app-site-association`) needs no fingerprint — it uses the App ID
`XCM437ST6L.com.basictech.uniun` (Team ID + bundle ID), which is already filled in.

## Hosting rules (all required, or verification silently fails)

1. **Exact paths over HTTPS.** Both files must be reachable at the `/.well-known/...` URLs above. A
   valid TLS certificate is required (no self-signed).
2. **`Content-Type: application/json` for BOTH.** The Apple file has **no file extension** but must
   still be returned as JSON — configure your server's MIME type so
   `apple-app-site-association` is served as `application/json` (not `text/plain` or `octet-stream`).
3. **Static files, no SPA fallback.** If `www.uniun.in` is a single-page app, exclude
   `/.well-known/*` from the catch-all that returns `index.html`. The fetchers expect raw JSON.
4. **No redirects.** The URLs must return **HTTP 200 directly**. iOS does not follow 3xx redirects
   for AASA, and redirects are unreliable for Android verification too.

### Example: Nginx
```nginx
location = /.well-known/assetlinks.json {
    default_type application/json;
    alias /var/www/uniun/.well-known/assetlinks.json;
}
location = /.well-known/apple-app-site-association {
    default_type application/json;
    alias /var/www/uniun/.well-known/apple-app-site-association;
}
```

## Verify after hosting

```bash
curl -i https://www.uniun.in/.well-known/assetlinks.json
curl -i https://www.uniun.in/.well-known/apple-app-site-association
```
Both should return `200` with `Content-Type: application/json`.

- **Android validator:** https://developers.google.com/digital-asset-links/tools/generator
- **Apple AASA validator:** https://app-site-association.cdn-apple.com/a/v1/www.uniun.in
  (Apple's CDN; may take time to refresh after you publish changes.)

### On-device checks
- **Android:** after installing the app, `adb shell pm get-app-links com.basictech.uniun` should
  show `www.uniun.in: verified`. Then
  `adb shell am start -a android.intent.action.VIEW -d "https://www.uniun.in/user/<npub>"`
  should open the app.
- **iOS:** tap a `https://www.uniun.in/channel/<id>` link from Notes/Messages → the app opens. iOS
  fetches AASA at install time and caches it; delete + reinstall to force a refresh.

> Reminder (iOS, one-time): enable the **Associated Domains** capability for App ID
> `com.basictech.uniun` (Team `XCM437ST6L`) in the Apple Developer portal and regenerate the
> provisioning profile, otherwise the `applinks:www.uniun.in` entitlement won't be valid at signing.
