# Quran App — Official Project State

Audit date: 2026-08-14  
Repository audited: `D:\quran_app`  
Application version: `1.0.0+1`  
Toolchain observed: Flutter 3.44.9, Dart 3.12.2  
Scope: updated after Universal Search & Discover V1, Quran Study Layer V2, and the focused product-quality audit.

This document is the source of truth for the state of the repository at the date above. Statuses describe code and evidence that exist now, not intent, prior task names, or visible UI shells.

## Status vocabulary

- `COMPLETE`: the current scoped capability is implemented, connected to the product, and meaningfully covered by automated or appropriate device evidence.
- `PARTIAL`: usable implementation exists, but an important product, reliability, validation, or platform requirement is missing.
- `ARCHITECTURE_ONLY`: types/interfaces/UI boundaries exist, but no usable end-to-end capability or content exists.
- `PLACEHOLDER`: a user-visible destination explicitly leads to a future/empty state.
- `NOT_STARTED`: no meaningful implementation exists.

## 1. Product vision

The product is an Arabic-first Quran and daily worship companion with an approved dark-emerald visual identity. Its intended core is a trustworthy Quran experience, listening, memorization and review, verified Adhkar, prayer times and reminders, and Qibla. Quran text integrity, religious-content provenance, calm interaction, offline usefulness, and privacy are product constraints rather than optional polish.

The present repository is a substantial V1/V2 foundation, but it is not yet a releasable complete product. It has deterministic dark identity, a validated 604-page Mushaf navigation/mapping layer, a usable 114-Surah streaming library/player, verified daily-worship content, configurable prayer times, Khatma planning, an offline calculated Islamic Daily layer, universal offline discovery, and verified bundled English translation, Arabic Tafsir and Arabic word meanings. Printed Mushaf line/glyph fidelity and production application identity/signing remain incomplete.

## 2. Current application architecture

The app is a Flutter/Material 3 monolith organized into app, core service, data model/repository, and feature UI/controller layers.

```text
main.dart
  -> initializes timezone and optional JustAudio/AudioService controller
  -> QuranApp loads canonical Quran asset
  -> MainShell constructs shared controllers/services
     -> five retained tab pages: Home, Quran, Listening, Memorization, More
     -> imperative MaterialPageRoute navigation for secondary pages
     -> local persistence through SharedPreferences repositories
     -> public HTTPS services for prayer times and streamed recitation
     -> native plugins for location, compass, notifications, and audio
```

There is no dependency-injection framework, declarative router, database, backend, authentication layer, analytics SDK, or crash-reporting SDK. `MainShell` is the composition root for most controllers. Audio is initialized separately before `runApp`; failure is silently converted to an unavailable player.

The five tab widgets are recreated as a list on every `MainShell.build`, while their durable state is held primarily in shared controllers. Secondary navigation uses direct `MaterialPageRoute` construction. Notification payload routing is a small custom coordinator rather than a general routing/deep-link system.

## 3. Directory/module map

| Path | Responsibility | State notes |
|---|---|---|
| `lib/app/` | Root app, MainShell, theme tokens, shared visual components | Central composition root; `app.dart` is large |
| `lib/core/services/` | Location, prayer API/local calculation, local notifications | Remote prayer service is active; local calculation is disconnected |
| `lib/data/models/` | Quran, resource, audio, memorization, settings, Adhkar and persistence models | `surah.dart` embeds the 114-Surah metadata table |
| `lib/data/repositories/` | Asset, network, and SharedPreferences access | Repository boundaries exist but are not uniformly owned/disposed |
| `lib/features/quran/` | Surah list and canonical Quran controller | Includes a Surah-name filter separate from full Quran search |
| `lib/features/reader/` | Reflowed Study reader, reading progress, and 604-page Mushaf foundation | Mushaf pages are lazy and canonically mapped, but printed line composition is not fixed |
| `lib/features/search/` | Offline universal search and exact result routing | Reuses the canonical Quran index and adds verified study, worship and personal-state documents |
| `lib/features/study/` | Verse study, source tabs and ayah navigation | Verified offline English translation, Arabic Tafsir and Arabic word meanings are installed |
| `lib/features/audio/` | EveryAyah sources, JustAudio engine, listening controller, library/full player/mini player | Complete streaming Listening V2 product; offline audio is out of scope |
| `lib/features/memorization/` | Plans, sessions, review scheduling, history UI | Real local V1 workflow |
| `lib/features/adhkar/` | Category/session UI and counting | Real session behavior over a six-item bundle |
| `lib/features/prayer/` | Configurable effective prayer-time controller, settings and polished page | One adjusted today/tomorrow result feeds display, next prayer, countdown and notifications |
| `lib/features/khatma/` | Local 604-page Khatma planning, progress, history and Wird flow | Versioned persistence; normal Quran reading progress remains separate |
| `lib/features/daily/` | Offline Hijri date/calendar, fasting indicators, prayer-derived night/Dhuha guidance and optional reminders | Uses calculated dates with an explicit moon-sighting disclaimer and bounded -1/0/+1 adjustment |
| `lib/features/qibla/` | Bearing calculation, sensor adapter, controller and UI | Real on-device calculation and sensor flow |
| `lib/features/settings/` | Settings UI/controller, notification scheduler/routing | Mostly worship-notification settings; many overview rows are informational |
| `lib/features/home/`, `more/`, `bookmarks/` | Dashboard, module directory, saved ayahs | More exposes both real and placeholder destinations |
| `assets/` | Canonical Quran text, Adhkar JSON, Amiri Quran font | Small, fully bundled asset set |
| `android/`, `ios/` | Native shells and plugin configuration | Android is ahead of iOS; neither is release-ready |
| `test/` | Dart unit and widget tests | 12 files, 109 tests after Listening V2 |
| `docs/` | Quran resources, Adhan audio, Qibla, notifications and this audit | Repository README remains template-only |

The audited Dart surface is 71 files and approximately 12,208 lines across `lib/` and `test/`.

## 4. Dependencies and why each important dependency exists

| Direct dependency | Current reason | Observation |
|---|---|---|
| Flutter / Material | Cross-platform application and UI | Primary framework |
| `geolocator` | Foreground position, permission and settings flows | Used by prayer times and Qibla |
| `flutter_device_compass` | Live compass heading stream | Used only by Qibla |
| `adhan_dart` | Local prayer calculation fallback | Uses the configured method, madhab, high-latitude rule, coordinates, date and device timezone |
| `timezone` | Time-zone database and TZ scheduling | Used by notifications and local prayer service |
| `flutter_timezone` | Read current native time-zone identifier | Used by notification scheduling |
| `http` | AlAdhan API and EveryAyah availability requests | Public HTTPS only |
| `shared_preferences` | All durable user state | Whole JSON documents plus an unversioned font double |
| `scrollable_positioned_list` | Lazy reader list, indexed scroll and visible-item tracking | Core of the current non-page reader |
| `just_audio` | Audio queue/playback engine | Streams per-ayah MP3 URLs |
| `audio_service` | Android/iOS background media integration and media controls | Native Android service is declared |
| `audio_session` | Configure playback audio session | Configured as speech |
| `flutter_local_notifications` | Local notification scheduling, Android channels and callbacks | Three Android channel IDs are defined |
| `hijri_core` | Offline Gregorian/Hijri conversion using its bundled Umm al-Qura table | Supported conversion range and calculated-date caveat are documented in `ISLAMIC_DAILY_LAYER.md` |
| `cupertino_icons` | Template icon package | No import exists in `lib/` or `test/`; removable dependency |
| `flutter_lints` | Analyzer lint baseline | Default recommended lint set only |

`pubspec.lock` is present. Resolved versions can be newer within the declared constraints; for example the audit resolved `cupertino_icons 1.0.9` and `shared_preferences 2.5.5`.

## 5. Shared controllers and services

`QuranApp` owns `QuranController` and the optional `QuranAudioController`. `MainShell` owns `PrayerController`, `ReadingProgressController`, `BookmarkController`, `MemorizationController`, `AdhkarController`, `SettingsController`, one shared `LocationService`, and `QiblaController`.

Important coupling and lifecycle behavior:

- Prayer and Qibla intentionally share one `LocationService`; concurrent position requests are deduplicated and the last position is retained in memory only.
- `SettingsController` depends directly on prayer and memorization controllers to schedule prayer/memorization notifications.
- MainShell observes app resume, refreshes notification health/timezone, and refreshes prayer data/schedules when needed.
- The Qibla controller is shared, but its compass subscription is started/stopped by the page lifecycle.
- The audio controller owns and disposes both its engine and the installed `EveryAyahAudioRepository` client.
- Controllers are concrete `ChangeNotifier` classes with manual construction. Tests inject stores, engines, gateways, location and compass fakes where interfaces exist.

## 6. Persistence systems and schema versions

All app-owned durable state uses `SharedPreferences`; no SQLite/filesystem database or cloud persistence exists.

| Key | Content | Schema behavior |
|---|---|---|
| `app.settings.v1` | Prayer and worship notification settings | JSON wrapper `version: 1`; invalid/unknown data falls back to defaults |
| `islamic.daily.settings.v1` | Hijri day adjustment and optional fasting/night/Dhuha reminders | JSON wrapper `version: 1`; adjustment is clamped to -1/0/+1 and all reminders default off |
| `prayer.settings.v2` | Prayer calculation method, madhab, high-latitude rule and per-prayer adjustments | JSON wrapper `version: 1`; malformed/unsupported values recover to bounded defaults |
| `quran.khatma.v1` | Active, paused, completed and archived Khatma plans/days | JSON wrapper `version: 1`; invalid pages and malformed plans are rejected |
| `quran.mushaf_display.v1` | Mushaf display scale and comfort mode | Scale is clamped to `1.0x–1.7x`; default is `1.15x` |
| `quran.bookmarks` | Bookmark list | JSON wrapper `version: 1`; invalid coordinates/data are ignored |
| `quran.reading_progress` | Last Surah/ayah and timestamp | JSON wrapper `version: 1` |
| `quran.memorization.v1` | Plans, memorized ayahs, sessions/history | JSON wrapper `version: 1` |
| `adhkar.session.v1` | Current Adhkar session | JSON wrapper `version: 1`; completion/reset removes session |
| `dua.favorites.v1` | Stable IDs of favorited Duas | JSON wrapper `version: 1`; malformed and unknown pack IDs are discarded |
| `tasbeeh.state.v1` | Selected verified phrase, counter, optional target and up to ten recent counters | JSON wrapper `version: 1`; malformed or unknown pack IDs fall back safely |
| `quran.search.recent.v1` | Up to eight query strings | Key is versioned but payload is a bare JSON list, without schema envelope |
| `quran.reader_font_size` | Reader font size, clamped 22–42 | Unversioned `double` |
| `quran.listening.v1` | Selected reciter, repeat mode, speed and up to 12 recent Surah coordinates | JSON wrapper `version: 1`; malformed/unknown data falls back safely |

