# Fixed-layout Madani Mushaf resource research

Audit date: 2026-08-14

## Outcome

No researched resource currently passes all five mandatory implementation gates:

1. explicit primary-source provenance;
2. permission to redistribute the exact assets inside an application;
3. a precisely identified Mushaf edition/version;
4. complete 604-page coverage; and
5. deterministic mapping from every rendered unit back to canonical Surah/Ayah coordinates.

Fixed-layout implementation therefore stopped before any font, glyph, vector, image, or layout package was added. The existing renderer remains **PARTIAL**. It provides correct 604-page boundaries and complete canonical ayah coverage, but it reflows Unicode text and is not a printed-page facsimile.

This is a resource-rights and data-contract blocker, not a Flutter rendering blocker. QCF V2 plus line/word metadata is technically sufficient. The available publications do not provide a verified right to ship that complete offline bundle in this app.

## Current repository baseline

- `assets/mushaf/madina_page_boundaries.json` is a 30,067-byte derivative of Tanzil's CC BY metadata. It contains 604 page starts, 30 Juz starts, and 240 Hizb-quarter starts; SHA-256 `CB9AF615681C6A677B743EB180150A62A8F54D1AB1836A304D35AF6658EDA15E`.
- `assets/quran/quran-uthmani.txt` remains the only canonical Quran text. It was not modified. Its protected SHA-256 is `829083F684ECB5C71853029CA1970946A12C2DC90528D6E0E3CD6DBC41204B7C`.
- `MushafPageView` lazily builds pages with `PageView.builder`, maps all 6,236 canonical ayahs exactly once, and keeps page progress separate from Study Mode.
- Page width currently changes Flutter text wrapping. Line breaks and word placement therefore are not fixed.
- Existing ayah taps, long-press actions, bookmarks, progress, and audio highlighting are correct for the reflowed spans, not for printed glyph positions.

## Candidate audit

Unknown values are stated as unknown; they are not inferred from a repository's software license.

