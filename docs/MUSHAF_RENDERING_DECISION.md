# Fixed-layout Mushaf rendering decision

Decision date: 2026-08-14  
Status: **STOPPED AT RESOURCE GATE — MUSHAF REMAINS PARTIAL**

## Decision

Do not implement or bundle a fixed-layout renderer in this milestone.

No candidate simultaneously provides explicit provenance, app redistribution permission, an exact edition, all 604 pages, and deterministic canonical Surah/Ayah mapping. Runtime code, domain models, Quran content, and the current rendering path remain unchanged.

The current Mushaf surface is a 604-page reflow foundation. It is not a fixed-layout Madani Mushaf: device width can change line composition. Study Mode remains the dedicated reflowing ayah reader. Neither surface is being re-labelled as a true printed-page renderer.

Full source and license evidence is in [MUSHAF_RESEARCH.md](MUSHAF_RESEARCH.md).

## Mandatory gate scorecard

| Candidate | Provenance | Redistribution | Exact edition | 604 pages | Canonical mapping | Result |
|---|---:|---:|---:|---:|---:|---|
| Quran Foundation QCF V2 fonts/API | Pass | **Fail for permanent offline bundle without separate written grant** | Partial | Pass | Pass | Rejected |
| QUL V2 layout + font + word script | Pass | **Fail: no resource-specific redistribution license shown** | Partial/conflicting 1421H vs around 1423H descriptions | Pass | Pass | Rejected |
| KFGQPC Illustrator vector pages | Pass | Pass for program use | Partial: no pinned release/version tied to mappings | Pass as complete artwork | **Fail: no word/ayah IDs or bounds** | Rejected |
| KFGQPC Unicode packages | Pass | Partial/unspecified package terms | Package version exists, but it is not a fixed print layout | Pass as Quran text, not 604 fixed pages | Ayah/page ranges only | Rejected |
| Quran for Android image/data ecosystem | Indirect/package-dependent | Fail/unknown for exact assets | Unknown until a package is selected | Package-dependent | Package-dependent | Rejected |

## Strategy comparison

| Strategy | Fidelity | Hit testing and canonical mapping | Accessibility | Audio highlight | Size and performance | Licensing / offline assessment |
|---|---|---|---|---|---|---|
| **A. QCF per-page glyph fonts** | Best. QCF V2 is designed for pixel-faithful Madani line composition; page scales as a unit when rendered in fixed logical geometry. | Best when word records carry `code_v2`, page, line, position, and verse key. Glyph spans can map directly to canonical coordinates. | Requires an ordered semantics layer using canonical Unicode text because private-use glyph codes are not meaningful to screen readers. | Per-word/per-ayah decoration can change paint only, never layout. | 604 fonts require lazy loading, a small page/font cache, adjacent-page prefetch, and measured memory. Published total bundle size was not verified. | **Preferred technical design, blocked legally.** QF terms do not permit a permanent checked-in snapshot by default; QUL resource-specific rights are missing. |
| **B. Structured line/glyph dataset** | Excellent when paired with the exact font/edition. Explicit line membership prevents arbitrary wrapping. | Excellent. Word IDs and first/last word per line support deterministic tap regions and canonical joins. | Strongest option: semantics can follow word/ayah reading order independently of visual glyphs. | Straightforward immutable-layout span decoration. | Small structured data plus fonts; SQLite/compact binary can be loaded page-wise. QUL download sizes are not published before authenticated download. | Technically preferred alongside A, but the exact QUL dataset/font/script bundle has no verified redistribution grant. |
| **C. Fixed SVG/vector pages** | Excellent and resolution-independent. Whole-page scaling naturally preserves composition. | Poor without authoritative element IDs/bounds. KFGQPC AI pages expose artwork, not canonical semantic mappings. | Requires a separately verified overlay; vector path order is not a Quran reading-order contract. | Requires exact canonical bounds; otherwise only unsafe page-level highlight is possible. | Potentially larger parse/raster cost; AI must be converted to a Flutter-supported vector/raster format and cached. Official download size is unpublished. | KFGQPC's rights page permits computer-program use, but deterministic coordinate mapping and a pinned mapped edition are absent. |
| **D. Fixed page images** | Exact at source resolution, but zoom can reveal raster limitations. | Requires a matching authoritative bounds dataset; image pixels alone are not tappable Quran coordinates. | Weak unless a full semantic overlay is supplied. | Overlay rectangles/polygons can work only with verified bounds. | Simple lazy rendering, but generally highest storage and decoded-memory cost; resolution trade-offs apply. | No exact image-plus-bounds package with acceptable app redistribution rights was verified. |

## Preferred implementation if the gate is cleared

The preferred production architecture is **A + B**: QCF V2 per-page fonts plus its exact structured word/line dataset.

The conditional design would be:

- fixed logical page coordinates and 15 fixed line slots;
- one lazily loaded page font and page record at a time, with adjacent-page prefetch and a bounded cache;
- immutable `MushafPage`, `MushafLine`, and resource-backed word/glyph-span records;
- canonical `(surahNumber, ayahNumber, wordIndex)` identity retained on every visual span;
- whole-page `FittedBox`/transform scaling so screen width changes scale, never wrapping;
- paint-only selected/playing decorations;
- hit testing over measured glyph spans mapped to canonical ayahs;
- a separate ordered semantic overlay containing canonical Unicode Quran text;
- existing canonical bookmarks, audio controller, memorization actions, and Study Mode reused by coordinate;
- an explicit resource-error state, never a silent reflow fallback labelled as fixed Mushaf.

This is a design decision, not implemented code.

## Current behavior and limitations

- Page coverage: 604 boundary-defined pages.
- Coordinate coverage: all 6,236 ayahs exactly once.
- Line composition: **not fixed**; Flutter wraps canonical Unicode spans within each page.
- Hit testing: accurate at reflowed ayah-span level only.
- Accessibility: reflowed Quran text remains available to normal Flutter semantics; no fixed-page semantic overlay exists.
- Audio highlight: works on reflowed ayah spans and can alter layout only insofar as existing text styling behaves; no fixed-glyph paint overlay exists.
- Performance: `PageView.builder` preserves lazy page widget construction. The earlier test instrumentation measured approximately 471–574 ms cold layout load; no fixed-layout asset load or process-memory measurement exists because no fixed resource was admitted.

## Validation implications

The requested fixed-layout tests—unchanged line composition across scale, fixed geometry, representative printed pages, fixed-glyph hit testing, and paint-only audio highlighting—would be dishonest against the current renderer. They were not added.

The existing 97 tests must continue to pass. They verify the current 604-page boundary/mapping foundation, canonical coverage, interactions, Study Mode, theme identity, and Quran hash. A future fixed-layout implementation must add the new tests only after an admitted resource defines the expected page lines and mappings.

## Unblock checklist

Before runtime work starts, obtain and archive:

- a rights-holder license naming every font, layout, and script artifact and explicitly permitting mobile-app/offline redistribution;
- exact edition/print/release identifiers with immutable source URLs and archive hashes;
- all 604 page resources;
- complete line and word/glyph records with canonical Surah/Ayah/word mappings;
- attribution, modification, update, and correction requirements;
- an agreed visual-validation reference for pages 1, 2, 42 (2:255), a Surah start, Surah 9 start, and page 604.

Only then should the project add assets, models, renderer code, semantics, performance instrumentation, and fixed-layout tests.
