# Memora – Project Status Audit
_Generated: 2026-10-17 | Branch: `clean-foundation`_

---

## 1. Git
| Item | Value |
|---|---|
| Branch | `clean-foundation` |
| Uncommitted | `auth_service.dart`, `notification_service.dart`, `auth_providers.dart`, `login_screen.dart` (M) + `MASTER_PLAN.md` (untracked) |
| Last 15 commits | WIP saves, WIP → analyze fixes, location/safe-zones, reminder snooze/delete, reminder management, layout overflow fix, reminder module init, minSdk/imports fixes, Cloud Functions init, initial commit |

---

## 2. Stack
| Layer | Detail |
|---|---|
| Flutter/Dart SDK | Dart `^3.7.2`, Flutter (resolved via `.flutter-plugins`) |
| State management | Riverpod 2.5 (`flutter_riverpod`) |
| Navigation | Imperative `Navigator.push` / `MaterialPageRoute` — **no named routes** |
| Firebase | core 3, auth 5, firestore 5, functions 5, messaging 15, storage 12 |
| UI | `google_fonts`, `cached_network_image`, `image_picker`, `flutter_image_compress`, `badges` |
| Notifications | `flutter_local_notifications 18`, `timezone`, `permission_handler` |
| **Functions runtime** | Node.js 18, TypeScript, `firebase-admin ^12`, `firebase-functions ^5`, `date-fns ^3` |

**Cloud Functions** (`functions/src/index.ts`):
| Name | Trigger | Purpose |
|---|---|---|
| `requestLink` | HTTPS callable | Caregiver requests link to patient; auto-assigns primary/secondary role |
| `respondToLink` | HTTPS callable | Primary caregiver approves/rejects secondary link |
| `removeSecondary` | HTTPS callable | Primary removes a secondary caregiver |
| `notifyUsers` | HTTPS callable | Client-triggered FCM send (missed reminders, SOS) |
| `scheduleReminderOccurrences` | Scheduled every 15 min | Pre-generates deterministic occurrence docs 48 h ahead |

---

## 3. Folder Structure (2 levels) & Screens
```
lib/
  main.dart               app entry point
  app.dart                AuthGate + routing
  core/constants/         AppConstants
  core/errors/            AppErrorHandler
  core/theme/             AppTheme
  data/models/            user, link, reminder, patient (safeZone, alert, week)
  data/repositories/      user, link, reminder
  data/services/          auth_service, notification_service
  features/auth/          login, register, role_selection, auth_providers
  features/linking/       linking_screen
  features/patient/       patient_home_screen
  features/caregiver/     caregiver_home_screen, caregivers_screen
  features/reminders/     reminders_screen, reminder_providers
  functions_helpers/      send_to_users.dart (stub/helper)
```

| Route (push) | File | Role | Purpose | Status |
|---|---|---|---|---|
| `/` (AuthGate) | `app.dart` | both | Auth → role-based routing | **Working** |
| LoginScreen | `features/auth/login_screen.dart` | both | Email/password login | **Working** |
| RoleSelectionScreen | `features/auth/role_selection_screen.dart` | both | Pick patient/caregiver before register | **Working** |
| RegisterScreen | `features/auth/register_screen.dart` | both | Create account with role | **Working** |
| PatientHomeScreen | `features/patient/patient_home_screen.dart` | patient | Shows patient ID, reminders, linked caregivers | **Partial** (no SOS, no safe-zone UI) |
| CaregiverHomeScreen | `features/caregiver/caregiver_home_screen.dart` | caregiver | Dashboard (Reminders only card visible) | **Partial** |
| CaregiversScreen | `features/caregiver/caregivers_screen.dart` | primary caregiver | Manage secondary caregivers | **Working** |
| RemindersScreen | `features/reminders/reminders_screen.dart` | caregiver | CRUD reminders (primary) / read-only (secondary) | **Partial** |
| LinkingScreen | `features/linking/linking_screen.dart` | caregiver | Enter patient ID to link | **Working** |

