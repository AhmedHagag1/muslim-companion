# iOS release readiness

Configuration audit only; no macOS/Xcode/iPhone acceptance was possible in this Windows workspace.

- Display name is رفيق المسلم; bundle ID is `com.ahmedhaggag.muslimcompanion`.
- No development team, distribution certificate, provisioning profile, App Store record, or production entitlements are supplied.
- Background audio mode is declared. Location permission descriptions are missing and must be added before exercising location on iOS.
- Branded app icons exist but require Xcode/App Store validation.
- Notification, timezone, file picker/share, background audio, privacy manifests, and restore flows require an actual iOS build and device pass.

Status: blocked, not physically accepted.
