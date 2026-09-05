# Navigation and information architecture

## Primary destinations

The application has five stable primary destinations:

1. **الرئيسية** — a curated daily surface.
2. **القرآن** — reading, listening, study, search and memorization.
3. **العبادة** — prayer, Qibla, Adhkar, Duas, Tasbeeh and the Islamic day.
4. **اسأل** — deterministic local commands and destination discovery.
5. **مكتبتي** — bookmarks, Khatma, memorization state, listening history and backup.

`المزيد` is no longer a primary destination. The old `MorePage` source remains
only as a compatibility implementation while notification and internal route
callers are audited; it is not reachable from the primary UI. Existing feature
pages and controllers remain the source of behavior. The hubs do not duplicate
prayer, Quran, audio, study, worship or persistence engines.

## Home hierarchy

Home renders the next-prayer surface first, then Continue Quran, exactly one
contextual action, the compact calculated Islamic-day card, Ask, and small
shortcuts. Contextual priority is deterministic: due memorization, active
Khatma, then daypart Adhkar. No reading statistic is inferred or fabricated.

## State and back behavior

Tabs are created lazily when first visited and retained in an `IndexedStack`.
This preserves useful scroll and field state without decoding every design
asset at startup. Feature details are pushed on the root shell navigator, so
system Back returns to the originating hub and does not create a nested shell.
Notification and internal destination routes continue to open their existing
feature pages directly.

Settings is available from Home and the Library header. No account, avatar or
authentication concept is implied.

## Accessibility and responsive rules

The Quran action row becomes vertical on narrow layouts or larger text. Worship
tiles become one column at large text scale. Hub cards use bounded artwork,
multi-line subtitles where needed, semantic button labels for image heroes,
and tooltips for icon-only actions. Quran text sizing is independent of the hub
artwork and system navigation remains inside the existing SafeArea boundary.

