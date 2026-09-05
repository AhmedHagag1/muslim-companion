# Threat model

Scope: Muslim Companion V1 local Flutter client. No backend, account, analytics, ads, cloud sync, or AI provider exists.

| Threat | Asset at risk / vector | Current mitigation | Remaining risk / action |
|---|---|---|---|
| Malicious or malformed backup | Local preferences; crafted JSON | JSON-only picker, strict schema/version/section allowlist, Quran/page bounds, UTF-8 decode, preview, confirmation, rollback, 2 MiB and depth limits | Continue parser fuzzing; do not add dynamic object construction |
| Path traversal/file picker abuse | Local filesystem | Picker returns user-selected JSON bytes; app never uses embedded paths or executes content | Re-audit plugin updates and platform provider configuration |
| Malicious deep link/URI | Navigation/actions | Parser accepts relative allowlisted paths only; rejects schemes, hosts, unknown routes and invalid coordinates | No external domain is registered; keep disabled until domain ownership exists |
| Exported component abuse | Android activities/services/receivers | Explicit exported attributes; notification receivers are non-exported; media exports are plugin-required | Audit merged release manifest and audio_service upgrades |
| Notification intent abuse | Route/state changes | Typed local payload parser and bounded destinations | Fuzz malformed payloads after notification plugin upgrades |
| FileProvider exposure | Shared files | No app-declared FileProvider or broad path XML; share/file-picker plugins mediate access | Inspect merged manifests and temporary-file lifetime |
| Cleartext/MITM | Prayer/audio requests | HTTPS endpoints; Android cleartext disabled; standard platform PKI | Third-party service compromise remains; brittle certificate pinning intentionally absent |
| Compromised resource pack | Religious text integrity | Bundled manifests, byte size, SHA-256, schema/count/coordinate checks; remote activation disabled | Hashes do not authenticate an attacker who can alter code and manifest; future updates require signed manifests |
| Signing-key exposure | Release ownership | No key in repository; ignored key files; release fails without explicit configuration | Ahmed must use secure offline custody, recovery copy, rotation plan and Play App Signing |
| API/AI key leakage | Public APK/repository | No credentials/provider; secret scan and ignore rules | Future provider secrets must live behind a backend/proxy, never in Flutter or CI logs |
| Sensitive logging | Location, backups, bookmarks, memorization | User UI hides raw exceptions; diagnostic prints are debug-gated | Continue release log review and avoid payload logging |
| Location privacy | Exact coordinates sent to AlAdhan | Permission-gated feature; coordinates excluded from backups/Ask | Disclose third-party processing and retention uncertainty; consider local-only prayer calculation option |
| Supply chain | Native/pub/Actions compromise | Lockfile, minimal CI permissions, Dependabot, serial tests | Review update diffs/advisories; `flutter_timezone` has a future Kotlin compatibility warning |
| Prompt injection | Future external AI/retrieval | No provider exists; current sources are bundled and verified | Future AI must use source allowlists, data minimization, untrusted-content boundaries and action allowlists |
