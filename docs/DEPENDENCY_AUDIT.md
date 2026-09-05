# Dependency audit — 2026-08-26

`flutter pub outdated` reports three direct packages with newer resolvable releases: `file_picker` 12.1.0, `flutter_device_compass` 2.2.0 and `hijri_core` 1.1.0. No mass upgrade was performed in the final release pass because all touch native/file, sensor or date behavior and require focused regression/device review. Fourteen transitive packages are lockfile-held behind current constraints.

Native elevated-capability plugins include geolocation, compass, notifications, audio/background media, file picker and sharing. Review their merged manifests and advisories with each update. Current Android builds warn that `flutter_timezone` still applies the Kotlin Gradle Plugin and may become incompatible with a future Flutter built-in-Kotlin release. It works now; upgrade or replacement should be tested in an isolated follow-up rather than changing the final candidate blindly.

`pubspec.lock` is retained for reproducible application builds. Dependabot is configured monthly; dependency pull requests still require human review and full CI/device checks.