---

## 4. Registration & Onboarding Flow
1. **RoleSelectionScreen** – user picks `patient` or `caregiver`.
2. **RegisterScreen** – collects name, email, password → calls `AuthService.register()`.
3. `register()` creates Firebase Auth user; if patient, generates a **6-char alphanumeric patientId** (`Random.secure()` from charset `ABCEFGHJKLMNP…` — O/0/1/I omitted) in a retry loop (max 20) checking uniqueness in Firestore.
4. Writes `users/{uid}` with `{uid, role, name, email, patientId?, fcmTokens:[], createdAt}`.
5. FCM token stored via `arrayUnion` immediately after auth.
6. **Linking** (caregiver side): caregiver opens LinkingScreen, enters patient ID → calls `requestLink` Cloud Function.
   - No existing primary → new link is `active primary` + `caregiverLinks/{cgUid}/patients/{patientId}` written.
   - Primary exists → new link is `pending secondary`; FCM push to primary caregiver.
   - Primary approves → `respondToLink` CF activates link, writes `caregiverLinks` index.
7. `_AuthGate` watches `firebaseAuthStateProvider` → routes to role-specific home.

---

## 5. Firestore
**Collections used in code:**
`users`, `links`, `caregiverLinks/{uid}/patients`, `patients/{pid}/reminders`, `patients/{pid}/reminderOccurrences`, `patients/{pid}/reminderEvents`, `patients/{pid}/safeZones`, `patients/{pid}/alerts`, `patients/{pid}/weeks`

**Security rules summary:**
- `users/{uid}`: owner-only read; create enforces role/name/email/createdAt; update blocks role change and patientId change; no delete. ✅
- `links/{id}`: participant-only read; all writes via admin SDK (callables). ✅
- `caregiverLinks`: caregiver can read own index; no client writes. ✅
- `reminders`: patient-self or linked can read; only primary caregiver can write. ✅
- `reminderOccurrences`: patient can only update status/snooze fields; primary can do all. ✅
- `reminderEvents`: patient creates (immutable); no update/delete. ✅
- `safeZones`: primary only can create/update; delete=false. ✅
- `alerts`: patient creates; linked caregivers can ack; delete=false. ✅
- `weeks`: admin-only write. ✅
- Default deny-all catch-all present. ✅

**⚠️ No dangerously open rules found.** Rules are well-structured.

`firestore.indexes.json`: **Exists** (6 indexes: reminders, reminderLogs, locationLogs, alerts, dailyBehavior, weeklySummaries — several indexes reference stale collection names `reminderLogs`, `locationLogs`, `dailyBehavior`, `weeklySummaries` not used in current code).

---

## 6. Feature Table
| Feature | Status | Evidence | Known Bugs |
|---|---|---|---|
| Reminders (CRUD + schedule) | **Partial** | `reminders_screen.dart`, `reminder_providers.dart`, CF `scheduleReminderOccurrences` | `weekly` recurrence hardcoded to Monday only |
| Safe Zone monitoring | **Not started** (model exists) | `patient_models.dart` has `SafeZoneModel`; no UI screen, no geofence service | — |
| SOS alerts | **Not started** (model exists) | `AlertModel` with type `sos`; no button/trigger in UI | — |
| Alerts / FCM notifications | **Partial** | `notification_service.dart`, `notifyUsers` CF | Maps API key hardcoded empty in manifest |
| Medicine tracking | **Not started** | No dedicated model or screen | — |
| Voice/speech | **Not started** | No package, no screen | — |
| ML weekly report | **Not started** (model exists) | `WeekModel` in `patient_models.dart`; `weeks` rule admin-only; no CF | — |
| Images (reminder) | **Partial** | `image_picker` + `firebase_storage` in pubspec; `imageUrl` in reminder model; not wired in UI | — |

---

