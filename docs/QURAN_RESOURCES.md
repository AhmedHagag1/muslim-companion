# Quran resources

## Quranic Arabic Corpus investigation

Quranic Arabic Corpus 0.4 morphology was investigated for Word-by-Word V1 but
was **not bundled**. The official download notice permits attributed verbatim
application use while the official FAQ separately limits research data to
non-commercial research. This ambiguity fails the production redistribution
gate. Exact evidence and the required rights clarification are recorded in
`QURAN_WORD_STUDY.md`.

Verified snapshot date: **2026-08-14**.

## Canonical Quran

- Asset: `assets/quran/quran-uthmani.txt`
- Provider: Tanzil Project, Uthmani 1.1
- License: CC BY 3.0 with verbatim distribution and attribution
- Topology: 114 surahs, 6,236 ayahs
- SHA-256: `829083F684ECB5C71853029CA1970946A12C2DC90528D6E0E3CD6DBC41204B7C`

This is the application's only bundled Quran text. It was not edited by the
Search & Study milestone. Search normalization is transient and displayed
Quran text always comes from `QuranRepository`.

## Installed QuranEnc study pack

The app bundles three non-Quran study resources from QuranEnc.com. The source
API also returns an `arabic_text` field; the importer deliberately omits that
field so the package cannot acquire a second Quran text.

| Resource | QuranEnc key | Version | Records | Non-empty | SHA-256 |
|---|---|---:|---:|---:|---|
| English Translation — Rowwad Translation Center | `english_rwwad` | 1.0.19 | 6,236 | 6,236 | `392383BD183650095A51D3E5F4869B407E98BA15F6A44422FA656CA7C8BE05DF` |
| Arabic At-Tafsir Al-Muyassar | `arabic_moyassar` | 1.0.0 | 6,236 | 6,236 | `F090A37DB4248D247E6FB8800C7E26A2E566C30D6B47A34E42E4FC3F9384DC76` |
| Arabic word meanings — As-Siraj | `arabic_seraj` | 1.0.0 | 6,236 | 3,648 | `348420D9810F3EF158C56835042E454FB3C06D47C090B681D6D149BC61E3D14F` |

Blank word-meaning records are retained as source facts; the app does not fill
them with generated or inferred religious content. Full provenance, rights,
import and update policy is in `QURAN_STUDY_RESOURCES.md`.

## Integrity and activation

`assets/quran_study/manifest.json` pins every asset, byte size, version,
publisher, retrieval date, record counts and SHA-256. Runtime loading rejects
unsupported schema, checksum mismatch, wrong count, duplicate/invalid Quran
coordinates, unexpected resource types and a manifest that enables remote
activation.

Remote resource activation is disabled. A future implementation must require
a signed manifest, publisher-authenticity verification, payload checksum,
atomic activation/rollback and downgrade protection before it may replace a
bundled resource.

## Search safety boundary

Universal search retrieves canonical Quran, verbatim installed study text and
local user/content records. It does not call an LLM, synthesize Tafsir, produce
a fatwa or alter Quran text. Quran, translation, Tafsir and word meanings remain
visually labeled and route to their exact surah/ayah coordinate.
# Integrity re-verification — 2026-08-25

The canonical `assets/quran/quran-uthmani.txt` was re-hashed before and after the release-candidate changes as `829083F684ECB5C71853029CA1970946A12C2DC90528D6E0E3CD6DBC41204B7C`. No canonical Quran, QuranMetadata, or verified study resource was modified.
