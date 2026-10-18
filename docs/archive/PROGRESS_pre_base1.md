# Memora — Build Progress

**Last updated:** 2026-10-17 16:23 IST  
**Current prompt:** P1 — Multi-caregiver links  
**NEXT ACTION:** Start P2 — Reminders core (data model, scheduling, patient confirmation UI)

---

## Step Table

| Step | Status | Files Touched | Notes |
|------|--------|---------------|-------|
| P0: Save & Audit | DONE | — | Committed WIP; flutter analyze run |
| P1: AGENT_RULES.md | DONE | AGENT_RULES.md | Exact content from prompt |
| P1: PROGRESS.md | DONE | PROGRESS.md | This file |
| P1: Multi-caregiver links | DONE | See below | All deliverables complete (previous session) |
| P2: Reminders core | IN PROGRESS | See below | Steps 1-4 of prompt |
| P3: Image reminders + alerts escalation + SOS | TODO | — | — |
| P4: Safe zone | TODO | — | — |
| P5: Weekly report + dashboard + final test | TODO | — | — |

---

## P1 Multi-Caregiver Links — DONE

### Deliverables (all complete)
- [x] `LinkModel` — role/priority/status/approvedBy/approvedAt (`lib/data/models/link_model.dart`)
- [x] Migration script — existing links → primary, priority 1, active (`functions/scripts/migrate_links.ts`)
- [x] CF `requestLink(patientId)` — first caregiver → primary+active; subsequent → secondary+pending; rejects dupes + 4th secondary (`functions/src/index.ts`)
- [x] CF `respondToLink(linkId, approve)` — primary only; approve assigns free priority 2-4; reject → rejected (`functions/src/index.ts`)
- [x] CF `removeSecondary(linkId)` — primary only; marks removed, cleans index (`functions/src/index.ts`)
- [x] CF helper `sendToUsers(uids, payload)` — sends FCM, removes stale tokens via arrayRemove (`functions/src/index.ts`)
- [x] Firestore rules — pending/rejected/removed = no access; primary = full; active secondary = read + ack-only alert update (`firestore.rules`)
- [x] `caregiverLinks/{uid}/patients/{patientId}` secondary index — written by CF, used by rules for fast role checks
- [x] `LinkRepository` — callable wrappers + Firestore streams (`lib/data/repositories/link_repository.dart`)
- [x] `AuthService` — requestLink/respondToLink/removeSecondary/updateFcmToken wrappers (`lib/data/services/auth_service.dart`)
- [x] `auth_providers.dart` — caregiverLinksProvider, patientLinksProvider, CaregiverManagementNotifier (`lib/features/auth/auth_providers.dart`)
- [x] `CaregiversScreen` — primary sees pending/active secondaries, approve/reject/remove buttons + badge (`lib/features/caregiver/caregivers_screen.dart`)
- [x] `CaregiverHomeScreen` — pending secondary sees "Waiting for approval"; primary sees badge button (`lib/features/caregiver/caregiver_home_screen.dart`)
- [x] `PatientHomeScreen` — reads active linked caregiver names (read-only), shows primary/secondary labels (`lib/features/patient/patient_home_screen.dart`)
- [x] `functions/package.json` — firebase-admin v12, firebase-functions v5, TypeScript support
- [x] `functions/tsconfig.json` — TypeScript config
- [x] FCM token store — arrayUnion on login/refresh, arrayRemove on logout (via `UserRepository`)

---

## Manual Steps Pending for the User

1. **Deploy Cloud Functions:**
   ```
   cd functions
   npm install
   npm run build
   firebase deploy --only functions
   ```
2. **Deploy Firestore rules:**
   ```
   firebase deploy --only firestore:rules
   ```
3. **Run one-time migration** (only if you have existing links without the `role` field):
   ```
   # Set GOOGLE_APPLICATION_CREDENTIALS first
   npx ts-node functions/scripts/migrate_links.ts
   ```
4. **Add SHA-1 fingerprint** to Firebase console (Project Settings → Android app) so Cloud Functions are callable from the APK.
5. **Enable Firebase Storage** in the Firebase console (needed for P3 image reminders).

---

## Known Issues

- `functions/index.js` stub still exists alongside `functions/src/index.ts`. Firebase should deploy from `src/` (configured in package.json). The `index.js` stub can be removed after confirming deploy works.
- `android/app/src/main/AndroidManifest.xml` has `YOUR_API_KEY_HERE` placeholder for Maps. Must be replaced with real key from `android/local.properties` at build time (or use a build.gradle substitution).
- `flutter_background_service` is registered in AndroidManifest but the package is no longer in pubspec.yaml — this may cause a build issue. Will be re-added in P4 (safe zone) if needed, or removed from manifest.
