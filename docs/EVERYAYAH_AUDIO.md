# EveryAyah streamed recitation

Audit date: 2026-08-14

## Integration used by this app

The listening system streams individual ayah MP3 files from `https://everyayah.com/data`. It does not bundle, cache, download, or redistribute those recordings.

The installed repository exposes these two sources:

| Display name | EveryAyah directory |
|---|---|
| Mishary Rashid Alafasy | `Alafasy_128kbps` |
| Abdul Basit Murattal | `Abdul_Basit_Murattal_64kbps` |

Each stream URL has the form:

```text
https://everyayah.com/data/{reciter-directory}/{SSS}{AAA}.mp3
```

`SSS` is the zero-padded canonical Surah number and `AAA` is the zero-padded canonical ayah number. A Surah queue is a sequence of these per-ayah URLs; the player does not manufacture a continuous Surah duration. A lightweight request is used when resolving a single ayah to distinguish an unavailable source from an ordinary playback failure.

## Rights boundary

EveryAyah service availability does not by itself establish permission to redistribute recordings. The repository currently has no verified record of the applicable service terms, recording ownership, reciter-specific licence, attribution requirements, permanent availability commitment, or permission to package/download/redistribute these files.

For that reason Listening V2 is streaming-only. Offline downloads, cached redistribution, or bundling must remain disabled until the exact recordings and provider terms have been reviewed and documented. Any later offline milestone must retain the applicable notices, verify source hashes/manifests, define storage and removal behavior, and avoid implying rights that have not been granted.

