# MEMORA BASE-2 Progress

Last updated: 2026-10-18
Current phase: Phase 2 — Accounts, onboarding and care circle (Free Mode)
NEXT ACTION: Complete P2.5 auth responsiveness and purple theme, then stop for phone testing.

| Step | Status | Files | Notes |
|---|---|---|---|
| P1.0 Save BASE-2 protocol | DONE | AGENTS.md, docs/BASE_PLAN.md, docs/archive/ | Existing base/foundation branch preserved; WIP saved as 58bbe46. |
| P1.1 Structure, design system, router, flags, developer shell | DONE | lib/, test/route_guard_test.dart | DONE: P1.1. Flutter analyze clean; guarded routes, shared themes, extensions and dev shell. |
| P1.2 Backend/Android housekeeping and docs | DONE | functions/, android/, docs/, README.md | DONE: P1.2. Analyze clean; Node 22, lockfile, indexes, Maps detection, minSdk 26, unused alarm scheduling removed. |
| P1.3 End-of-phase checks | DONE | PROGRESS.md | Phase 1 checks were blocked where Firebase required Blaze; release APK result remains pending from the prior session. |
| P2.0 Free-mode constraints | DONE | docs/FREE_MODE.md, PROGRESS.md | Spark plan recorded; `flutter analyze` clean. |
| P2.1 Atomic registration and email index | DONE | lib/, PROGRESS.md | Patient root, email index, onboarding state, and rollback-safe Auth flow added; `flutter analyze` clean. |
| P2.2 Client transaction linking | DONE | lib/data/repositories/link_repository.dart, lib/data/models/link_model.dart | Spark transactions now support requests, email backups, approval/rejection, removal, counters, and mirrors; `flutter analyze` clean. |
| P2.3 Onboarding and care circle UI | DONE | lib/, firestore.rules, docs/rules_tests.md | Patient onboarding, live care-circle links, backup-by-email, approval/rejection/removal, and Spark rules are wired; `flutter analyze` clean. |
| P2.4 Auth redirect and patient profile creation | DONE | lib/, firestore.rules | Signed-out users reach Login; incomplete patients complete and save a profile before entering the main app. `flutter analyze` clean. |
| P2.5 Auth responsiveness and purple theme | IN PROGRESS | lib/, test/ | Auth and palette migration are clean. Remaining work: widget overflow/navigation tests and final overflow audit. |
| P3 Alerts and safe zone | TODO | lib/, functions/ | Phone acceptance required. |
| P4 Reminders | TODO | lib/, functions/ | Server delivery and migrations pending. |
| P5 Polish, docs, deploy, APK, tag | TODO | docs/, README.md | v0.1-base only after completion. |

## Manual steps pending for the user
- From repo root, after Phase 2 rules are complete: `firebase deploy --only firestore:rules,firestore:indexes --project memora-3b359`.
- Do not run that command from the app automatically; the owner must run it after reviewing the rules.
- Do not deploy functions or Storage in Free Mode.
- Optional Maps key: set MAPS_API_KEY in android/local.properties, never in Git. Run `cd android` then `.\gradlew.bat signingReport`; add that machine's debug SHA-1/package name to the Maps key restriction and Firebase if needed.
- Use Node.js 22 locally; this machine has Node 20.20.0. Functions target Node 22 and TypeScript build passed on the installed runtime.
- Phone tests: follow docs/TESTING.md; no device testing has been performed here.
- Phone test: register a patient and confirm the six-character ID; link caregiver 1 and confirm primary access.
- Phone test: link caregiver 2, approve it from the primary, add a backup by email, and verify pending caregivers cannot read patient data.
- Phone test: try a fourth backup, then log out and back in on both phones to confirm links remain.

## Known issues
- Existing BASE-1 plan and progress archived; BASE-2 is authoritative.
- MVP-0 uses real Firebase Auth and Firestore data; earlier UI-only/fake-data ideas are set aside.
- Release signing uses debug keys for phone testing only.
- Reminders, alerts, safe zone, SOS, medicine, voice, and ML report remain out of scope; existing functions are intentionally unused in Free Mode.
- Firebase deployment was previously blocked by the Blaze requirement; no deployment success is claimed.
- npm install reported 17 dependency vulnerabilities (12 moderate, 4 high, 1 critical); dependency audit/upgrade remains pending.
- Firestore rules compiled, with warnings in the unused isSecondaryCaregiver helper (lines 35–38); review in Phase 2.
- Location foreground service belongs to Phase 3 when geolocator is installed; permission declarations alone do not implement monitoring.

## Phase 1 verification
- `flutter analyze`: No issues found (after each implementation step).
- `flutter test test/route_guard_test.dart`: four tests passed.
- `cd functions && npm run build`: passed; importing compiled functions also passed.
- Firebase predeploy build passed. Rules compiled successfully; deploy then failed:
  `Error: Your project memora-3b359 must be on the Blaze (pay-as-you-go) plan to complete this command. Required API cloudbuild.googleapis.com can't be enabled until the upgrade is complete.`
- Storage attempt failed: `Firebase Storage has not been set up on project 'memora-3b359'.`
- Main Android manifest permissions and Maps placeholder verified; minSdk = 26.
- Release APK build: running; result pending.