Existing version mismatch handling discards data rather than migrating it. This is safe against crashes but is not a production migration strategy. SharedPreferences is adequate for the current small datasets, but whole-document writes will become fragile for a large Adhkar catalog, resource packs, audio downloads/history, or growing memorization history. Data is not app-level encrypted, and Android/iOS OS backup behavior has not been explicitly disabled or documented.

## 7. Assets and provenance

| Asset | Bytes | SHA-256 | Provenance state |
|---|---:|---|---|
| `assets/quran/quran-uthmani.txt` | 1,359,946 | `829083F684ECB5C71853029CA1970946A12C2DC90528D6E0E3CD6DBC41204B7C` | Tanzil Uthmani 1.1, CC BY 3.0; copyright block remains in the asset and details are in `QURAN_RESOURCES.md` |
| `assets/religious_content/daily_worship_ar_manifest.json` | 610 | `D18CD9191AFD1CA96811D9FCAB7864663F4B0A48B9A2DC557A939E940032B75D` | V2 manifest for the 51-record offline Arabic worship pack; source/edition/publication conclusion and payload checksum are visible in Settings |
| `assets/religious_content/daily_worship_ar_payload.json` | 29,230 | `76EAD44D26C247D6435834AEE58474F3B534B145AF5926BD278BE114BE2699E3` | Attributed Arabic excerpts from the approved IslamHouse edition of *Hisn al-Muslim* under the author's source-specific printing/publication permission; details in `RELIGIOUS_CONTENT.md` |
| `assets/fonts/AmiriQuran.ttf` | 167,976 | `8FA95FAAF7BD18B71789F6F57312003E30C5029218A035E5BAF613A0222AB82D` | Embedded metadata identifies Amiri Quran 1.003 under OFL-1.1; functional font-table checksums match the official 1.003 release, but this unstripped binary is not byte-identical to the published artifact; see `MUSHAF_RESEARCH.md` |
| `android/app/src/main/res/raw/adhan_cc0.ogg` | 1,229,032 | `35FE06B08FE80505C550C33FED8A783FA9901DDC81AC884958B4BE048F5B2A79` | Wikimedia source, unmodified, CC0 1.0; documented in `ADHAN_AUDIO.md` |

The streamed EveryAyah recitations are not bundled assets. Endpoints and source directories are documented in `EVERYAYAH_AUDIO.md`; provider terms, recording ownership, attribution and redistribution/download rights remain unresolved, so offline audio remains disabled.

## 8. Quran integrity contract

The canonical contract is strong and must remain protected:

- One bundled Tanzil Uthmani 1.1 file is the canonical Arabic source.
- Expected topology is exactly 114 Surahs and 6,236 ayahs, with sequential coordinates.
- `QuranMetadata` defines names, counts, revelation type and basmala policy.
- `QuranRepository` reads the first 6,236 non-empty lines in canonical metadata order. For Surahs whose basmala is rendered separately, it removes that prefix in memory only; it does not edit the asset.
- Surah 1 retains its first ayah basmala, Surah 9 has no separate basmala, and the other established policies are tested.
- Search, bookmarks, progress, audio coordinates, memorization and study navigation all address this canonical Surah/ayah coordinate space.
- Automated tests assert 114/6,236 counts, sequential ayahs and key basmala behavior.
- The protected asset hash verified in this audit is `829083F684ECB5C71853029CA1970946A12C2DC90528D6E0E3CD6DBC41204B7C`.

The parser logs asset line and verse counts in debug output. A future Mushaf layout asset must be additive and checksum-verified; it must not replace, reorder, or mutate the canonical text contract.

## 9. Feature-by-feature implementation state

Exactly 50 major capabilities are classified below.

| # | Feature | Status | Evidence and unresolved boundary |
|---:|---|---|---|
| 1 | Quran canonical data | COMPLETE | Bundled Tanzil asset, 6,236 verses, checksum and integrity tests |
| 2 | Quran metadata | COMPLETE | Static 114-Surah metadata, counts and basmala contracts tested |
| 3 | Mushaf | PARTIAL | Real lazy 604-page paging, complete coordinate mapping, persistence, ayah actions and audio highlight exist; page-jump dialog teardown was repaired and page 42/1/604 jumps passed on RMX3938, but text still reflows within verified page boundaries |
| 4 | Study reader | PARTIAL | Existing vertical reader is now explicitly selectable as Study Mode with exact ayah navigation/actions; translation/Tafsir content remains absent |
| 5 | Universal search | COMPLETE | Quran index reuse, Arabic/English normalization, stable ranking/group limits, recent queries, study/worship/personal content and exact routes |
| 6 | Bookmarks | COMPLETE | Add/remove, persist, list and exact reader navigation are tested |
| 7 | Reading progress | COMPLETE | Most-visible ayah tracking, debounce, persistence, restoration and indexed navigation are tested |
| 8 | Verse Study | COMPLETE | Canonical ayah, prev/next, bookmark/audio actions, three source tabs and visible provenance work offline |
| 9 | Translation | COMPLETE | QuranEnc Rowwad English 1.0.19, 6,236 mapped records, integrity checks and exact Study/search routing |
| 10 | Tafsir | COMPLETE | QuranEnc At-Tafsir Al-Muyassar 1.0.0, 6,236 mapped records, integrity checks and exact Study/search routing |
| 11 | Word study | COMPLETE | QuranEnc As-Siraj 1.0.0 preserves all 6,236 coordinates and 3,648 non-empty source records without generated fill |
| 12 | Audio engine | COMPLETE | Real per-ayah queues, play/pause/seek/speed, engine-backed ayah/Surah repeat, calm error mapping and rich MediaItems are implemented and tested |
| 13 | Listening page | COMPLETE | Searchable canonical 114-Surah library, repository reciter selection, current/recent sections and full player are usable |
| 14 | Surah-level listening | COMPLETE | Surah selection, resume, no-wrap Surah transport, ayah queue/player, seek and history are connected end to end |
| 15 | Background audio | PARTIAL | AudioService/MediaItem integration and Android manifest service exist; real lifecycle/lock-screen/headset behavior is not physically validated across platforms |
| 16 | Offline audio | NOT_STARTED | No cache manifest, download manager, storage UI, eviction, rights model or offline source selection |
| 17 | Memorization plans | COMPLETE | Create/edit/activate ranges, daily targets, persistence and coordinate validation are tested |
| 18 | Memorization review | COMPLETE | Review queue, interval scheduling, success/failure recording and resumable sessions are tested |
| 19 | Memorization history | COMPLETE | Completed sessions are persisted and shown in real history |
| 20 | Speech recitation grading | NOT_STARTED | No microphone, speech recognition, alignment or grading implementation |
| 21 | Adhkar | COMPLETE | Recommended discovery, nine verified offline categories, normalized search, one-item session counter, repeat targets, source display, haptics, persistence and resume are implemented |
| 22 | Adhkar dataset completeness | COMPLETE | 29 attributed items across morning, evening, waking, wudu, home, mosque, after-prayer, sleep and food categories; intentional source-reviewed gaps are documented |
| 23 | Adhkar updates/resources | PARTIAL | Versioned manifest/payload, checksum/schema/reference validation, staged activation and rollback abstractions exist; remote transport and mandatory signed-manifest authentication are deliberately not implemented |
| 24 | Duas | COMPLETE | 17 separately modeled verified Duas in six categories with local search, large Arabic cards, source/reference display and persistent favorites |
| 25 | Tasbeeh | COMPLETE | Five verified selectable phrases, persistent counter/target, increment/decrement, haptics, confirmed reset, progress and a modest ten-entry history |
| 26 | Prayer times | COMPLETE | One configurable, adjusted effective-time model drives the page, Home, countdown, next-prayer state and notification scheduling; online and local-source flows were exercised on RMX3938 |
| 27 | Prayer calculation configurability | COMPLETE | Five shared methods, Standard/Hanafi, three high-latitude rules and persisted ±30-minute prayer adjustments are used by both remote and local paths |
| 28 | Prayer offline fallback | COMPLETE | Timeout/network/service/malformed failures fall back to timezone-aware local calculation; RMX3938 network-off and process-restart checks retained valid times, countdown and a calm local-source state |
| 29 | Adhan | PARTIAL | Android CC0 sound can be selected per prayer notification; this is not a full Adhan playback service and iOS has no bundled equivalent configured |
| 30 | Prayer notifications | PARTIAL | Permission/settings/exact fallback/channels/routing/today+tomorrow schedules are real; normal/prayer/Adhan-channel delivery, tap routing and exact screen-off wake were exercised on RMX3938, while reboot/OEM matrix and iOS behavior remain incomplete |
| 31 | Salawat reminders | PARTIAL | Real daily local schedules with preset/custom times and tests; platform delivery is not physically validated |
| 32 | Adhkar reminders | PARTIAL | Real morning/evening daily schedules and payload routes; platform delivery is not physically validated |
| 33 | Memorization reminders | PARTIAL | Real plan/review-aware schedules and routes; platform delivery is not physically validated |
| 34 | Wird reminders | PARTIAL | Real daily schedule and Quran route; platform delivery is not physically validated |
| 35 | Qibla | COMPLETE | Great-circle calculation, sensor/location states, lifecycle, semantics, tests and RMX3938 live sensor evidence exist for scoped V1 |
| 36 | Settings | PARTIAL | Detailed worship-notification management and Quran resource status exist; appearance/audio/privacy rows are mostly informational, not settings |
| 37 | Dark visual identity | COMPLETE | MaterialApp is deterministically dark regardless of device brightness; emerald surfaces, gold accents and dark system bars are the production identity |
| 38 | Light theme | NOT_STARTED | Intentionally not exposed or selected in V1; the ivory Mushaf paper is a reading surface, not an application light theme |
| 39 | Localization | NOT_STARTED | Arabic strings are hard-coded and root RTL is forced; no `intl`, ARB files, locale selection or translation infrastructure |
| 40 | Khatma planner | COMPLETE | Deterministic 30/60/90/custom plans, current-page start, Wird routing, progress/restart persistence, redistribution, archive/history, Home card and optional reminder are implemented, tested and physically accepted on RMX3938 |
| 41 | Hijri calendar / Daily layer | COMPLETE | Offline Umm al-Qura conversion, Arabic month UI, -1/0/+1 persistence, month navigation, fasting indicators, prayer-derived night/Dhuha windows, Home/Daily/More/Settings integration and default-off reminders are implemented, tested and exercised on RMX3938 |
| 42 | Islamic occasions | COMPLETE | Concise calculated markers exist for 1/10 Muharram, 1 Ramadan, 1 Shawwal and 9/10 Dhul-Hijjah; moon-sighting dependence is disclosed and Laylat al-Qadr is not reduced to one guaranteed date |
| 43 | Resource manager | ARCHITECTURE_ONLY | Manifest/checksum model and installed-resource display exist; no acquisition, install, validation, activation, update or removal flow |
| 44 | Authentication | NOT_STARTED | No account/auth code or dependency |
| 45 | Cloud sync | NOT_STARTED | No backend or sync code |
| 46 | Android | PARTIAL | Debug build/platform integrations work; package identity, release signing, store validation and full physical matrix are incomplete |
| 47 | iOS | PARTIAL | Generated shell/background audio/local-notification code exists; required location strings, signing/capabilities and build/device validation are absent |
| 48 | Accessibility | PARTIAL | Mushaf now has persisted 1.0x–1.7x scale, controls, double tap, passive two-pointer pinch and comfort mode; whole-app screen-reader/focus/contrast coverage remains incomplete |
| 49 | Release pipeline | NOT_STARTED | No CI workflow, release signing pipeline, flavors, automated artifact/checksum flow or release gate |
| 50 | GitHub open-source packaging | NOT_STARTED | No Git metadata in this workspace, root license, real README, contribution/security policy, changelog, issue templates or CI |

