# Quran Word Study source decision

Decision date: **2026-08-14**. Status: **BLOCKED — no corpus content imported**.

## Dataset investigated

- Dataset: Quranic Arabic Corpus morphological data.
- Official download: <https://corpus.quran.com/download/default.jsp>
- Official FAQ: <https://corpus.quran.com/faq.jsp>
- Version offered by the official download page: **0.4**.
- Copyright notice: **Copyright © 2011 Kais Dukes**.
- Maintainer attribution shown by the site: Language Research Group,
  University of Leeds; maintained by the quran.com team.
- Intended fields include token coordinates, segmented source token,
  lemma/root where annotated, part of speech and morphological features.

## Rights gate

The official download-page notice calls the resource GNU GPL and expressly
allows verbatim copies and use in a website or application when the Quranic
Arabic Corpus is clearly credited, linked, and its copyright notice retained.
It also says changing the annotation file is not allowed.

The official FAQ separately says research data must not be used commercially
and should be used purely for research. Those statements do not establish a
clear production-app redistribution position. The project therefore does not
infer permission from the more permissive sentence and does not import from an
unofficial mirror.

Required resolution: obtain written clarification from the copyright holder
that identifies the exact version/files, permits the intended commercial or
non-commercial app distribution model, and explains how the GPL label relates
to the verbatim-only and research-only restrictions.

## Import and implementation result

- Downloaded source files: **none**.
- Local derivative files: **none**.
- Local record/token count: **not applicable**.
- Local SHA-256: **not applicable**.
- APK contribution: **0 bytes**.
- Verse Study token chips, morphology detail, root occurrences and linguistic
  search: **not exposed**, because showing empty or synthetic data would
  misrepresent capability.
- Existing QuranEnc `arabic_seraj` content remains honestly presented as
  verse-level word meanings. It is not relabelled as token morphology.

If permission is clarified, a future importer must consume only the official
download, retain source annotation values, validate every `(surah, ayah,
wordIndex)` against `QuranMetadata`, reject duplicate/out-of-order tokens, omit
the corpus Quran text from the app pack, and emit a deterministic versioned
manifest and payload hashes.
