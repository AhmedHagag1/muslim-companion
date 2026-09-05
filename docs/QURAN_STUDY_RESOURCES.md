# Quran Study Resources — QuranEnc snapshot

Review and import date: **2026-08-14**.

## Rights gate

Only the primary QuranEnc source was accepted. QuranEnc's published Terms and
Policies permit translation contents to be downloaded and republished when the
content is not modified, the publisher and QuranEnc are identified, the
version and transcript information are retained, source feedback and updates
are respected, and inappropriate advertising is not placed with the content.

Official references used during the review:

- Home/catalog and resource metadata: `https://quranenc.com/en/home`
- Official API documentation: `https://quranenc.com/en/home/api`
- API pattern: `https://quranenc.com/api/v1/translation/sura/{key}/{surah}`
- Published terms are displayed by QuranEnc on its catalog/browse pages.

No downstream GitHub mirror, rendered-page scraper or repository-level
software license was used as evidence for the religious text.

## Installed sources

### English translation

- Key: `english_rwwad`
- Title: English Translation — Rowwad Translation Center
- Publisher/transcript: Rowwad Translation Center with the Rabwah Dawah
  Association, Islamic Content Service Association in Languages and
  IslamHouse.com
- Version: 1.0.19
- Source update: 2026-03-12
- Payload: 6,236 non-empty verse-coordinate records; footnotes retained

### Arabic Tafsir

- Key: `arabic_moyassar`
- Title: At-Tafsir Al-Muyassar
- Publisher: King Fahd Complex for Printing the Holy Quran in Madinah
- Version: 1.0.0
- Catalog date: 2017-02-15
- Payload: 6,236 non-empty verse-coordinate records; footnotes retained

### Arabic word meanings

- Key: `arabic_seraj`
- Title: Arabic Language — Meanings of Words
- Source work: *As-Siraj fi Bayan Gharib Al-Quran*
- Version: 1.0.0
- Source update: 2025-12-17
- Payload: 6,236 coordinates, of which 3,648 contain text

The Arabic resource metadata is recorded from the official QuranEnc catalog;
the current translation-list endpoint does not enumerate these Arabic keys,
but the official per-surah API endpoints do serve them.

## Reproducible import

- Importer used and validated in this workspace: `tool/import_quranenc.ps1`
- Inputs: 114 official per-surah JSON API responses for each pinned key
- Outputs: one compact JSON payload per resource plus a versioned manifest
- Encoding: UTF-8 without BOM

The importer copies `translation` and non-empty `footnotes` verbatim. It does
not normalize, correct, translate, summarize or combine the source. It omits
QuranEnc's `arabic_text` field because the app already has one protected
canonical Quran. It fails unless each resource has exactly 6,236 unique,
in-range coordinates. The app repeats coordinate, count, size and SHA-256
validation before activating the bundled data in memory.

## User-visible attribution

Verse Study labels translation, Tafsir and word meanings separately and shows
publisher, QuranEnc, version and the verbatim-source notice. Settings lists all
installed resources and exposes publisher, source, version, source date,
record count and SHA-256. Empty As-Siraj records are described as having no
independent meaning in the source; no replacement text is generated.

## Update architecture

The manifest has `remoteActivation.enabled: false`. Remote update support is
not represented by a non-functional download button. Before future activation,
the product must implement all of the following as one gate:

1. a signed manifest rooted in a trusted publisher key;
2. publisher and resource-key authenticity verification;
3. pinned schema, size, SHA-256, count and Quran-coordinate validation;
4. staged storage and atomic activation with last-known-good rollback;
5. version monotonicity and explicit downgrade/replay protection; and
6. updated user-visible attribution and terms metadata.

Until that gate exists, updates require a reviewed source snapshot, importer
run, automated validation and a normal signed application release.