Status totals:

| COMPLETE | PARTIAL | ARCHITECTURE_ONLY | PLACEHOLDER | NOT_STARTED | Total |
|---:|---:|---:|---:|---:|---:|
| 18 | 14 | 4 | 3 | 11 | 50 |

## 10. Real features, partial features and placeholders

### Mushaf audit

The Quran tab now formalizes two persisted modes. Mushaf Mode is the default and uses a lazy horizontal RTL `PageView.builder` over a repository-independent 604-page domain. Study Mode preserves the existing `ScrollablePositionedList.builder` per-ayah reader, progress tracking, font controls and exact navigation.

The Mushaf repository loads a bundled CC-BY derivative of Tanzil Medina-page metadata: exactly 604 page starts, 30 Juz starts and 240 Hizb-quarter starts. It validates continuous page numbering and maps all 6,236 canonical ayahs exactly once across all 114 Surahs. Direct page, Surah-first-page and coordinate navigation exist. The page-jump dialog now owns only route-local input state; its former externally disposed `TextEditingController` caused a `_dependents.isEmpty` assertion while Flutter was still reversing and tearing down the dialog route. A regression test repeatedly submits/cancels the dialog, and page 42, 1 and 604 jumps passed on RMX3938. Mushaf progress is stored separately from Study reading progress. Canonical Quran text is not duplicated and still comes from the protected Quran controller.

The ivory page renderer reflows Unicode ayah spans inside the verified page range. Tap recognizers are bound to rendered ayah spans and long-press resolves a rendered character offset to a known ayah; both invoke the same audio/bookmark/copy/memorization/VerseStudy actions as Study Mode. Active audio is highlighted and a visible action navigates to the playing ayah's page. This is safe ayah-level interaction for the reflowed V1 surface, not printed word/line hit testing.

The fixed-layout resource gate is documented in `docs/MUSHAF_RESEARCH.md` and `docs/MUSHAF_RENDERING_DECISION.md`. Quran Foundation and QUL QCF V2 stacks are technically sufficient but do not currently establish permission for a permanent offline redistribution bundle. Official KFGQPC Illustrator pages permit program use but provide no canonical word/ayah bounds or semantic mapping. No candidate passed all five gates, so no fixed-layout assets, models, or renderer were added and Mushaf remains PARTIAL.

AmiriQuran.ttf is internally versioned 1.003 and embeds OFL-1.1 terms. Its functional glyph, metrics, cmap, GDEF, GPOS, and GSUB tables match the official Amiri 1.003 release; its hash differs because its name/post metadata is unstripped. The exact original build/download remains unproven, so a release build should pin the official 1.003 binary and retain `OFL.txt` after visual comparison.

### Listening audit

Listening V2 now provides:

- A searchable library built directly from all 114 canonical `QuranMetadata` entries, with current-playing and recent-listening sections.
- Repository-provided Mishary Alafasy and Abdul Basit Murattal sources, persisted selection, and predictable same-coordinate queue rebuilding when the reciter changes.
- Deterministic per-ayah MP3 queues, start/resume at a canonical ayah, no-wrap previous/next Surah transport, and previous/next ayah controls.
- A full-screen emerald/gold player with code-native abstract artwork, interactive current-ayah seek, elapsed/duration, speed, three repeat modes, queue access and retry.
- Engine-backed repeat: current ayah maps to `LoopMode.one`, current Surah maps to queue-wide `LoopMode.all`, and off disables looping.
- Schema-versioned local history containing coordinates, reciter and update time; entries are unique per Surah, most-recent first and bounded to 12.
- A shared global mini player that opens the full player and can stop/clear the same controller state.
- AudioService media items containing canonical Surah, ayah and reciter metadata plus duration when known.
- Calm Arabic network/source/buffering/playback errors while technical exceptions remain debug-log only.

The main seek bar intentionally represents only the current ayah because the queue consists of individual tracks; it does not fake a continuous Surah duration. Offline downloads remain absent pending the rights boundary in `EVERYAYAH_AUDIO.md`. Background audio remains PARTIAL until a broader device/platform matrix covers interruptions, headsets and iOS.

### Adhkar audit

The bundle has exactly 2 categories and 6 items: morning has 3 and evening has 3. Items include Arabic text, target repeat count, source text and reference. Category loading, corruption recovery, counting, navigation, completion, persistence, resume, reset and time-of-day recommendation are real.

The next content architecture should use:

```text
audited bundled base pack
  + signed/versioned optional resource packs
  + manifest: ID, semantic version, locale, entry count, source edition,
    scholarly/provenance record, license, SHA-256, signature, min app schema
  + staged validation and atomic activation/rollback
```

Religious text should not be silently pulled from arbitrary live APIs. Candidate packs require human content review, stable IDs, deduplication rules, source/reference fields, license review, offline retention and a safe migration path for active sessions.

### Translation and Tafsir audit

Visible tabs and More/settings destinations do not mean these features are implemented. `BundledTranslationRepository.installedTranslations()` and `BundledTafsirRepository.installedSources()` return empty lists, and the UI correctly shows no verified source installed. The existing models, range logic, manifest and tabs are architecture only.

`QURAN_RESOURCES.md` records the blockers: Tanzil’s translation listing did not provide a sufficiently explicit per-translation redistribution license; ClearQuran’s cited CC BY-NC-ND terms conflict with unrestricted/derived packaging needs; downstream repositories cannot grant rights to underlying Quran.com, QuranEnc, Tanzil or individual-translator content; and Tafsir software-wrapper licenses do not prove rights to commentary text. A 6,236-coordinate mapping, primary-source provenance and source-specific redistribution terms must be verified before installation.

### Empty and shell destinations

Explicit user-visible placeholders are:

- About app in More -> `قريبًا` bottom sheet. It is outside the 50-row feature matrix but remains a store/readiness gap.
- Word study tab -> “section later” empty state.

Intentional architecture-only empty states are Translation and Tafsir in Verse Study and Quran Resources. Listening’s no-active-item state is not labeled coming soon, but it is an incomplete discovery shell that directs the user back to the reader. Normal empty states for no bookmarks, no memorization plan/history, no search results, a completed Adhkar session, or recoverable errors are not placeholders.

No disabled fake controls (`onTap/onPressed/onChanged: null` used as a feature facade) were found. Some Settings overview rows are static descriptive tiles, not editable settings.

### Theme audit

`MaterialApp.themeMode` is now fixed to `ThemeMode.dark`; both theme slots use the approved dark emerald theme, and status/navigation bar overlays are explicitly dark with light icons. Device light appearance cannot select a white app surface. Settings describes the fixed identity accurately. The ivory background remains scoped to Quran paper surfaces and is not a light app theme.

## 11. Android platform state

- Manifest permissions: `INTERNET`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`, `WAKE_LOCK`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, and `SCHEDULE_EXACT_ALARM`. There is intentionally no background-location permission and no `USE_EXACT_ALARM`.
- SDK values inherited from Flutter 3.44.9 resolve to compile SDK 36, minimum SDK 24 and target SDK 36.
- Build stack: Gradle 9.1.0, Android Gradle Plugin 9.0.1, Kotlin 2.3.20, Java/JVM 17, core-library desugaring 2.1.5.
- Required Windows/Kotlin stability settings remain: 8 GB Gradle heap, `android.newDsl=false`, `android.builtInKotlin=false`, `kotlin.incremental=false`, and in-process Kotlin compilation. These must not be removed casually.
- The activity is `AudioServiceActivity`; the media playback foreground service and media button receiver are declared. Scheduled-notification and boot receivers are declared non-exported.
- Three stable notification channels are generated in Dart: `worship_general_v1`, `prayer_reminders_v1`, and `adhan_v1`; the last uses `adhan_cc0`.
- Location runtime flow checks service state, requests foreground permission when denied, maps denied/denied-forever/unavailable to typed UI-safe failures, and offers Location Settings or App Settings where appropriate.
- Compass access is stream-based through `flutter_device_compass`; no extra Android sensor permission is required.
- Release blockers: `applicationId`/namespace are still `com.example.quran_app`, manifest label is `quran_app`, and the release build explicitly signs with the debug key. Launcher icons appear to be small Flutter-template raster assets; no adaptive icon is configured.
- Exact alarm access is requested only from explicit settings action and falls back to inexact scheduling. Store policy eligibility still needs review.

Physical evidence includes debug installation/launch on an RMX3938, a Qibla session with foreground location/live AKM09919 readings, repaired Mushaf page jumps, and Listening V2 playback/background media checks. There is still no evidence here for full prayer-notification delivery after reboot, OEM battery restrictions, fresh permission denial/forever paths, every screen, a broad Android device matrix, or release-mode behavior.

## 12. iOS platform state

- iOS deployment target is 13.0 and `UIBackgroundModes` contains `audio`.
- `flutter_local_notifications` is initialized with default `DarwinInitializationSettings`. Those defaults request alert/sound/badge permission during initialization, unlike the Android product flow that waits for an enabling action. The gateway’s permission/health methods are Android-specific and return `true` on iOS, so iOS Settings health is not authoritative.
- `NSLocationWhenInUseUsageDescription` is absent. Because prayer/Qibla use Geolocator and compass, the foreground location flow is not correctly configured for iOS. No related localized permission text exists.
- The Android raw Adhan resource is not an iOS sound asset; iOS Adhan selections would use default Darwin notification details.
- Bundle ID remains `com.example.quranApp`. No development team is configured in the project, no production signing setup is evidenced, and no app entitlements file/capability audit exists beyond the plist audio mode.
- The native `RunnerTests.swift` contains only the template `testExample`; there is no meaningful native iOS test.
- There has been no iOS build, simulator run, physical-device validation, background-audio validation, notification validation, compass/location validation, or App Store signing validation in this Windows audit environment.

iOS is therefore partial scaffolding, not production-ready.

## 13. Offline capabilities

Usable without app-owned network calls:

- Canonical Quran load/read, metadata and Surah navigation.
- Full Quran search and recent-search persistence.
- Bookmarks, reading progress and font preference.
- Memorization plans, sessions, review scheduling and history.
- The bundled six-item Adhkar catalog and session state.
- Qibla bearing/heading calculation once the OS supplies a current location; no remote Qibla API is used.
- Previously scheduled local recurring reminders and bundled Android Adhan sound, subject to OS scheduling behavior.

Not actually available offline:

- Active prayer-time flow: AlAdhan is primary; a device-timezone-aware local calculator is the validated fallback.
- Quran recitation: all sources are remote EveryAyah URLs and there is no cache/download path.
- Translation, Tafsir and word data: no installed content.
- Content/resource updates: no manager exists.

## 14. Internet-dependent capabilities

| Capability | Endpoint/data sent | Reliability concerns |
|---|---|---|
| Prayer times | `https://api.aladhan.com/v1/timings/...`; sends precise latitude/longitude plus the selected method, school and high-latitude rule for today/tomorrow | Eight-second timeout, validated parsing and local fallback contain availability failures; third-party availability/privacy remains relevant while online |
| Quran recitation | `https://everyayah.com/data/...`; HEAD for single ayah, then streamed MP3 URLs | Surah queue URLs are not prevalidated track-by-track; no cache/download path; provider/recording rights remain unresolved in `EVERYAYAH_AUDIO.md` |

