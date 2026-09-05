# Grounded Islamic Assistant V1

`اسأل` is a bounded local assistant, not a mufti and not an open-ended chatbot. No LLM/provider, API credential, cloud account, or generated religious explanation is configured.

The intent service normalizes natural Arabic and classifies navigation, Quran coordinate retrieval, translation, Tafsir, word meanings, prayer time, Qibla, Adhkar/Dua, Tasbeeh, Khatma, and memorization actions. Navigation stays deterministic. Retrieved answers use the already-loaded canonical Quran or checksum-validated bundled study repositories.

Responses structurally separate `نص المصدر` from optional `ملخص المساعد` and carry explicit citation records. V1 does not generate summaries. Quran/study citations include Surah/Ayah and resource identity; prayer answers identify the on-device calculation state. Exact citation navigation remains a follow-up improvement.

Fatwa, halal/haram, marriage/divorce, finance, madhab, and personalized ruling language routes to an explicit boundary response. It never attempts an answer from model memory. Unsupported questions state that local sources are insufficient.

No bookmarks, memorization history, Khatma state, location, or settings are sent externally. Prayer and audio services remain separate app data flows documented in the privacy audit. A future provider must be opt-in, receive only the minimum retrieved public source context, add no personal state, and refuse operation without sufficient grounding.