## 7. Android
| Item | Value |
|---|---|
| minSdk | **23** |
| applicationId | `com.memora.memora` |
| Signing | Release uses **debug keys** (TODO comment in build.gradle.kts) |
| Permissions | INTERNET, RECEIVE_BOOT_COMPLETED, SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM, POST_NOTIFICATIONS, WAKE_LOCK, ACCESS_FINE/COARSE/BACKGROUND_LOCATION, FOREGROUND_SERVICE, FOREGROUND_SERVICE_LOCATION, REQUEST_IGNORE_BATTERY_OPTIMIZATIONS |
| Notification channel | `memora_reminders` (declared in `notification_service.dart`) |
| Foreground service | Permission declared; **no foreground service class registered** in manifest |
| Maps key injection | `com.google.android.geo.API_KEY` meta-data present but **value is empty string** — Maps will fail at runtime |
| `flutter analyze` | ✅ **1 info only** — `_caregiverUid` local var starts with underscore (`auth_providers.dart:179`) — no errors, no warnings |

---

## 8. Firebase
| Item | Value |
|---|---|
| Project ID | `memora-3b359` |
| Products used | Auth, Firestore, Cloud Functions, FCM, Storage |
| Functions code present | ✅ `functions/src/index.ts` compiled to JS |
| Deployed status | **Unknown** — CLI login state not verified; `lib/` compiled JS not present in `functions/lib/` |
| `firebase.json` | Present (hosting + functions configured) |

---

## 9. Top 10 Problems (Ranked)
| # | Severity | Problem | Area | Recommendation |
|---|---|---|---|---|
| 1 | 🔴 Security | Release build uses debug signing keys | Android | **REFACTOR** – add proper keystore before release |
| 2 | 🔴 Security | Google Maps API key is empty string in manifest | Android | **REFACTOR** – inject via `local.properties` / CI secret |
| 3 | 🔴 Bug | No foreground service registered in manifest despite location perms declared | Android | **REFACTOR** – register or remove unused permissions |
| 4 | 🟠 Bug | `weekly` recurrence fires only on Mondays (hardcoded in CF) | Functions | **REFACTOR** – add `daysOfWeek` field to reminder model |
| 5 | 🟠 Bug | `firestore.indexes.json` references stale collections (`reminderLogs`, `locationLogs`, `dailyBehavior`, `weeklySummaries`) | Firestore | **REFACTOR** – align indexes with active schema |
| 6 | 🟠 Tech debt | `functions/lib/` (compiled JS) absent — deploy will fail unless `npm run build` is run first | Functions | **REFACTOR** – add build step to CI/deploy script |
| 7 | 🟡 Tech debt | No named routes / `go_router` — imperative navigation will not scale | Flutter nav | **REFACTOR** – adopt `go_router` |
| 8 | 🟡 Tech debt | Caregiver dashboard has only one card (Reminders); SOS, safe-zone, alerts screens not built | Feature gap | **REWRITE** (these screens) |
| 9 | 🟡 Tech debt | `StateNotifierProvider` used (deprecated pattern) instead of `NotifierProvider` | State mgmt | **REFACTOR** – migrate to Riverpod 2 Notifier API |
| 10 | 🟡 Tech debt | Auth rollback only deletes Firebase Auth user; Firestore doc may have been partially written with no cleanup | Auth | **REFACTOR** – use batch write or handle partial writes |

### Area Recommendations
| Area | Verdict |
|---|---|
| Auth + onboarding flow | **KEEP** – solid, well-tested |
| Firestore rules | **KEEP** – well-structured, no open rules |
| Cloud Functions (linking + scheduling) | **KEEP** – clean callable design |
| Reminder feature | **REFACTOR** – fix weekly recurrence, wire image UI |
| Android manifest + signing | **REFACTOR** – Maps key, signing, foreground service |
| Safe zone / SOS / alerts / voice / ML | **REWRITE** – not started |
| Navigation | **REFACTOR** – adopt go_router |