No account, cloud sync, advertisements, analytics, remote configuration, push backend or app-owned content API exists.

## 15. Notification architecture

`SettingsController` initializes the plugin, loads schema-v1 settings, refreshes timezone/health and invokes `WorshipNotificationScheduler`. Settings default to all top-level reminder groups off, although each prayer’s nested default is enabled for when the group is activated.

Scheduling groups are prayer, Salawat, morning Adhkar, evening Adhkar, Wird, memorization and review. IDs are deterministic. Daily non-prayer reminders use `DateTimeComponents.time` and inexact scheduling. Prayer reminders use real today/tomorrow prayer instances, optionally schedule a before-prayer item, and use exact-while-idle only when the user enabled exact alarms and Android reports access; otherwise they use inexact-while-idle.

The prayer horizon is deliberately bounded to today and tomorrow. MainShell reconciles after prayer updates, startup, resume and date rollover. The plugin boot receiver restores persisted scheduled items after boot/app replacement, but it cannot fetch new prayer times while the app stays unopened beyond that two-day horizon. OEM force-stop/autostart/battery policies remain outside app guarantees.

Notification taps route to prayer, morning/evening Adhkar sessions, Quran/continue-reading, memorization, or review. Test buttons exist for normal, prayer and Adhan channels. Android POST permission is requested when enabling a reminder/test, not merely by scheduling. As noted above, iOS initialization currently prompts eagerly and is not equivalently modeled.

## 16. Location and privacy architecture

`LocationService` requests only foreground location at high accuracy. It checks disabled services first, requests when permission is denied, permits retry on ordinary denial, distinguishes denied forever, provides settings links, collapses platform exceptions into a typed unavailable state, deduplicates concurrent calls and caches the latest `Position` only in memory. Prayer and Qibla share this service. No background location permission or persistent coordinate store exists.

Privacy boundary:

- Qibla calculations and compass readings remain on device after position acquisition.
- PrayerController sends precise latitude/longitude to AlAdhan for today and tomorrow. This is not disclosed by the current Settings sentence.
- Recitation requests expose IP address plus reciter/Surah/ayah URL to EveryAyah.
- Quran activity, bookmarks, memorization, Adhkar and settings are stored locally with SharedPreferences and are not sent by app code.
- Notification payloads contain route/category/prayer identifiers, not coordinates or Quran text.
- There are no analytics, ads, accounts, API keys or cloud-sync SDKs.

The current in-app statement “no account, ads, analytics, or cloud sync” is narrowly true for app-owned systems but incomplete as privacy disclosure: third-party prayer/audio requests and possible OS backup of SharedPreferences are not explained. A real privacy policy and store data-safety declarations are absent.

## 17. Test coverage

Current automated total: **165 tests**. All previous 146 tests are preserved; Islamic Daily Layer V1 adds 19 conversion, calendar, calculation, persistence, UI-state and scheduling checks.

| Test file | Tests | Main coverage |
|---|---:|---|
| `adhkar_test.dart` | 4 | Dataset parsing/failure, session counts/navigation/persistence/resume/reset |
| `bookmark_test.dart` | 7 | Persistence/validation plus bookmark empty/action/navigation widgets |
| `memorization_test.dart` | 9 | Ranges, scheduler, plans, attempts, editing, resume/abandon and history |
| `mushaf_foundation_test.dart` | 9 | Dark identity, 604-page metadata, canonical coverage, boundaries, persistence, lazy pages, mode separation, actions, basmala policy and repeated page-dialog teardown |
| `notification_settings_test.dart` | 15 | Defaults, IDs, scheduling/reconciliation, permission/exact behavior, routing/controllers |
| `islamic_daily_test.dart` | 19 | Known-date conversion, adjustment/rollovers, fasting indicators, occasions, night/Dhuha formulas, defaults, persistence, offline state and deterministic schedules |
| `qibla_test.dart` | 9 | Bearings, normalization, invalid data, sensor/location states, haptic, shared service and page state |
| `quran_audio_architecture_test.dart` | 17 | Queue/coordinate state, calm errors, reciter persistence, Surah boundaries, seek, real repeats, history recovery, 114-library/search, full/mini players and MediaItems |
| `quran_data_contract_test.dart` | 8 | 114 Surahs, 6,236 ayahs, sequence, metadata and basmala contracts |
| `quran_knowledge_test.dart` | 10 | Offline Quran index/search/navigation/history, manifest/checksum, Tafsir range and verified Verse Study |
| `quran_ux_cleanup_test.dart` | 3 | Surah filtering, search UI states and location permission source contract |
| `reading_progress_test.dart` | 17 | Persistence/validation, reader styling/items/actions/navigation/progress and basmala behavior |
| `widget_test.dart` | 1 | App data load and main navigation smoke test |

Unit-tested: canonical data/metadata, repository serialization and corruption handling, Quran search, memorization/review logic, notification scheduling with fakes, Qibla math/state with fakes, and audio controller behavior with a fake engine.

Widget-tested: app smoke/navigation, reader/bookmark/progress/basmala/action behavior, search states, Verse Study empty-resource states, mini player/active ayah, notification settings and Qibla error states.

Physically tested on RMX3938: debug install/start; Qibla’s foreground-location/live-compass path; Mushaf page jumps to 42, 1 and 604 plus five repeated dialog cancellations with no assertion log; Listening library/reciter/full player; real EveryAyah playback; seek; ayah/Surah transport; app-background and screen-off continuation; public lock-screen metadata and media controls. Media-session pause/previous/next/stop commands changed the real session. The secure PIN prevented automated return to the in-app mini player after lock; mini-player open/close remains widget-tested.

Important behavior not physically validated or not automated:

- True fixed-layout Mushaf behavior does not exist; printed line stability, fixed-glyph hit testing, semantic overlays, and scale-only page geometry therefore cannot be validated.
- Cross-region/timezone prayer accuracy beyond the tested RMX3938 location and broader AlAdhan availability behavior.
- Complete EveryAyah provider availability, long buffering/retry sessions, interruptions, headphones and the iOS background lifecycle.
- Actual Android notification delivery, exact/inexact timing, denial flows, reboot/app-update restoration, channel sound and OEM battery behavior.
- iOS build, signing, permissions, notifications, location/compass or background audio.
- Accessibility with TalkBack/VoiceOver, focus order, dynamic text, contrast, reduced motion and switch access.
- Performance/profile benchmarks, memory, 6,236-index startup cost, long-session persistence, orientation/tablet layouts, golden/visual regressions and release builds.
- Data migrations between future schema versions and backup/restore.

## 18. Known technical debt

- Large files mix view, orchestration and formatting: `surah.dart` 820 lines, `memorization_page.dart` 733, `settings_page.dart` 626, `quran_reader_page.dart` 582, `qibla_page.dart` 495 and `app.dart` 423.
- Prayer accuracy still needs a broader multi-location/date comparison matrix even though the local path is connected and configuration/timezone-aware.
- Quran-coordinate validation is duplicated across bookmarks, reading progress, audio, knowledge repositories and memorization.
- Arabic normalization is duplicated/divergent between the Surah filter and full Quran search.
- Time formatting is duplicated in PrayerPage (twice) and HomePage.
- `EveryAyahAudioRepository` owns a client but is not disposed by its controller owner.
- Single-ayah playback performs HEAD validation, while full-Surah URL generation does not.
- `QuranResourceRepository`, `UnsupportedQuranAudioRepository`, audio next/previous-coordinate helpers, and Qibla `CompassCalibrationState` have no production consumer.
- Audio initialization happens before `runApp` and silently collapses all setup failures, with no diagnostics.
- Prayer relies on a third-party online primary source; the local fallback limits outages but does not eliminate the need for cross-method accuracy governance.
- All persistence is whole-document SharedPreferences with discard-on-version-mismatch and no migration/transaction model.
- Imperative routes are scattered; there is no typed central route/deep-link contract beyond notification destinations.
- No logging/diagnostics or crash-reporting strategy exists; debug Quran line logs are ad hoc.
- `analysis_options.yaml` is the default Flutter lints template with no project-specific strictness.
- Generated/build/IDE artifacts exist in the workspace. Most are ignored, but the workspace has no Git metadata to prove what is tracked.

## 19. Known UX/product debt

- The Mushaf-labelled surface uses verified 604-page boundaries but still reflows text inside each page; it must not be represented as a printed-layout facsimile.
- Mushaf pinch is implemented with passive two-pointer tracking and deterministic gesture tests, but a real two-pointer device gesture could not be injected after ADB loss; visible controls remain the guaranteed accessibility path.
- Listening has no offline/cache/download path and provider availability remains external.
- The active player lacks interactive seek, Surah transport, reciter selection, real repeat, queue/history and robust error/retry UX.
- Adhkar’s six items are far below a credible full worship catalog.
- Translation, Tafsir and word-meaning destinations expose installed QuranEnc resources and exact source metadata.
- Duas, Tasbeeh and About are visible coming-soon endpoints.
- Settings mixes real controls with static explanatory rows; theme and audio cannot actually be configured there.
- Prayer calculation method/school are invisible fixed assumptions.
- Arabic-only forced RTL has no localization infrastructure.
- Accessibility coverage is uneven, and large text/layout behavior is not tested.

## 20. Licensing and content gaps