| Candidate | Primary/original source and version | Edition / coverage | License and app redistribution | Mapping | Flutter, offline, and size | Gate result |
|---|---|---|---|---|---|---|
| Tanzil Quran metadata v1.0 | [Tanzil metadata documentation](https://tanzil.net/docs/Quran_Metadata) | Medina page-boundary metadata; 604 page starts. No fixed line composition. | CC BY 3.0; attribution and source link required. Redistribution of the metadata derivative is allowed. | Page/Juz/Hizb starts map to Surah/Ayah. No line, word, glyph, or hit-box data. | Fully offline; checked-in derivative is 30,067 bytes; simple Dart parsing. | **Passes only the boundary role.** Fails fixed-layout and printed hit-testing requirements. |
| Tanzil Uthmani text | [Tanzil text license](https://tanzil.net/docs/Text_License) | Unicode Uthmani text, 114 Surahs / 6,236 ayahs; no page geometry. | CC BY 3.0; text must remain verbatim and attribution/link must be retained. | Canonical Surah/Ayah only. | Fully offline; current protected file is 1,359,946 bytes. | **Not a layout source.** Remains the canonical application identity/text. |
| KFGQPC Unicode Uthmanic Hafs packages | [KFGQPC Quran Developer Portal](https://qurancomplex.gov.sa/quran-dev/) | Official Hafs Unicode text/font packages. The portal explicitly distinguishes the smart-device font from fonts intended to reproduce a complete printed page. Published database fields include ayah-level `page`, `line_start`, and `line_end`, but not deterministic per-word line placement. | The portal promotes use in applications, but the exact downloadable font/database package does not present a package-specific redistribution license/NOTICE in the audited material. Modification and attribution terms remain unspecified. | Ayah/page and ayah line-range metadata; insufficient for word placement or exact printed glyph hit testing. | Flutter-compatible Unicode; offline package sizes published by KFGQPC are approximately 10 MB for the regular update and 21.6 MB for the smart-device update. | **Reject for fixed layout.** It is reflowable Unicode, and exact package redistribution terms are not pinned. |
| Quran Foundation QCF V2 fonts + Content API | [Font rendering guide](https://api-docs.quran.com/docs/tutorials/fonts/font-rendering/) and [page-layout guide](https://api-docs.quran.com/docs/tutorials/fonts/page-layout/) | Mushaf ID 1, QCF V2, 604 pages. The guide calls it modern Madani and pixel-perfect, but does not pin a print year/release artifact. | [Developer Terms](https://api-docs.quran.foundation/legal/developer-terms/) grant revocable API/application display rights. Raw/commercial redistribution needs a separate written license. Content normally may not be stored longer than one week unless expressly allowed or synchronized at least weekly through eligible Content Sync data. | Strong: `code_v2`, `page_number`, `line_number`, word position, and verse key permit deterministic word-to-ayah mapping. | Technically suitable for Flutter with 604 per-page fonts and line grouping. Normal use requires authenticated network/API operation; a verified distributable offline bundle and total bundle size are not published by these pages. | **Reject for this offline bundle.** Technical gates pass; redistribution/offline permanence and exact release gates fail without written QF authorization. |
| QUL KFGQPC V2 layout + QPC V2 font + word script | [KFGQPC V2 layout](https://qul.tarteel.ai/resources/mushaf-layout/10), [QPC V2 font](https://qul.tarteel.ai/resources/font/249), and [related resources](https://qul.tarteel.ai/resources/mushaf-layout/10/related_resources) | Layout page identifies a 1421H print, 604 pages, 15 lines. QUL's glyph documentation describes QCF V2 as based on a print from around 1423H, leaving the exact combined-edition relationship insufficiently pinned. | QUL says commercial use depends on each resource's specific license. These three resource pages expose downloads but no resource-specific license, redistribution grant, modification rules, or attribution terms. Tarteel's general Terms reserve service content and prohibit copying/distribution except where expressly permitted. The QUL CMS code's MIT license does not license its datasets or KFGQPC fonts. | Technically excellent: page/line records, first/last word IDs, word index/key/Surah/Ayah, QPC glyph codes, and 604 page fonts. | SQLite/JSON-style data is straightforward to import and Flutter can load per-page TTF assets lazily. Downloads require sign-in; total asset size is not published on the resource pages. | **Reject at legal gate.** Do not bundle until the exact three resources carry an explicit app-redistribution license from the rights holders. |
| KFGQPC Illustrator vector pages | [Official project](https://dm.qurancomplex.gov.sa/project-def/), [downloads](https://dm.qurancomplex.gov.sa/), [rights](https://dm.qurancomplex.gov.sa/rights/), and [technical notes](https://dm.qurancomplex.gov.sa/techinfo/) | Official complete Hafs Madinah Mushaf vector artwork, one page at a time. The audited page does not identify a release number/year precise enough to bind it to a separate canonical coordinate dataset. | Strongest legal candidate: KFGQPC explicitly permits free use in computer programs, websites, publishing, and institutional/private work inside and outside Saudi Arabia. Commercial paper printing in/import into Saudi Arabia has a separate restriction. No app attribution requirement is stated. | Illustrator paths have no published word/ayah IDs, reading order, semantic text, or hit geometry tied to canonical coordinates. Page-range boundaries alone cannot make printed text tappable. | Fixed and scalable after an AI-to-runtime-vector conversion pipeline, but Flutter cannot render AI directly. Conversion may constitute modification and needs a validation policy. Download size is not published on the page. Accessibility would require a separate verified overlay. | **Reject for this interactive renderer.** Legal use passes, but exact edition binding and deterministic glyph/ayah mapping fail. |
| Fixed page images from Quran for Android ecosystem | [quran/quran_android](https://github.com/quran/quran_android) | Image sets can cover Madani pages; exact set/version depends on the selected data package. | GPL-3.0 covers code. Its README says data licenses vary and are commonly CC BY-NC-ND, and discourages profit/commercial use of hosted data. That does not establish rights for this app. | Some ecosystem packages include ayah bounds, but no exact image-plus-bounds package with a passing license was verified. | Easy Flutter image rendering and predictable layout, but high storage/memory, reduced zoom quality, and accessibility requires semantic overlays. Asset size is package/resolution dependent and was not verified. | **Reject.** No exact legally redistributable image/bounds pair was verified. |
| Quran.com image/font generator | [quran/quran.com-images](https://github.com/quran/quran.com-images) | Generates old Madani/QCF pages and can emit glyph bounds. | GPL applies to generator code; the repository states the QCF fonts/pages belong to KFGQPC. The code license does not grant asset redistribution. | Technically capable of word/ayah bounds if supplied the original fonts/data. | Server-side generator, not a direct Flutter runtime. Output size depends on resolution/format. | **Reject.** Upstream asset rights remain unresolved. |
| `quran_library` Flutter package | [alheekmahlib/quran_library](https://github.com/alheekmahlib/quran_library) | Advertises Madina-style 604-page rendering using QUL/QCF resources. | MIT covers package code. Its NOTICE sends font/data users back to QUL and upstream KFGQPC terms; it cannot supply missing content rights. | Advertises page/ayah/word APIs and highlighting. | Flutter-compatible but duplicates existing reader/audio/bookmark architecture. Asset size depends on downloaded QCF files. | **Reject as a rights shortcut.** It is an implementation reference, not an original asset license. |
| Amiri Quran | [Official Amiri repository](https://github.com/aliftype/amiri) and release `1.003` | Unicode Naskh font tailored for Quran text; not a page-specific Madani/QCF layout. | SIL Open Font License 1.1 permits use, modification, and redistribution under its terms. The font embeds the OFL identification and URL. | Normal Unicode shaping only; no page/line/word placement data. | Excellent Flutter/HarfBuzz compatibility. Local file is 167,976 bytes; official `Amiri-1.003.zip` is 1,033,533 bytes and its released `AmiriQuran.ttf` is 136,920 bytes. | **Valid Study/reflow font, not a fixed-layout source.** See provenance audit. |

## Licensing conclusions

### Quran Foundation

The QCF V2 API is the cleanest technical contract. It has 604 pages, per-page fonts, word glyph codes, line numbers, page numbers, and canonical verse keys. However, the current Developer Terms are not an unconditional asset redistribution license. They limit storage to one week unless a specific exception applies, require ongoing sync for eligible offline content, reserve raw/commercial redistribution for a separate written agreement, and terminate retained rights when API access terminates. That is incompatible with silently checking a permanent font/data snapshot into this offline app.

### QUL / Tarteel

The QUL combination is also technically complete, but the precise layout, font, and script pages do not identify their own licenses. QUL's FAQ explicitly tells implementers to review dataset-specific terms. An MIT license on the Rails CMS or a downstream Flutter package does not transfer rights in KFGQPC-derived fonts/content. General permission to download or use data commercially is not the explicit right to redistribute this exact three-part bundle.

### KFGQPC vector pages

The official rights page explicitly allows computer-program use, so these files are not rejected for lack of general app permission. They are rejected because fixed artwork alone cannot satisfy the interactive product contract: there are no primary-source canonical word/ayah IDs, bounds, or semantic reading-order records. Generating those mappings with OCR or visual approximation would violate the deterministic mapping gate and would not be an acceptable Quran correctness mechanism.

## AmiriQuran.ttf provenance audit

- Repository file: `assets/fonts/AmiriQuran.ttf`
- Size: 167,976 bytes
- SHA-256: `8FA95FAAF7BD18B71789F6F57312003E30C5029218A035E5BAF613A0222AB82D`
- Embedded family/PostScript name: `Amiri Quran` / `AmiriQuran-Regular`
- Embedded version and unique ID: `Version 1.003` / `1.003;ALIF;AmiriQuran-Regular`
- Embedded manufacturer/designer: Alif Type / Khaled Hosny
- Embedded license: SIL Open Font License 1.1, with `https://openfontlicense.org`
- Verified upstream release: [Amiri 1.003](https://github.com/aliftype/amiri/releases/tag/1.003), release archive SHA-256 `81AF0AFF7D2086D8AF24CEA7202F7546130997982534691373485CD96744D05E`.
- Official released `AmiriQuran.ttf`: 136,920 bytes, SHA-256 `E2A47644762D16BDFB6D33E0D8DB8C6FF30BEAE84150EF5A705316BBD829455C`.

The local font is conclusively identifiable as Amiri Quran 1.003 and carries its OFL metadata, but it is not byte-for-byte the published release artifact. Table inspection shows identical checksums and lengths for the functional `cmap`, glyph outlines, metrics, GDEF, GPOS, and GSUB tables. Differences are confined to the `name` table and an unstripped glyph-name `post` table. This strongly indicates an unstripped 1.003 build, but it does not prove the exact download/build origin.

The file was not replaced in this milestone. Replacing it is not needed to solve fixed layout, and the hard gate stopped runtime changes. Before distribution, pin the official 1.003 artifact, retain its `OFL.txt`, and run visual/golden comparison. That replacement should not change shaping or glyph geometry based on the verified table checksums, but it still deserves explicit rendering validation.

## What would clear the blocker

Any one of these evidence packages would permit implementation to restart:

1. A written license from Quran Foundation/KFGQPC/Tarteel explicitly authorizing permanent offline redistribution of the exact QCF V2 604-font set, glyph script, and line/word layout data in mobile applications, with version, attribution, and modification terms.
2. An official KFGQPC release that combines the redistributable fixed artwork with canonical word/ayah IDs, bounds, and reading order for all 604 pages.
3. Another primary-source 604-page Madani dataset carrying an explicit app-redistribution license and complete canonical coordinate mapping.

After rights are cleared, record source archives and hashes, retain license/NOTICE files, validate all 604 pages and all 6,236 canonical coordinates, and implement models only from the resource's actual schema. Until then, no visually similar or width-wrapped surface may be described as a true fixed-layout Mushaf.
