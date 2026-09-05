# GitHub release checklist

- Create the repository under Ahmed Haggag's account/organization and choose the source-code licence deliberately.
- Review the content licence matrix before making the repository public.
- Push a clean default branch; enable secret scanning, push protection and Dependabot.
- Protect the branch: pull requests, review, required Flutter CI, no force-push/deletion.
- Verify public files contain no local configuration, backups, logs, credentials or signing material.
- Add the real repository URL to About/README only after it exists.
- Create `v1.0.0` only after the signed store artifact and release notes are final.
- Attach signed distributable artifacts only when appropriate; never attach a keystore or `key.properties`.