- Quran text provenance and hash are well documented, but release UI must visibly satisfy Tanzil attribution/link requirements; the current resources screen does not show a clear Tanzil link/license notice.
- QuranEnc study resources passed the primary-source rights, version, attribution, checksum and 6,236-coordinate gates; remote replacement remains disabled until signed-manifest authenticity and downgrade protection exist.
- The Amiri Quran font is identified as OFL-1.1 version 1.003 and documented, but the local unstripped binary is not byte-identical to the official release artifact and should be pinned before distribution.
- EveryAyah endpoints and streamed sources are documented, but provider terms, recording ownership, attribution and download/redistribution rights remain unresolved; see `EVERYAYAH_AUDIO.md`.
- The small Adhkar JSON cites an MIT source and per-item hadith references, but the project needs a maintained content-review/provenance record before expansion; an MIT wrapper alone must not substitute for religious-text verification.
- The Android Adhan asset has the clearest non-Quran record: source, CC0 license, modification statement and checksum.
- The repository itself has no root software `LICENSE`, so it cannot yet be responsibly published as open source.

## 21. Release-readiness gaps

- Android unique package/application ID, product label, adaptive icon, release keystore and protected signing configuration are absent; release currently uses the debug key.
- iOS bundle ID/signing team/capability review and required location descriptions are absent.
- No release-mode Android or iOS build gate, obfuscation/symbol/archive process, or artifact provenance exists.
- No current full physical regression matrix for permissions, notifications, background audio, process death, reboot, offline/network changes and accessibility.
- No production privacy policy, support contact, terms/content acknowledgements, or in-app license/attribution center.
- Version remains initial `1.0.0+1`; there is no changelog or release process.
- Known functional defects include no pinch despite Settings copy and remote-only prayer times.
- External-service availability remains a dependency; EveryAyah acceptable-use and recording rights are explicitly recorded as unresolved.
- The five owner-declared core gaps remain unresolved and block a credible V1 claim.

## 22. GitHub-readiness gaps

This workspace has no `.git` directory. It also lacks a root software license, meaningful README, contribution guide, code of conduct, security policy, changelog, issue/PR templates and GitHub Actions workflows. The current README is the default “A new Flutter project” template.

Before publication, choose a software license compatible with all authored code and bundled assets, clearly separate third-party content licenses, document setup/toolchain/platform limitations, add reproducible validation commands, establish branch/review/release policy and ensure ignored generated files/secrets/local paths are not committed. `local.properties`, IDE metadata, build output and generated ephemeral files are present locally and must remain untracked.

## 23. Store-readiness gaps

- Store identifiers and branding are template values; launcher/marketing assets, screenshots and store descriptions are not production evidence.
- Privacy/data-safety forms must disclose foreground precise location sent to AlAdhan, external audio streaming, local notifications/exact-alarm access and local/OS-backed-up preferences.
- A public privacy policy and support/contact URL are absent.
- Google Play exact-alarm eligibility/policy and foreground media service declarations need release review.
- App Store location purpose text is missing; signing/capabilities and notification prompting behavior need correction and review.
- Content attribution/licensing screens are incomplete, particularly Quran/font/audio providers.
- Arabic-only product localization, accessibility metadata, tablet/orientation layouts, age/content rating and device compatibility have not been assessed for submission.
- No release artifacts have passed store preflight, Play testing tracks, TestFlight or reviewer scenarios.

## 24. Security and privacy observations

Positive observations:

- No embedded API keys, passwords, auth tokens, analytics/advertising SDKs or app backend were found.
- External endpoints use HTTPS.
- Location is foreground-only, deduplicated and retained in memory rather than app persistence.
- Qibla math and user Quran/worship records remain local in app code.
- Platform exceptions are generally mapped to calm user messages in location/prayer/Qibla paths.

Risks and required decisions:

- Precise coordinates are sent to a third party without a complete in-app/public disclosure.
- SharedPreferences content is unencrypted and OS backup behavior is unspecified. Memorization/religious activity may be personally sensitive even without identity.
- Android exact-alarm permission is high-sensitivity platform access and must be justified and policy-compliant.
- Prayer requests have a bounded timeout, validated parsing, typed failures and a local fallback; broader multi-region accuracy validation remains required.
- Audio error text can expose raw platform/network exceptions to the UI.
- Exported audio service/activity/receiver follow plugin architecture but should be reviewed against the final plugin version and manifest merger before release.
- There is no dependency vulnerability/scanning policy, SBOM, secret scan or automated supply-chain check.
- No resource-pack signature system exists; future religious content updates must be authenticated, checksum-verified and rollback-safe before activation.

## 25. Dead code, placeholders and TODOs

Dead/unused or disconnected code identified:

- `PrayerTimesService` is the production local fallback behind `EffectivePrayerTimesService`.
- `UnsupportedQuranAudioRepository`: no caller.
- `QuranResourceRepository`: tests only; settings reads the static manifest directly.
- `QuranAudioController.nextCoordinate` / `previousCoordinate`: tests only; not Surah transport UI.
- `CompassCalibrationState`: mutated/exposed by controller but not read by Qibla UI.
- `cupertino_icons`: declared but not imported.

The About and word-study placeholders were removed. Duas, Tasbeeh, Khatma and the three study resources are real offline destinations. Authentication and cloud sync remain intentionally absent.

Explicit source TODOs remain in Android build configuration for unique application ID and production release signing. The native iOS test contains only a template comment/test. The root README is entirely template content.

## 26. Current APK and debug-size observations

The existing artifact `build/app/outputs/flutter-apk/app-debug.apk` was last written 2026-08-13 08:26 local time and is 227,283,345 bytes (about 216.75 MiB). It is a debug artifact, not a release-size benchmark. Debug engine/symbol overhead and multiple native architectures can dominate size; bundled app-owned content itself is roughly 2.76 MiB across Quran, Adhkar, font and Android Adhan assets.

No release APK/AAB size, ABI split, app bundle download size, iOS archive size, symbol package or store size report exists. Size optimization should follow a measured release AAB analysis, not assumptions based on this universal debug APK.

## 27. Risk register

| Priority | Risk | Impact | Mitigation/gate |
|---|---|---|---|
| P0 | Product's Mushaf surface still reflows text within real page boundaries | Core printed-page promise/credibility mismatch | Obtain explicit rights for an exact 604-page font/layout/mapping bundle, then implement fixed logical geometry; do not fake or silently relabel reflow |
| P0 | Android release uses example ID and debug signing | Cannot safely publish/update a production app | Establish final identity, protected keystore and release build pipeline |
| P0 | iOS lacks location purpose configuration and any device/build evidence | Prayer/Qibla failure and App Store rejection risk | Add audited iOS configuration, signing and real-device validation before iOS claim |
| P0 | Production application IDs/signing/publisher identity absent | Store rejection and upgrade-identity risk | Publisher-owned reverse domain, signing and store/legal setup |
| P1 | Streaming depends on EveryAyah availability and unresolved recording/provider rights | Playback availability and future offline scope | Keep streaming errors calm; complete a source-rights review before downloads or bundling |
| P1 | Prayer methods require broader date/location accuracy governance despite the tested local fallback | Incorrect worship times outside the exercised location/method combinations | Maintain comparison fixtures and physically validate representative latitudes, seasons and timezone changes |
| P1 | Notification claims exceed device evidence; prayer horizon is two days | Missed worship reminders | Physical reboot/OEM/iOS matrix and explicit reliability UX |
| P1 | Privacy copy omits third-party coordinate/audio traffic and OS backup | User/store disclosure mismatch | Publish accurate policy and in-app disclosure; decide backup behavior |
| P1 | Whole-document persistence has no migrations | User progress loss as schemas evolve | Introduce migration fixtures/version policy before changing durable models |
| P2 | Large coupled widgets/composition root and duplicated domain helpers | Regression cost during Mushaf/listening work | Targeted extraction along feature boundaries, not a broad rewrite |
| P2 | No CI/release/security automation | Regressions and non-reproducible artifacts | Add format/analyze/test/integrity/build gates and dependency scanning |
| P2 | Local Amiri 1.003 binary is an unstripped build, not the byte-identical published artifact | Distribution chain is not fully reproducible despite embedded OFL and matching functional tables | Pin official release SHA/file and retain OFL after rendering comparison |

## 28. Recommended V1 roadmap

Follow the product-owner sequence and reassess after item 6; do not dilute it with miscellaneous features.

1. **Clear the printed Mushaf resource gate, then finish fidelity.** Obtain explicit offline app-redistribution rights for one exact KFGQPC/QCF-compatible 604-page font/layout/script bundle with canonical word mappings. Retain notices and hashes, add exact layout models, validate all pages, and pin the official Amiri release separately for Study/reflow text.
2. **Listening hardening and rights gate.** Validate interruptions/headsets and iOS background media, then establish recording/provider rights before considering manifests, caching, storage controls or offline downloads.
3. **Adhkar verified expansion/update model.** Establish editorial/provenance criteria, a materially complete audited local base dataset, signed/versioned resource-pack format, migration/rollback and content tests.
4. **Real Duas module.** Replace the placeholder only after a verified content model/source and production interaction scope are approved.
5. **Real Tasbeeh module.** Replace both placeholders with one consistent local state model, accessibility/haptic rules and tests.
6. **Signed study-resource updates.** Keep bundled reviewed snapshots until publisher authentication, signed manifests, rollback and downgrade protection are implemented together.

Every milestone should pass Quran hash/topology tests, `flutter analyze`, the full automated suite, relevant release builds, accessibility checks and a written physical-device acceptance matrix.

## 29. Recommended post-V1 roadmap

Only after the seven V1 priorities are complete and the roadmap is reassessed:

- Extend Prayer V2 validation across representative locations, seasons, timezone changes, OEM notification delivery and reboot behavior.
- Add rights-aware offline audio downloads, storage management and listening history if provider rights permit.
- Introduce localization infrastructure and accessibility conformance before adding additional languages.
- Complete Khatma's remaining physical acceptance, then consider Hijri calendar and Islamic occasions as a coherent planning/calendar domain rather than disconnected tiles.
- Evaluate speech recitation grading only with an explicit privacy, accuracy, dialect/qira'at and on-device/cloud processing policy.
- Consider optional authentication/cloud sync only after a threat model, encryption, deletion/export, consent and conflict-resolution design; local-first must remain usable without an account.
- Add mature GitHub/open-source packaging, CI/release automation, security policy/SBOM and store operations.
- Reassess desktop/web targets separately; generated platform shells do not currently imply supported products.

---

Baseline audit validation completed on 2026-08-13. Milestone validation results are appended in the final milestone report; this historical baseline was:

- `flutter pub get`: passed; dependencies resolved. Eight newer packages were reported as incompatible with current constraints, which is informational rather than a resolution failure.
- `flutter analyze`: passed with **No issues found**.
- `flutter test`: passed with **89/89 tests**.
- Canonical Quran SHA-256: `829083F684ECB5C71853029CA1970946A12C2DC90528D6E0E3CD6DBC41204B7C` (match).
- Physical-device validation was not rerun because no Android device was connected during this audit.

Milestone validation completed on 2026-08-14:

