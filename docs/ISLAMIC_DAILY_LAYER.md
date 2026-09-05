# Islamic Daily Layer V1: calculation and content policy

## Calendar engine

The app uses `hijri_core` 1.0.1 with its default Umm al-Qura engine. Conversion is local and table-driven. The package documents a 184-entry KACST-derived Umm al-Qura table covering Hijri 1318–1500 (approximately Gregorian 1900–2076), binary-search conversion, reverse Hijri-to-Gregorian conversion and an MIT license.

Source: https://pub.dev/packages/hijri_core

The app converts civil date components at UTC midnight to avoid host-timezone drift. A user adjustment of only -1, 0 or +1 day is applied before conversion and inverted for reverse conversion. Every result is described as a calculated Hijri date. It is not represented as an official local moon-sighting announcement.

Visible disclaimer:

> تاريخ هجري محسوب وفق تقويم أم القرى، وقد يختلف عن الإعلان الرسمي حسب رؤية الهلال في بلدك.

## Occasion rules

V1 contains date markers, not narratives or legal rulings:

- 1 Muharram: beginning of Muharram — calculated date.
- 10 Muharram: Ashura — calculated date.
- 1 Ramadan: beginning of Ramadan — calculated date.
- 1 Shawwal: first of Shawwal — calculated date.
- 9 Dhul-Hijjah: Day of Arafah — calculated date.
- 10 Dhul-Hijjah: tenth of Dhul-Hijjah — calculated date.

All markers inherit the moon-sighting disclaimer. Laylat al-Qadr is intentionally not reduced to one guaranteed calendar date. No historical or devotional narrative is generated.

## Fasting indicators

Monday and Thursday are derived from the device civil weekday. The white-day indicator is derived from calculated Hijri days 13, 14 and 15. These are calm calendar indicators only; the app does not score, pressure or claim that a user fasted.

References:

- Monday/Thursday: Jami` at-Tirmidhi 747, https://sunnah.com/tirmidhi:747
- Days 13, 14 and 15: Sunan Abi Dawud 2449, https://sunnah.com/abudawud:2449
- Moon-sighting variability boundary: Sahih Muslim, Book of Fasting, chapter 2, https://sunnah.com/muslim/13/14

## Prayer-derived calculations

The Daily layer never recalculates prayer times. It consumes Prayer V2's already configured and manually adjusted effective times.

- Night duration: Maghrib to the following Fajr.
- Calculated midpoint: Maghrib plus one half of that duration.
- Calculated last-third start: Maghrib plus two thirds of that duration.
- Dhuha guidance window: Sunrise plus 20 minutes through Dhuhr minus 10 minutes.

The Dhuha offsets are conservative product guard bands. The UI labels the result as calculated guidance and explicitly does not claim a jurisprudential optimum time.

## Notifications and privacy

All Daily reminders default off and remain local. Fasting reminders use the user-selected time on the previous evening. Last-third and Dhuha reminders require effective Prayer V2 data. Stable IDs are 7001, 7002, 7013–7015, 7101 and 7102; schedules are cancelled before reconciliation to prevent duplicates. No calendar API, account, analytics, cloud service or Quran text is involved.
