# Religious content policy and Daily Worship Content V2

## Scope

The bundled Arabic daily-worship pack is an offline, versioned resource shared by Adhkar, Duas, and Tasbeeh. It contains 51 stable content records:

- 29 Adhkar in 9 categories: morning, evening, waking, wudu, home, mosque, after prayer, sleep, and food.
- 17 Duas in 6 categories: distress, illness, travel, istikhara, rain, and food/hospitality.
- 5 selectable Tasbeeh phrases.

The manifest is `assets/religious_content/daily_worship_ar_manifest.json`; its payload is `assets/religious_content/daily_worship_ar_payload.json`. The old unversioned `assets/adhkar/adhkar.json` is no longer bundled.

## Included source and redistribution conclusion

All religious text in pack `daily-worship-ar` version `2.0.0` comes from one source:

- Book: **حصن المسلم من أذكار الكتاب والسنة**.
- Author: سعيد بن علي بن وهف القحطاني.
- Edition record: the approved Arabic edition published by IslamHouse; the book records the original compilation date as Safar 1409 AH.
- Canonical source page: `https://islamhouse.com/ar/books/2522`.
- Provenance ID: `hisn-muslim-ar-approved-1421`.
- Redistribution conclusion: the author explicitly asks Allah to benefit everyone who reads, prints, or causes the book to be published. This pack therefore republishes attributed, verbatim Arabic excerpts. This is a source-specific author permission, not a generic software/open-source license and not permission to alter the religious text.

The former GitHub dataset and its MIT software license are not treated as evidence of religious-text redistribution rights and are not used by V2.

## Included references

Each record carries the book item number and its corresponding takhrij/footnote number. Adhkar use items 1–3, 12–18, 20–21, 66–68, 77, 86–87, 91, 94, 97, 102–103, 105, 178, and 180–181. Duas use items 74, 122–125, 147–148, 169, 172, 174, 182–183, 208, 211–213, and 243. Tasbeeh selections are excerpts tied to items 91, 106, and 260.

The payload records, for every item:

- a stable ID;
- the verbatim Arabic excerpt shown to the user;
- domain category;
- repeat count only where a single count applies to that record;
- visible source and item/footnote reference;
- a provenance ID that resolves to the source, edition, URL, and redistribution conclusion.

## Editorial rules

- Never generate Dhikr, Dua, Quran text, translations, commentary, benefits, or religious rulings with an AI model.
- Add a text only after checking it against an approved source edition and recording the exact item/reference.
- Store and display Arabic text verbatim. Search normalization must operate on temporary comparison strings only.
- Do not infer a repeat count. A repeat is included only when specified by the cited source. Mixed instructions remain contextual text rather than a misleading single counter.
- Do not treat a repository's software license as licensing for embedded religious content.
- Do not silently repair, modernize, translate, or harmonize spellings in the displayed text.
- New source editions require a new provenance entry and editorial review.

## Search normalization

Local search removes tashkeel from the comparison value, folds alef variants to bare alef, folds `ى` to `ي`, `ؤ` to `و`, and `ئ` to `ي`, and collapses whitespace. The stored and displayed content is never rewritten.

## Pack validation and update policy

The current app loads only the bundled offline pack. No remote endpoint or arbitrary live religious-content API exists.

The pack codec rejects:

- malformed manifests or payload records;
- unsupported schema/minimum-app-schema values;
- a payload whose raw UTF-8 SHA-256 differs from the manifest;
- duplicate IDs across provenance, categories, and content records;
- missing category or provenance references;
- invalid/empty fields and invalid repeat/target values;
- a declared item count different from the parsed content count.

The future-update boundary supports checking a manifest, downloading an exact candidate, binding the candidate to that checked manifest, validating before staging, rereading and validating staged bytes, atomic activation, and rollback on every failure. An update must never mutate an active pack in place.

SHA-256 detects accidental or substituted payload bytes only when the manifest is trusted. Before a remote source is implemented, publisher authentication must be added (for example, an app-pinned public key and signed manifests), plus monotonic version/downgrade policy, secure transport, durable atomic storage, and recovery tests. A remote backend must not ship until those gates pass.

## Persistence boundaries

Religious text remains immutable in the pack. User state is stored separately with versioned JSON records:

- Adhkar active/resumable session and per-item counts: `adhkar.session.v1`.
- Dua favorite IDs: `dua.favorites.v1`.
- Tasbeeh selected phrase, count, optional target, update time, and at most ten recent completed/reset counters: `tasbeeh.state.v1`.

Unknown IDs from an older or replaced pack are discarded during loading rather than attached to different content.

## Deliberate gaps

This pack does not include Quran verses, translations, tafsir, AI explanations, audio, parent-specific Duas, travel-opening Quran passages, or categories without individually verified content. It does not implement remote updates or cryptographic publisher signatures. Those omissions are intentional safety and rights decisions, not placeholders for generated material.
