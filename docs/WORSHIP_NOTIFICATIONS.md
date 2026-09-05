# Worship notification behavior and Android limits

- Enabled reminders are reconciled at app startup. Prayer reminders use the
  existing location/prayer service and schedule a bounded today-and-tomorrow
  horizon; the app refreshes that horizon when it resumes and at a detected
  date rollover. It never requests background location.
- `flutter_local_notifications` persists scheduled entries and its declared
  boot receiver restores them after `BOOT_COMPLETED` and
  `MY_PACKAGE_REPLACED`. Device vendors may still delay alarms, disable
  autostart, or clear schedules when an app is force-stopped.
- The device timezone is read again whenever the app resumes, after which all
  enabled prayer schedules are refreshed from the existing prayer service.
  Android does not guarantee Dart code can run at the instant of every
  timezone change while the app is terminated, so the next startup/resume is
  the guaranteed application-level reconciliation point.
- Exact delivery uses `SCHEDULE_EXACT_ALARM` only after an explicit user action
  and capability check. If Android withholds special access, prayer reminders
  remain enabled with inexact delivery. `USE_EXACT_ALARM` is intentionally not
  declared.
- Notification permission is requested only when the user enables a reminder
  or sends a test. The status card links to Android notification settings when
  notifications are blocked.
- Android notification-channel sound is immutable once a channel exists. The
  bundled Adhan therefore uses the deterministic `adhan_v1` channel; a future
  sound/configuration change must intentionally increment that version.
