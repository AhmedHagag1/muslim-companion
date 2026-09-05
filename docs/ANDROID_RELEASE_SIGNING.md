# Android release signing

Release artifacts intentionally fail when production signing is absent. The app must never ship with Flutter's debug key.

1. Ahmed Haggag creates an upload keystore outside this repository:

   `keytool -genkeypair -v -keystore muslim-companion-upload.jks -alias muslim-companion-upload -keyalg RSA -keysize 4096 -validity 10000`
2. Create `android/key.properties` locally with `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`.
3. Use an absolute keystore path or a path relative to `android/app` and run `flutter build appbundle --release`.
4. Verify the certificate fingerprint with `keytool -list -v`, archive it with the publisher's recovery procedure, and enroll in Play App Signing during the real store setup.

`key.properties`, `*.jks`, and `*.keystore` are ignored. No passwords or private keys belong in CI. A future release workflow should inject protected files and values from the publisher's secret store.

Use Google Play App Signing: Google protects the app-signing key while Ahmed retains the replaceable upload key. Keep two encrypted backups in separate controlled locations, store passwords in a password manager, record certificate fingerprints, and define recovery ownership. Never email or attach the keystore to GitHub releases.

Identity is final as `com.ahmedhaggag.muslimcompanion`. Remaining owner steps are keystore creation/custody, Play Console enrollment, recovery contacts and signed-artifact verification.
