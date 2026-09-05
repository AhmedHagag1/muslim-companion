# Security and privacy audit

The audited source uses HTTPS for AlAdhan prayer requests and EveryAyah streaming. Prayer API requests can disclose precise coordinates, calculation method, school, IP address, and date to AlAdhan; EveryAyah sees IP address plus requested reciter/ayah. The local assistant sends nothing externally and does not use an LLM.

Android components are limited to the launcher/audio-service activity, media service/receiver, and non-exported notification receivers. Exported media components are required by `audio_service`; re-check merged manifests on every plugin upgrade. No cleartext opt-in was found.

Backup import must remain JSON-only, schema/version validated, previewed, and explicitly confirmed. Sharing uses platform share/file-picker plugins; no arbitrary execution path is intended. Logs must exclude coordinates, bookmarks, backup bodies, and memorization history.

Open items: physical malformed-backup test, dependency vulnerability process, external service privacy terms, final privacy-policy/support URLs, iOS privacy manifest review, and a signed-release merged-manifest audit.

## Final closure delta — 2026-08-26

Android explicitly disables cleartext traffic. Backup import now rejects inputs above 2 MiB and structures deeper than 32 levels in addition to its prior schema/allowlist/bounds/confirmation/rollback controls. Internal routing tests reject HTTP(S), JavaScript, file, content, authority-style and traversal-like inputs. The final app ID is `com.ahmedhaggag.muslimcompanion`; exported media components remain required by audio_service and notification receivers remain non-exported.

A repository-wide pattern and sensitive-file scan found no credential, private key, keystore, service-account file or `key.properties`. Pattern hits were reviewed as documentation, design-token names or ordinary religious/translation words. No `.git` directory exists, so historical-secret inspection cannot be performed. Remaining risks include third-party service privacy/availability, dependency compromise, iOS/merged-release-manifest validation and owner signing-key custody.
