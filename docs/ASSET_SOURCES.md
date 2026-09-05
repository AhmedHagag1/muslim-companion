# Design asset sources and use

All files under `assets/design/` are project-original design assets supplied
for this application. They are declared as one Flutter asset directory and are
not downloaded at runtime.

The original brand composition is `assets/branding/muslim_companion_logo.png`, supplied for Muslim Companion by Ahmed Haggag. `muslim_companion_emblem.png` is an emblem-only launcher derivative produced from that reference for this release: wordmarks were removed, the emblem was centered on a matching dark-emerald square, and platform sizes were generated without stretching. The original file remains unchanged. Public trademark/asset licensing is separate from the application-source licence.

## Integrated assets

| File | Product use |
|---|---|
| `01_home_hero_bg.webp` | Home greeting/header region with a dark contrast overlay. |
| `02_prayer_card_bg.webp` | Home next-prayer hero. |
| `03_listening_bg.webp` | Listening library hero and full-player artwork. |
| `04_daily_card_bg.webp` | Compact calculated Islamic-day card on Home. |
| `05_mushaf_header_ornament.png` | Low-opacity Mushaf page header. |
| `06_mushaf_divider.png` | Decorative divider above Mushaf Quran text. |
| `07_mushaf_corner_tl.png` | Small, low-opacity header corner outside Quran text. |
| `08_mushaf_corner_tr.png` | Small, low-opacity header corner outside Quran text. |
| `09_mushaf_footer_ornament.png` | Low-opacity footer outside Quran text. |
| `10_mushaf_paper_texture.webp` | Eight-percent-opacity Mushaf paper texture. |
| `11_islamic_pattern_dark.webp` | Low-opacity Ask header pattern. |
| `12_mosque_silhouette.webp` | Worship prayer-priority hero. |
| `13_open_quran_illustration.webp` | Home Continue Quran and Quran hub hero. |
| `14_closed_quran_illustration.webp` | Library header. |
| `15_tasbeeh_illustration.png` | Tasbeeh tile in Worship. |
| `16_qibla_compass_illustration.png` | Qibla tile in Worship. |
| `17_adhkar_illustration.png` | Adhkar tile in Worship. |
| `18_dua_illustration.png` | Dua tile in Worship. |
| `19_hijri_calendar_illustration.png` | Islamic-day tile in Worship. |
| `21_empty_no_results.webp` | Search and Listening no-results states. |
| `22_empty_no_bookmarks.webp` | Empty bookmarks page. |
| `24_empty_no_khatma.webp` | Khatma creation state. |

## Intentionally unused

- `20_empty_general.webp` is not used because every currently touched empty
  state has a more specific message or artwork.
- `23_empty_no_history.webp` is not used because Listening history is a section
  of the real Listening library, not a standalone empty page. Library reports
  its empty count compactly instead of showing another large illustration.

Backgrounds use cover fitting, illustrations use contain fitting, aspect ratios
are preserved, and text-over-art surfaces use dark gradients. Mushaf ornament
is outside the canonical glyph area and remains subordinate to readability.