- `flutter pub get`: passed; the same eight constraint-compatible update notices remain informational.
- `flutter analyze`: passed with **No issues found**.
- `flutter test`: passed with **97/97 tests** (89 preserved plus 8 Mushaf/theme tests).
- `flutter build apk --debug`: passed; APK at `build/app/outputs/flutter-apk/app-debug.apk`.
- Canonical Quran SHA-256 remained `829083F684ECB5C71853029CA1970946A12C2DC90528D6E0E3CD6DBC41204B7C`.
- Mushaf boundary asset SHA-256: `CB9AF615681C6A677B743EB180150A62A8F54D1AB1836A304D35AF6658EDA15E`.
- Cold layout load in widget-test instrumentation was approximately 471–574 ms; pages are built lazily by `PageView.builder`. No reliable process-memory measurement was taken.
- ADB listed no attached devices, so RMX3938 install, real swipe/rendering, tap/long-press, restoration and orientation observations were not claimed.

Fixed-layout resource-gate audit completed on 2026-08-14:

- No researched candidate passed provenance, redistribution, exact-edition, 604-page, and deterministic canonical-mapping gates together. Fixed-layout implementation and asset bundling stopped; only the research/decision/project-state documents changed.
- `flutter pub get`: passed; eight newer package versions remain incompatible with current constraints.
- `flutter analyze`: passed with **No issues found**.
- `flutter test`: passed with **97/97 tests**; the existing reflow foundation reported a 518 ms cold layout load during this run.
- `flutter build apk --debug`: passed. APK: `build/app/outputs/flutter-apk/app-debug.apk`, 227,315,582 bytes, SHA-256 `082A3BF53FD2DACCE6B40FA006304ED0E78F155BA125B337A94FF7ADFF0F1AF4`.
- Canonical Quran SHA-256 remained `829083F684ECB5C71853029CA1970946A12C2DC90528D6E0E3CD6DBC41204B7C`; boundary asset SHA-256 remained `CB9AF615681C6A677B743EB180150A62A8F54D1AB1836A304D35AF6658EDA15E`.
- The debug APK installed and launched on RMX3938 (Android 15/API 35). The existing reflow page 1 rendered. Attempting the page-jump dialog to page 42 produced a Flutter debug assertion at `framework.dart` line 6268 (`_dependents.isEmpty`) during dialog teardown, so representative page-jump inspection could not be completed. This existing runtime defect was documented rather than patched because the hard resource gate required implementation to stop.
- No physical claim is made for fixed line composition, fixed-glyph hit testing, semantic overlays, audio overlay behavior, or scale-only geometry because no fixed-layout renderer exists.

Mushaf page-jump repair and Listening V2 validation completed on 2026-08-14:

- The page-jump assertion root cause was route teardown racing an externally disposed `TextEditingController`. Input state is now dialog-local. Automated submit/cancel regression coverage passes.
- On RMX3938 (Android 15/API 35), page jumps to 42, 1 and 604 completed, followed by five open/cancel cycles. Page 604 remained selected and logcat contained no `_dependents.isEmpty` or related Flutter assertion.
- The device displayed the canonical 114-Surah library, switched from Abdul Basit to repository-provided Mishary Alafasy, resumed a recent Surah and opened the full player. Real streamed durations were available.
- Physical transport changed Al-Fatihah ayah 7 to ayah 6, a seek drag changed the MediaSession position, next returned to ayah 7, next Surah rebuilt Al-Baqarah at ayah 1, and previous Surah rebuilt Al-Fatihah at ayah 1. Repeat mode UI was exercised; exact ayah/Surah loop flow is also covered by fake-engine tests.
- Playback remained active on the launcher and with the screen off. The secure lock screen displayed public Surah/reciter metadata and pause/previous/next/stop controls. Media-session pause, previous, next and stop dispatches changed the real session. A secure PIN prevented automated return to the in-app mini player after locking, so that transition is not claimed physically; it is widget-tested.
- `flutter pub get`: passed; eight newer package versions remain incompatible with current constraints.
- `flutter analyze`: passed with **No issues found**.
- `flutter test`: passed with **109/109 tests** (all previous 97 preserved plus 12 targeted tests).
- `flutter build apk --debug`: passed. APK: `build/app/outputs/flutter-apk/app-debug.apk`, 227,341,838 bytes, SHA-256 `A7BEBA7649DB8AEE2F65BDC3E63626C25777317C3526D75CAFA27C2272882E68`.
- Canonical Quran SHA-256 remained `829083F684ECB5C71853029CA1970946A12C2DC90528D6E0E3CD6DBC41204B7C`.
- The implementation build was installed and exercised before the final documentation-only update. Reinstalling the byte-final APK timed out after the secure device returned offline; no final reinstall claim is made. Kotlin stability settings and Quran/QuranMetadata files were not changed.

## 30. Daily Worship Content V2 (2026-08-14)

Daily worship is now a real offline product domain rather than two placeholders and a six-item static file.

- The shared `daily-worship-ar` 2.0.0 pack contains 29 Adhkar in 9 categories, 17 Duas in 6 categories, and 5 Tasbeeh phrases. Every record has a stable ID, visible source/reference, and a provenance link.
- The sole source is the approved Arabic edition of **حصن المسلم من أذكار الكتاب والسنة** distributed by IslamHouse. Its author explicitly permits reading, printing, and causing the work to be published. V2 uses attributed Arabic excerpts under that source-specific permission; it no longer relies on an MIT software-repository license as evidence for the underlying text.
- The pack has a schema/versioned manifest and raw-payload SHA-256. Parsing rejects malformed records, unsupported schemas, checksum mismatch, duplicate IDs, broken category/provenance references, invalid repeat/target values, and count mismatch.
- Future updates have explicit manifest-check, candidate-download, staged-store, revalidation, atomic-activation, and rollback boundaries. No remote backend exists. A signed-manifest/publisher-authentication and downgrade policy remains a mandatory gate before remote updates.
- Adhkar now has recommended-time discovery, nine categories, normalized local search, direct search-result session starts, repeat progress, haptics, visible source/reference, and persisted resume state.
- Duas now has category browsing, normalized local search, large Arabic cards, visible source/reference and persisted favorites.
- Tasbeeh now has verified selectable phrases, tap/haptic increment, decrement, confirmed reset, 33/34/100/custom/no-target options, progress display, persistent active state, and a maximum ten-entry factual history. It has no scoring, streaks, XP, ranking, or other worship gamification.
- Home's Tasbeeh tile and More's Dua/Tasbeeh rows now open real destinations. Settings displays the installed content version, record count, source, edition, publication conclusion, and integrity hash.
- Detailed sourcing, editorial, normalization, checksum, update, and omission policy is recorded in `docs/RELIGIOUS_CONTENT.md`.

Validation for this milestone completed on 2026-08-14:

- `flutter pub get`: passed; eight newer packages remain outside current dependency constraints.
- `flutter analyze`: passed with **No issues found**.
- `flutter test`: passed with **125/125 tests** (all 109 previous tests preserved plus 16 net new/expanded checks).
- `flutter build apk --debug`: passed. APK: `build/app/outputs/flutter-apk/app-debug.apk`, 227,393,043 bytes, SHA-256 `9FAA060E6F49D42A33563B66ED0B00D528C66183D6F3AC5F64C6D9FB041D005F`.
- Canonical Quran SHA-256 remained `829083F684ECB5C71853029CA1970946A12C2DC90528D6E0E3CD6DBC41204B7C`.
- Daily-worship payload SHA-256 is `76EAD44D26C247D6435834AEE58474F3B534B145AF5926BD278BE114BE2699E3`.
- The byte-final APK installed successfully on RMX3938 (`0O65228F31204E0C`, Android 15). Physical inspection showed all nine Adhkar categories, verified source/reference text, counting, and resume after process restart (`1 من 107`). Adhkar and Dua search fields reacted immediately to entered queries; Arabic normalization remains covered deterministically by unit tests because ADB's device input command rejected Arabic text.
- Duas displayed the approved source/item reference, category controls, and real cards. A favorite changed to “إزالة من المفضلة” and remained selected after process restart.
- Tasbeeh increment/decrement changed the real counter, preset target 100 applied, custom target 9 submitted, reset displayed a confirmation dialog, and count 3/target 9 survived process restart. Physical custom-target submission first exposed the Flutter route-teardown `_dependents.isEmpty` assertion caused by an externally disposed text controller; input was moved to dialog-local state, submit/cancel regression coverage was added, and the rebuilt/reinstalled APK submitted target 9 without the assertion. Haptic dispatch is implemented but tactile sensation cannot be asserted through ADB.

Quran text, QuranMetadata, Listening V2, fixed Mushaf work, and Kotlin stability flags were outside the change scope.

## 31. Prayer V2, Khatma V1 and Mushaf Accessibility V1 (2026-08-14)

This milestone adds three bounded product layers without changing Quran text, QuranMetadata, the fixed-layout/QCF resource gate, Listening V2 internals, or the Android Kotlin stability flags.

### Prayer V2

- `EffectivePrayerTimesService` is the single source of effective times for Prayer UI, Home, next-prayer/countdown state and worship-notification reconciliation. Adjustments are applied once after remote/local source resolution.
- Supported methods are Muslim World League, Egyptian General Authority of Survey, Umm Al-Qura, University of Islamic Sciences Karachi and ISNA. The same selection is mapped into AlAdhan and `adhan_dart`; the AlAdhan method IDs are 3, 5, 4, 1 and 2 respectively.
- Standard and Hanafi Asr schools and middle-of-night, seventh-of-night and twilight-angle high-latitude rules are supported by both calculation paths.
- `PrayerApiService` has an eight-second default timeout, validated response/time ordering, safe timezone parsing and typed timeout/network/service/malformed failures. Any such failure resolves through the local calculator without exposing the raw exception.
- The local path uses current coordinates, requested date, configured method/madhab/high-latitude rule and the device IANA timezone reported by `flutter_timezone`. Moscow/Russia/fixed-Hanafi assumptions were removed.
- Fajr, Dhuhr, Asr, Maghrib and Isha adjustments are independently persisted and clamped to -30 through +30 minutes. The already-adjusted result is used consistently for display, countdown, next prayer and notifications.
- Midnight is the midpoint from Maghrib to the following Fajr. The start of the last third is two-thirds into that interval. Both are labelled as calculated times. Sunrise is shown directly; Dhuha was deliberately omitted rather than presenting one disputed approximation as universal.
- Calculation settings live in the versioned `prayer.settings.v2` document. Resume refreshes location/timezone and reconciles schedules only when the effective schedule signature changes.

RMX3938 evidence: a fresh install displayed the Android foreground location dialog; allowing it loaded online AlAdhan times and the online source label. Muslim World League was changed to Egyptian, Standard was changed to Hanafi, Fajr +5 was shown, and reset returned it to zero. With Wi-Fi and mobile data disabled, Prayer displayed a local-calculation source with Egyptian/Hanafi and `Europe/Moscow`; all times, next prayer and countdown remained available after process restart and logcat showed no Flutter fatal/error/assertion. Local-effective notification construction and duplicate suppression are automated; actual OEM delivery/reboot timing remains part of the separate PARTIAL notifications capability.

