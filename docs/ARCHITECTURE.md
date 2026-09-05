# Architecture

Muslim Companion is an Arabic-first Flutter/Material application. `QuranApp` loads the canonical Quran, while `MainShell` owns shared feature controllers and five retained primary tabs. Secondary screens use bounded `MaterialPageRoute` navigation. Feature code lives under `lib/features`, durable models/repositories under `lib/data`, and platform/service adapters under `lib/core`.

State is local SharedPreferences with versioned JSON records and migration validation. Quran, study and worship resources are bundled, immutable, provenance-documented and checksum-validated. AlAdhan prayer lookup and EveryAyah streaming are the only runtime network services. Ask is deterministic and provider-free.

Security boundaries are the canonical Quran invariant, explicit internal-route allowlist, backup section allowlist, checksum-gated resources, release signing gate and absence of embedded secrets. MainShell remains a large but intentional composition root; it was not refactored merely for line count.
