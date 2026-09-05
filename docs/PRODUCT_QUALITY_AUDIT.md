# Product quality and release audit

Audit date: **2026-08-14**. Scope: Universal Search & Discover V1, Quran Study
Layer V2, and a focused release-quality review. This is not a claim that every
legacy production risk is closed.

## Corrected in this milestone

- Replaced Quran-only discovery entry points with one Arabic-first universal
  search surface from Home, Quran and More.
- Kept the Surah-name field inside Study Mode as a local list filter; it is not
  presented as a second global search product.
- Replaced the translation/Tafsir/word placeholders with verified offline
  QuranEnc resources and exact Verse Study routes.
- Replaced the More/About “قريبًا” sheet with a real, concise About page.
- Replaced the fake profile affordance on Home with the global-search action.
- Changed user-visible Android, iOS, macOS, web, Windows and Linux product labels from
  template `quran_app`/`Quran App` text to “القرآن الكريم”.
- Removed canonical Quran and Mushaf startup debug prints. Audio exception
  diagnostics are now explicitly debug-only.
- The Quran load failure screen no longer prints a raw exception.
- Resource failures are converted to calm unavailable states; integrity errors
  remain internal and never substitute unverified text.
- Search result groups have deterministic order, deterministic tie-breaking
  and bounded counts. Results are built lazily by `ListView.builder`.
- English text is rendered LTR while the page and Arabic resources remain RTL.
- User-facing resource metadata now exposes source, publisher, version, date,
  counts and hash without presenting internal asset paths as product copy.

## Intentional non-duplicates

- `QuranSearchService` remains the single canonical Quran index and is reused
  by `UniversalSearchService`; no second Quran index or normalized Quran text is
  persisted.
- The Quran Study Mode Surah filter and global search serve different scopes.
- More's Tafsir and Translation rows intentionally converge on the same real
  installed-resources inventory.
- Verse Study, Reader and Mushaf reuse canonical surah/ayah coordinates and do
  not own Quran copies.

## Open release blockers

1. Android, iOS, macOS and Linux still contain `com.example...` application or
   bundle identifiers. A production identifier must be chosen from a reverse
   domain controlled by the publisher. This audit deliberately did not invent
   ownership or silently break upgrade identity.
2. Release signing, store records, privacy URLs, support contact and legal
   publisher identity are not present in the repository.
3. iOS background audio/notification behavior, Android OEM reboot scheduling,
   audible Adhan and true physical two-finger Mushaf pinch retain previously
   documented acceptance gaps.
4. The fixed printed-page/QCF fidelity gate remains unresolved; no unlicensed
   QCF font was introduced.
5. `MainShell` remains a large imperative composition root and secondary routes
   are not a declarative deep-link graph. Search uses stable route settings, but
   external URL/deep-link handling is not implemented.
6. The study pack is about 4.99 MB uncompressed and is parsed in memory on first
   Study/Search use. It is acceptable for V2 but should be profiled on low-memory
   Android devices before a much larger multilingual catalog is added.
7. SharedPreferences remains the persistence layer for growing memorization and
   history documents; schema migration remains discard-and-recover rather than
   a full migration framework.

## Audit boundaries

No Quran text or `QuranMetadata` was modified. No generated religious content,
cloud service, authentication, analytics, advertisement, offline audio or new
Kotlin stability setting was introduced. Remote study-resource activation is
disabled until the signed-manifest gate documented in
`QURAN_STUDY_RESOURCES.md` exists.

## Validation outcome

- `flutter analyze`: no issues.
- `flutter test`: 177/177 passed.
- Byte-final debug APK: 227,577,668 bytes, SHA-256
  `9A9C48C05E0DFE435F8DD7FE81760AFFF6EBAA64366D9961E18D106A4A996855`.
- Protected Quran SHA-256: unchanged at
  `829083F684ECB5C71853029CA1970946A12C2DC90528D6E0E3CD6DBC41204B7C`.
- RMX3938 rendered the universal search and real English translation matches.
  The phone went ADB-offline during replacement with the byte-final rebuild, so
  byte-final installation and installed-APK hash equality remain unverified.

## Memorization/backup hardening follow-up

- The new Memorization session controls use semantic tooltips and a bottom
  `SafeArea`. Physical QA found the original bottom controls beneath Android's
  three-button navigation; that layout was corrected and locked by a widget
  regression check.
- Ayah actions are scrollable, fixing a 6.5-pixel overflow after Share was
  added and improving large-text behavior.
- Backup copy is concise and states the exclusion of Quran and study content.
  Import never exposes parser exceptions and requires preview plus explicit
  replacement confirmation.
- The large memorization page remains sizeable, but session domain logic stays
  in controller/scheduler/model layers, backup logic is isolated in a service,
  and internal path parsing is isolated from widgets. No line-count-only
  refactor was performed.
- Runtime Dart contains no TODO/FIXME, coming-soon, fake-smart or AI placeholder
  terminology. No analytics or remote diagnostics were added.
- Production identity remains blocked by publisher-owned IDs/signing details;
  exact rename steps are in `docs/RELEASE_IDENTITY.md`.

Final validation: 188/188 tests, no analyzer issues, and a successful byte-final
debug APK build at 227,803,557 bytes with SHA-256
`B6093AF8785950461C82A4E6F81A24E929506D7589EFBFEFF5E1A13D2D85F7F3`.
The fixed artifact was not installed after RMX3938 disconnected during package
replacement, so remaining physical acceptance is explicitly open.

## Navigation and visual-fidelity follow-up

- Replaced the overloaded More primary tab with purpose-specific Quran,
  Worship, Ask and Library destinations. Existing feature routes remain intact
  for notifications and internal destinations.
- Home no longer presents the complete product as a grid. It uses one explicit
  priority chain and progressive disclosure.
- Added project-original art through reusable clipped/overlaid cards, responsive
  standalone illustrations, subtle Mushaf decoration and selective empty states.
  The two generic/history empty assets remain deliberately unused.
- Added a bounded local Arabic command parser. It returns typed app actions or
  source-grounded Prayer/Study results and has no generative or remote path.
- Fixed a Quran-hub large-layout defect found by the widget suite: a stretched
  row inside an unbounded scroll constraint requested infinite height. The row
  now uses its children's explicit height and the test locks the shell behavior.
- Remaining blockers are production IDs/signing/legal identity, fixed-layout
  Mushaf fidelity, low-memory profiling, and the outstanding physical acceptance
  pass while RMX3938 is unavailable to ADB.

Validation finished with 194/194 tests in the isolated serial run, no analyzer
issues, and a 227,846,799-byte debug APK with SHA-256
`C029EC86BF4A1EB06919461FBEE7A78BA57B90798FF271F9BADBED3A7DF1C70C`.
An earlier default-concurrency run also completed 194/194; a later heavily
contended run made the pre-existing three-second search benchmark flaky, so the
byte-final validation used `--concurrency=1`. RMX3938 did not appear in ADB and
no physical or installed-byte claim is made.
# Release-candidate delta — 2026-08-25

- 196 tests and static analysis pass; the byte-final debug APK was installed and byte-compared on RMX3938.
- Ask has structured grounded retrieval and a dedicated religious-ruling boundary, with no LLM/network provider.
- Android release signing no longer uses the debug key and now fails explicitly when private configuration is absent.
- CI and release/security/privacy/store/iOS/audio-rights documents were added.
- Store readiness remains blocked by publisher IDs, signing custody, hosted privacy/support contacts, audio rights, and unperformed iOS acceptance.
