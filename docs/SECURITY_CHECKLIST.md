# Release security checklist

- [ ] Run repository and Git-history secret scans; rotate and purge any historical secret.
- [ ] Review `flutter pub outdated`, advisories, lockfile changes, and native plugin permissions.
- [ ] Inspect the merged release manifest: permissions, exported activities/services/receivers/providers and FileProvider paths.
- [ ] Run backup malformed, oversized, nesting, schema, coordinate, rollback and confirmation tests.
- [ ] Run internal-route, unsafe-scheme, malformed notification and external-link rejection tests.
- [ ] Confirm every runtime endpoint is HTTPS and update privacy disclosures.
- [ ] Verify canonical Quran SHA-256 and all study/religious manifest hashes.
- [ ] Verify release certificate fingerprint and that no debug certificate signs the artifact.
- [ ] Require green CI and reviewed changes on the protected default branch.
- [ ] Install the exact final bytes, smoke-test RMX3938, pull the APK and compare it.
- [ ] Confirm no backup, local log, keystore, credentials or machine-only files are included in the publication set.
