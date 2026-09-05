# Local user-data backup format

Current format: **appBackupVersion 1**.

```json
{
  "appBackupVersion": 1,
  "createdAt": "2026-08-14T10:00:00.000Z",
  "sourceAppVersion": "1.0.0+1",
  "sections": {
    "bookmarks": {},
    "memorization": {}
  }
}
```

## Included state

The exporter uses an explicit whitelist for bookmarks, ordinary and Mushaf
reading progress, reader/display preferences, memorization, Khatma, Dua
favorites, Tasbeeh state/history, the current Adhkar session, and safe app,
prayer and Islamic Daily settings.

Quran text, Quran metadata, QuranEnc resources, Tafsir, translations, word
meanings, audio, location coordinates, search history and arbitrary preference
keys are not exported.

## Validation and restore

- The top-level version, timestamp, source version and section map are required.
- Unknown sections and unsupported section versions are rejected.
- Every discovered Quran coordinate is checked against `QuranMetadata`.
- Mushaf page values are constrained to 1–604.
- Reader mode accepts only `mushaf` or `study`.
- The UI previews included sections before restore.
- Restore replaces only sections present in the file and requires explicit
  confirmation. It never silently clears absent state.
- Existing values are retained and rolled back if a preference write fails.
- Imported data is fully reloaded on the next app launch.

Export uses the platform share sheet with an in-memory JSON file. Import uses
the platform document picker and requests no broad storage permission.