### Khatma V1

- Immutable `KhatmaPlan`, `KhatmaDay` and `KhatmaProgress` models use the verified 1-604 page layer only. Storage is a schema-versioned `quran.khatma.v1` document with UTC event timestamps, malformed recovery and invalid-page rejection; Quran text is never stored.
- Quick 30/60/90-day plans and a custom target date can begin at page 1 or the current Mushaf page. Preview reports remaining pages, a non-rounded pages/day estimate and expected end date.
- Distribution is deterministic: integer quotient pages are assigned to every day and remainder pages are spread one per early day. Tests prove complete contiguous coverage with no gaps or duplicates.
- Today's card exposes its page range, remaining pages, current/total day and overall progress. Start/Continue opens a dedicated Mushaf route without overwriting ordinary reading-progress storage. Subsequent page changes infer bounded progress inside today's range; explicit day completion remains available.
- Missed incomplete days preserve completed history and redistribute only remaining pages across dates from today through the target date. The calm update message is persisted through the recalculated model.
- Title, target date, optional reminder and active/paused status can be edited. Completed and archived plans remain in history without scoring, rankings or streaks.
- Home has a compact plan/progress entry and More exposes the full Khatma destination. The optional reminder defaults off, uses deterministic ID 6001 and is omitted when today's assignment is complete.

RMX3938 evidence: a 30-day page-1 plan produced day 1 pages 1-21, Start Wird opened page 1, a swipe to page 2 recorded two completed pages, and ayah/Mushaf interactions remained intact. That session exposed an overall remaining-pages bug (603 instead of 602); the formula was corrected to total minus completed and locked with a regression test. Because the device disappeared from ADB before the corrected byte-final APK could be installed, final-device persistence, custom-plan and archive/history acceptance are not claimed; the overall Khatma capability therefore remains PARTIAL.

### Mushaf accessibility/readability

- Mushaf display settings are independent of Study Reader and persist under `quran.mushaf_display.v1`. Scale is clamped to 1.0x-1.7x, default is 1.15x, malformed data recovers safely and reset restores the default with comfort mode off.
- A display bottom sheet provides immediate decrease, reset and increase feedback plus a clearly described comfort-mode toggle.
- Double tap changes scales below 1.4x to a 1.45x comfort preset, then restores the previous/default scale.
- Pinch uses a passive pointer `Listener`, not an `InteractiveViewer` or a competing one-pointer scale recognizer. At two-pointer start it records the display scale and initial distance; updates calculate `startScale * currentDistance / startDistance`, clamp once and render continuously, while persistence occurs only after the pointers end. This leaves the horizontal `PageView` arena available for one-finger swipes.
- Comfort mode reduces decorative margins, relaxes line spacing and permits vertical scrolling inside the current page. It is explicitly a readability presentation, not a claim of fixed printed-page fidelity. Canonical ayah coordinates and lazy `PageView.builder` rendering are unchanged.

RMX3938 evidence: default 1.15x rendered readably; repeated increase reached 1.45x with visibly larger text; vertical scrolling exposed all content, horizontal page 1-to-2 swipe worked, ayah tap and long press still opened actions, double tap returned to 1.15x, and comfort mode reduced horizontal margins. Page jumps to 42 and 604 and process restoration of page 604/display settings succeeded without Flutter errors. A true two-pointer pinch could not be driven through Android's single-pointer `input` command, and raw multi-touch injection was denied; no physical pinch claim is made. Android large-font/display-scale coverage also remains outstanding.

### Validation and artifact

- `flutter pub get`: passed.
- `flutter analyze`: passed with **No issues found**.
- `flutter test`: passed with **146/146 tests** (all prior 125 preserved).
- `flutter build apk --debug`: passed. Byte-final APK is 227,461,897 bytes with SHA-256 `CFFD43B66286C0919AC034F422F89757A38F331264FED0086AAB39686894E3B1`.
- Canonical Quran SHA-256 remains `829083F684ECB5C71853029CA1970946A12C2DC90528D6E0E3CD6DBC41204B7C`.
- The implementation candidate was exercised extensively on RMX3938 (`0O65228F31204E0C`, Android 15). The device dropped out of ADB before the final Khatma counter/accessibility-test rebuild could be reinstalled, so a byte-final install claim is explicitly withheld.

## 32. Islamic Daily Layer V1 and Android acceptance hardening (2026-08-14)

Islamic Daily Layer V1 is a local-first calculated information layer, not a generic religious-content feed.

- `hijri_core` supplies offline Gregorian/Hijri conversion from its bundled Umm al-Qura table. The product applies the selected -1/0/+1 adjustment to the civil day before conversion and uses the inverse operation for calendar selection. Arabic month names and immutable date/settings/occasion/fasting/night/Dhuha state models are app-owned.
- Every Hijri surface labels the result as calculated and explains that official local dates can differ with moon sighting. The supported library range and source boundary are documented in `docs/ISLAMIC_DAILY_LAYER.md`.
- The month view supports previous/next navigation and selected-day Gregorian mapping. Calculated occasion rules are limited to 1 and 10 Muharram, 1 Ramadan, 1 Shawwal, and 9 and 10 Dhul-Hijjah. It does not present Laylat al-Qadr as one guaranteed date.
- Monday, Thursday and Hijri days 13/14/15 are non-coercive fasting indicators. Their optional reminders default off, use deterministic IDs, schedule on the previous evening at the user-selected time, and cancel before replacement.
- The effective Prayer V2 schedule is reused rather than recalculated. Night is Maghrib through the following Fajr; midpoint is one half of that duration and the last-third start is two thirds through it. The calculated Dhuha guidance window is sunrise plus 20 minutes through Dhuhr minus 10 minutes and is not described as a jurisprudential optimum.
- One compact Home card prioritizes the Hijri date plus a useful fasting/night summary. Daily and calendar pages are reachable from Home and More; Settings owns adjustment and reminder controls. Basic conversion and prayer-derived fallback state remain usable without network access.
- Notification integration adds deterministic fasting, last-third and Dhuha IDs, prerequisite checks, duplicate prevention and Daily payload routing. A one-minute notification test is available for physical background/screen-off acceptance.

RMX3938 evidence before the final artifact rebuild: the current date, +1 adjustment, month navigation, Home/Daily/Settings integration, calculated night/Dhuha values, reminder enable/disable, Android notification permission prompt, restart persistence and offline cold-start behavior all passed. The +1 setting and Monday reminder were returned to 0/off after testing. Under Android font scale 1.3 plus density 400, Home, Mushaf, Prayer, Khatma/history, Listening, Adhkar, Duas, Tasbeeh, Daily, More and Settings remained usable without a Flutter overflow exception; one Prayer app-bar truncation was found and corrected with scale-down layout. The device was restored to its exact 1.0/320 baseline.

Khatma acceptance is now complete: both 30-day and custom-date/current-page plans were created, Wird navigation and partial progress were exercised, the process was restarted, and persisted archive history showed the expected 604-page/30-day and 603-page/38-day records. Mushaf remains PARTIAL because fixed printed-page composition is unresolved and true two-pointer pinch could not be injected through non-rooted ADB; one-finger paging, tap, long press, double tap, controls, comfort/default modes and restart persistence passed.

Notification acceptance confirmed normal, prayer and Adhan-channel delivery, Settings/Prayer tap routing, the Android exact-alarm settings flow, and an Adhan channel bound to the bundled `adhan_cc0` resource with DND bypass disabled. On the final installed bytes, notification ID 9996 fired from an exact zero-window `RTC_WAKEUP` while the app was backgrounded and the screen was asleep; Android recorded the app wakeup and retained the expected unseen Arabic notification. Its post-lock tap could not be exercised because the secure PIN cannot be dismissed through ADB. Audible sound cannot be independently heard through ADB, and reboot/OEM restoration remains unclaimed.

Final validation: `flutter pub get` passed; `flutter analyze` reported no issues; all **165/165 tests** passed; and `flutter build apk --debug` succeeded. `build/app/outputs/flutter-apk/app-debug.apk` is **227,531,760 bytes** with SHA-256 `9C195B101FF61652FD264480E808C755293B8B6764F6FE8ADE0DEAE653F6C3C9`. Installation on RMX3938 succeeded, launch succeeded, and pulling the installed `base.apk` produced the same byte count and SHA-256. The canonical Quran SHA-256 remained `829083F684ECB5C71853029CA1970946A12C2DC90528D6E0E3CD6DBC41204B7C`.

## 33. Universal Search & Discover V1 and Quran Study Layer V2 (2026-08-14)

- One Arabic-first discovery surface now searches the existing canonical Quran index, installed QuranEnc study resources, Adhkar, Duas, bookmarks, memorization/Khatma state and an explicit set of real application destinations. Ranking and tie-breaking are deterministic, result groups are bounded and lazy, and recent history is local and limited to eight entries.
- Quran results continue to display text only from `QuranRepository`; the universal layer does not persist or build a second Quran text index. Exact references, bookmarks and memorization ayahs route to the canonical reader. Study results route to the exact verse and Translation, Tafsir or Word Meanings tab. Worship and feature results use stable identifiers and real destinations.
- The bundled offline study pack contains QuranEnc `english_rwwad` translation (6,236 nonempty records), `arabic_moyassar` Tafsir (6,236 nonempty records) and `arabic_seraj` verse-level word meanings (6,236 coordinates, 3,648 nonempty source records). Blank source word-meaning records remain blank and are not fabricated.
- `tool/import_quranenc.ps1` consumes the official per-surah API, retries requests, validates all 6,236 unique coordinates, deliberately excludes API `arabic_text`, preserves source study strings and emits a versioned manifest with byte size and SHA-256. Runtime validation rejects schema, metadata, size, checksum, coordinate, duplicate and substitution failures before exposing content.
- Remote resource activation is intentionally disabled. Future activation requires authenticated publisher origin, signed manifests or equivalent authenticity, and downgrade protection; checksum-only updating is not treated as secure.
- Verse Study now presents the canonical ayah first, followed by real selectable Translation, Tafsir and Word Meanings tabs, concise source/version attribution, previous/next navigation, bookmark and audio. Settings lists the installed resources and exposes publisher, source, version, date, record count, integrity hash and redistribution notice in technical details.
- Product polish replaced template-facing product labels on Android, iOS, macOS, web, Windows and Linux, removed the fake Home profile affordance and placeholder About sheet, stopped raw Quran-load errors from reaching users, and restricted remaining audio/performance diagnostics to debug builds. Production reverse-domain IDs, signing, publisher/legal/support identity, store records, external deep links and several previously documented physical acceptance gaps remain release blockers.

