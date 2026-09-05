# Google Play Data Safety draft

Draft only; Ahmed Haggag must answer the current Play Console form and confirm third-party terms.

| Data/behavior | Current implementation | Draft disclosure |
|---|---|---|
| Precise location | Permission-gated prayer/Qibla; prayer refresh sends coordinates to AlAdhan | Collected/transmitted for app functionality when used; not sold; not used for ads |
| App activity/personal state | Stored locally in SharedPreferences | Not transmitted by the developer; user may export a backup |
| Audio requests | Requested reciter/ayah and network metadata reach EveryAyah | Network/service interaction for app functionality |
| Diagnostics | No analytics or cloud crash SDK | Not collected remotely by the app |
| Account/contact | No account; support email is outbound user choice | Not collected in-app |

Encryption in transit: HTTPS for known runtime endpoints. Deletion: uninstall/local clearing; exported files remain under user control. Account deletion is not applicable.