Final source validation passed: `flutter analyze` reported **No issues found** and `flutter test` passed **177/177 tests** (all 165 prior checks retained plus 12 focused study/search checks). Representative full-suite timings were study load **1,204 ms**, index construction **989 ms**, Quran query **47 ms**, Tafsir query **45 ms** and translation query **37 ms** on the development host. The byte-final debug APK built successfully at `build/app/outputs/flutter-apk/app-debug.apk`: **227,577,668 bytes**, SHA-256 `9A9C48C05E0DFE435F8DD7FE81760AFFF6EBAA64366D9961E18D106A4A996855`, a net **45,908-byte** increase over the previous verified debug baseline. The four study-pack ZIP entries total **1,526,900 compressed bytes** (**4,998,834 raw bytes**); the smaller net APK movement reflects other changed ZIP/build sections and is not a release-build forecast. Canonical Quran SHA-256 reverified as `829083F684ECB5C71853029CA1970946A12C2DC90528D6E0E3CD6DBC41204B7C`.

RMX3938 physically rendered the new global search and real bounded English translation results for `Throne` without overflow. The device then changed to ADB `offline` during final package replacement and disappeared after daemon recovery. Therefore installation and pulled-hash equality of the final instrumentation-only rebuild are **not claimed**; the last fully installed candidate preceded only the debug timing instrumentation/import correction. Exact study routing, all three resource tabs and stable worship/destination identifiers are covered by automated tests, but a complete byte-final physical navigation pass remains outstanding.

## 34. Memorization Coach V2, local backup and source-gated Word Study (2026-08-14)

### Quran Word Study gate

Quranic Arabic Corpus version 0.4 was investigated only through its official
site. The download-page notice permits attributed verbatim application use and
labels the data GNU GPL, while the official FAQ separately limits research
data to non-commercial research. This is ambiguous for a production product,
so no corpus file, token, derivative, manifest or UI claim was introduced.
Corpus contribution is 0 raw bytes and 0 compressed APK bytes. The exact
decision and required copyright-holder clarification are in
`docs/QURAN_WORD_STUDY.md`. Existing QuranEnc word meanings remain described as
verse-level content rather than token morphology.

### Memorization Coach V2

- Explicit modes are new memorization, near review, old review and self-test.
- Test presentations are full-ayah concealment, first canonical whitespace
  words, progressive canonical-word reveal and a previous-ayah prompt asking
  for the next ayah. No linguistic tokens, generated hints, speech grading or
  accuracy scores are used.
- The three self-ratings are stable, needs review and difficult. They map
  deterministically to stage advancement, one-stage reduction, or stage-zero
  reset respectively.
- Weak review contains only memorized ayahs with explicit failures or a missed
  review date. Sessions persist mode, presentation and per-ayah results, resume
  locally, and finish with reviewed/needs-review/next-review/plan-progress
  summary information.
- Exact ayah audio and repeat continue through the existing audio controller.
  The reader callback opens the exact canonical coordinate and returns to the
  memorization route. Home uses one compact due-review message rather than a
  new dashboard card.

### Backup, routes and migrations

- Backup V1 exports only an explicit whitelist of user-owned SharedPreferences
  sections as versioned JSON. It excludes Quran/study resources, audio,
  location coordinates, search history and arbitrary keys.
- Import uses the system document picker, previews sections, rejects unknown
  or incompatible data, validates Quran coordinates and pages 1–604, and
  replaces only present sections after confirmation. Preference writes roll
  back on failure. Export uses the system share sheet with an in-memory JSON
  file and requests no storage permission.
- Internal path models now cover ayah, Verse Study tab, Khatma, memorization,
  Dua, Adhkar, prayer and Qibla. They reject external schemes/domains because
  no production domain ownership exists. Ayah sharing contains only canonical
  Quran text, Surah/ayah reference and app attribution unless future explicit
  study sharing is requested.
- Memorization, Khatma, bookmarks, reading progress, app settings and Mushaf
  progress/display documents migrate safely from v1 to v2. Invalid coordinates
  and pages are rejected rather than migrated.

### Validation

`flutter pub get` passed. `flutter analyze` reported **No issues found**.
`flutter test` passed **188/188 tests**, retaining all previous 177 tests and
adding 11 focused checks. `flutter build apk --debug` passed. The byte-final APK
is **227,803,557 bytes**, SHA-256
`B6093AF8785950461C82A4E6F81A24E929506D7589EFBFEFF5E1A13D2D85F7F3`, a
**225,889-byte** debug increase over the prior milestone. Canonical Quran
SHA-256 remains
`829083F684ECB5C71853029CA1970946A12C2DC90528D6E0E3CD6DBC41204B7C`.
Debug size is not a release-size forecast.

The first milestone APK installed on RMX3938 and cold-launched in 6,681 ms. Its
persisted memorization plan rendered all four new session modes and opened a
real hidden full-ayah session offline. Physical interaction exposed a bottom
inset defect: session controls overlapped Android three-button navigation and
the reveal tap opened Recents. The session body was moved into a bottom
`SafeArea`, regression coverage was added, and the fixed APK rebuilt. During
replacement the RMX3938 again transitioned from connected to shell-stalled,
ADB-offline and disconnected. Therefore the fixed byte-final installation,
post-fix reveal/rating/weak-queue flow, backup picker/share sheet, large-font
pass and installed-APK hash comparison are not claimed.

## 35. Navigation, premium visual fidelity and local Assistant foundation (2026-08-14)

- Primary navigation is now Home, Quran, Worship, Ask and Library. More is not
  exposed as a primary tab. Tabs are lazily created and then retained, preserving
  useful state without eagerly decoding every supplied design asset.
- Home prioritizes next prayer, Continue Quran, one contextual action, a compact
  calculated Islamic-day summary, Ask and small shortcuts. The contextual action
  is deterministic: due memorization, active Khatma, then daypart Adhkar.
- Quran groups Mushaf, Study, Search, Listening, Translation, Tafsir, Word
  Meanings and Memorization around existing engines. Worship exposes Prayer,
  Qibla, Adhkar, Duas, Tasbeeh and the Islamic day. Library contains only real
  user state: bookmarks, Khatma, memorization, listening history and backup.
- Ask is a deterministic local-command foundation. It supports bounded Quran,
  prayer, worship, Khatma, memorization and installed-study intents, rejects
  invalid/unsupported input, and never generates religious guidance. AI/LLM is
  **not implemented**; the future retrieval/citation safety gate is documented.
- Project-original assets in `assets/design/` are integrated with contrast
  overlays and responsive fitting. Mushaf uses subtle header, divider, corner,
  footer and paper assets outside the canonical glyph area. Canonical Quran text,
  QuranMetadata and verified religious resources are unchanged. Mushaf remains
  **PARTIAL** for fixed printed-line fidelity.
- Navigation/Home/Worship/Library are implementation-complete but physical
  classification remains pending until the byte-final build can be exercised on
  RMX3938. The previous SafeArea, backup and post-rating acceptance gaps also
  remain open while the device is absent from ADB.

### Validation

- `flutter pub get` passed and `flutter analyze` reported **No issues found**.
- `flutter test --concurrency=1` passed **194/194 tests**, preserving the prior
  188 and adding six focused navigation, Assistant, asset and 1.3x layout checks.
  The serial run keeps the inherited wall-clock search benchmark isolated from
  unrelated image-decoding test isolates.
- `flutter build apk --debug` passed. The byte-final APK is **227,846,799
  bytes**, SHA-256
  `C029EC86BF4A1EB06919461FBEE7A78BA57B90798FF271F9BADBED3A7DF1C70C`.
- The 24 project-original design assets contribute **10,746,115 stored APK
  bytes**. Tabs load lazily, and runtime decode widths are bounded to reduce
  image-cache pressure. No startup or memory regression was measured on a
  physical device because RMX3938 remained absent from ADB.
- Canonical Quran SHA-256 remains
  `829083F684ECB5C71853029CA1970946A12C2DC90528D6E0E3CD6DBC41204B7C`.
- Byte-final install, pulled-APK comparison and the requested physical flow are
  not claimed. `adb devices -l` returned no connected device throughout the
  milestone.
# Release-candidate audit — 2026-08-25

The final audit preserved the protected Quran SHA-256 and all 194 baseline tests. Grounded Ask V1 now returns structured local source text/citations for Quran, verified translation, Tafsir, word meanings, and prayer calculation state; app actions remain deterministic, unsupported prompts do not hallucinate, and ruling prompts receive an explicit scholar boundary. No provider or external assistant data flow exists.

Android debug validation passes on RMX3938 and the pulled installed APK is byte-identical. Production AAB creation is intentionally blocked until publisher signing credentials exist. Android/iOS identifiers remain `com.example...` because no legal publisher identity was supplied. Offline audio is blocked by recording-specific rights. iOS remains configuration-audited only. Therefore this is an engineering release-candidate build, not store-ready.

## 37. Final production/public-release pass — 2026-08-26

Final identity is رفيق المسلم / Muslim Companion, publisher Ahmed Haggag, support `ahmedhaggagdev@gmail.com`, application/bundle ID `com.ahmedhaggag.muslimcompanion`, version `1.0.0+1`. Active Android and iOS production configurations no longer use `com.example`. Branded emblem icons and an emerald Android 12 splash replace Flutter placeholders; About presents identity, support, version, privacy/source context and the approved dedication.

Security closure added Android cleartext denial, backup import byte/depth limits, unsafe URI regression coverage, threat model/checklist, secret scan, conservative Dependabot and public-repository templates. No credential or sensitive key file was found. Because `.git` is absent, history scanning was impossible. The source licence is deliberately public-visible but proprietary/no-grant; third-party content remains separately licensed in `CONTENT_LICENSE_MATRIX.md`.

Validation: Flutter 3.44.9 / Dart 3.12.2; doctor clean; 199/199 tests; analyzer clean. Debug APK is 182,194,099 bytes with SHA-256 `FD5F1E6BC36D0339912DB33EC37F9D1D53490CF544EB42CE9BCBE3EDE22D26F8`. `apksigner` verifies its debug v2 signature. RMX3938 Android 15/API 35 installed the exact package via non-streamed ADB, cold-launched through the branded splash, rendered Home, and the pulled APK matched exact size/hash. No fatal Flutter/Android log was observed in that smoke session.

Strict classification:

- Android engineering release candidate: **COMPLETE** for the validated debug bytes.
- Play Store code readiness: **COMPLETE** except owner-controlled signing/hosted-policy/store-console actions; release tasks correctly refuse to build without production signing.
- Play submission: **BLOCKED** by upload keystore/Play App Signing, Play Console forms/assets and a hosted privacy-policy URL.
- GitHub public readiness: **COMPLETE** for a source-visible proprietary repository, subject to Ahmed accepting the no-grant licence posture and reviewing the publication set outside generated/ignored files.
- iOS: **PARTIAL/BLOCKED** without macOS/Xcode/iPhone build and signing validation.
- Mushaf: **PARTIAL** because licensed exact printed layout remains unavailable.
- Offline audio: **BLOCKED** by recording-specific storage/redistribution rights.
- Token morphology: **BLOCKED** by ambiguous corpus redistribution terms.
