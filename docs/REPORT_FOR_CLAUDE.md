# MEMORA PROJECT STATUS REPORT (FOR CLAUDE / NEXT ASSISTANT)

**Document Type:** Read-Only Technical Audit & Status Report  
**Active Workspace:** `e:\memora-main` (Git repository at `e:\Pro\memora`, branch `mvp/linking`)  
**Architecture Baseline:** BASE-2 (`docs/BASE_PLAN.md`, `docs/FREE_MODE.md`, `PROGRESS.md`)  
**Date:** 2026-10-20  

---

## 1. Git Status & History
- **Current Branch:** `mvp/linking` (in origin repo `e:\Pro\memora`; workspace `e:\memora-main` is unversioned mirror/copy).
- **Branches & Tags:**
  - Branches: `mvp/linking` (active), `main`, `base/foundation`, `clean-foundation`, `legacy-backup`, remotes `origin/main`, `origin/mvp/linking`.
  - Tags: None.
- **Uncommitted Files:** `M README.md` (in `e:\Pro\memora`). Workspace `e:\memora-main` has untracked runtime artifacts (`serve_nocache.py`, `MEMORA_PROJECT_AUDIT.md`).
- **Last 20 Commits:**
  - *Branch `mvp/linking` & shared:*
    1. `a37af56` Caregiver linking, profile screen and rules update
    2. `2e8016a` features added
    3. `9130d85` feat: Implement Location-Based Safe Zones & Reminders with Background Tracking and Custom Sounds
    4. `4d00c22` Enhance Reminder Module: Add snooze toggle, deletion preservation, role visibility guards, and FCM cloud triggers
    5. `5b92184` Enhance reminder management module: Local notification triggers, snooze support, completedAt logs, caregiver notification sync, adherence scoring dashboard, unit and provider test suites
    6. `2d02f1e` fix: resolve layout overflow by setting isExpanded true on DropdownButtonFormFields
    7. `265104b` feat: implement Reminder Management Module, database rules, and comprehensive unit tests
    8. `46a11bf` Fix import conflicts, JVM memory crash, minSdkVersion requirements, and migrate user operations to client-side Firestore
    9. `ad362fb` feat: Initialize Memora Flutter App and Firebase Cloud Functions backend
    10. `1b8f11c` Initial commit
  - *Branch `base/foundation` & `clean-foundation` (parallel AI sessions):*
    11. `cea285b` WIP: saved from previous session
    12. `1d8052f` WIP: saved from previous session
    13. `8f96e25` chore: finish platform housekeeping and start phase checks
    14. `d013c32` docs: start foundation platform and backend checks
    15. `21d7b8e` feat: complete foundation structure and guarded navigation
    16. `9b8ea2b` docs: adopt BASE-2 and start foundation completion
    17. `58bbe46` WIP: saved from previous session
    18. `6a5f4a5` WIP: saved from previous session
    19. `c8e6bcc` chore(A1-A4): analyze clean, delete dead code, clean indexes, fix weekly CF bug, add Node20+predeploy
    20. `2a08228` chore: save BASE_PLAN.md, archive old progress, create fresh PROGRESS.md, create base/foundation branch
- **Most Changed Areas:** Multiple tools (Antigravity, Codex, Copilot) touched: `lib/features/auth/`, `lib/data/repositories/` (`user_repository.dart`, `link_repository.dart`), `lib/core/router/`, `firestore.rules`, and `functions/src/index.ts`.

---

## 2. Screens and Routes
| Route | Screen / File | Role | Description | Status in Code |
|---|---|---|---|---|
| `/` | `RoleSelectionScreen` (`lib/features/auth/presentation/role_selection_screen.dart`) | Both | Welcome / Role chooser ("I need care" vs "I am a caregiver") | Built in code |
| `/login` | `LoginScreen` (`lib/features/auth/presentation/login_screen.dart`) | Both | Email/password login with error banner and navigation | Built in code |
| `/register` | `RegisterScreen` (`lib/features/auth/presentation/register_screen.dart`) | Both | Account signup based on role query parameter | Built in code |
| `/forgot-password` | `_FeatureShell` (`lib/core/router/app_router.dart:88`) | Both | Password reset shell placeholder | Partial (Shell only) |
| `/onboarding/patient` | `PatientOnboardingScreen` (`lib/features/onboarding/presentation/patient_onboarding_screen.dart`) | Patient | Name, age, details input, generates 6-char ID | Built in code |
| `/patient/home` | `PatientHomeScreen` (`lib/features/patient_home/presentation/patient_home_screen.dart`) | Patient | Massive patient UI (carousel, medicine prompt, SOS, contacts) | Built in code |
| `/patient/medicine` | `_PatientMedicineDispatcher` (`lib/core/router/app_router.dart:104`) | Patient | Routes incoming reminder occurrence vs already taken screen | Built in code |
| `/patient/medicine/confirmed` | `MedicineTakenConfirmationScreen` (`lib/features/medicine/presentation/...`) | Patient | Celebration / confirmation screen after medication logged | Built in code |
| `/patient/medicine/already-taken` | `MedicineAlreadyTakenScreen` (`lib/features/medicine/presentation/...`) | Patient | State indicating medications have been taken | Built in code |
| `/patient/refills` | `PatientRefillsScreen` (`lib/features/reminders/presentation/...`) | Patient | Prescription refills list and status | Built in code |
| `/patient/contacts` | `EmergencyContactsScreen` (`lib/features/emergency_contacts/presentation/...`) | Patient | Direct call emergency contacts screen | Built in code |
| `/patient/profile` | `_FeatureShell` (`lib/core/router/app_router.dart:124`) | Patient | Phase 2 profile placeholder | Partial (Shell only) |
| `/onboarding/link-patient` | `LinkingScreen` (`lib/features/onboarding/presentation/linking_screen.dart`) | Caregiver | Input 6-char patient code to initiate link | Built in code |
| `/caregiver/home` | `CaregiverHomeScreen` (`lib/features/caregiver_home/presentation/...`) | Caregiver | Active/pending view, patient summary, bottom navigation shell | Built in code |
| `/caregiver/profile` | `CaregiverProfileScreen` (`lib/features/caregiver_home/presentation/...`) | Caregiver | Displays caregiver account details and logout | Built in code |
| `/caregiver/reminders` | `RemindersScreen` via `_CaregiverReminders` (`lib/features/reminders/...`) | Caregiver | Reminder creation, toggle, edit, schedule list | Built in code |
| `/caregiver/contacts` | `EmergencyContactsScreen` (`lib/features/emergency_contacts/presentation/...`) | Caregiver | Caregiver-side emergency contacts management | Built in code |
| `/caregiver/care-circle` | `CaregiversScreen` (`lib/features/care_circle/presentation/...`) | Caregiver | Primary/backup caregiver management, approve/reject secondary | Built in code |
| `/caregiver/safe-zone` | `_FeatureShell` (`lib/core/router/app_router.dart:154`) | Caregiver | Safe zone setup placeholder (Phase 3) | Partial (Shell only) |
| `/caregiver/alerts` | `_FeatureShell` (`lib/core/router/app_router.dart:160`) | Caregiver | Alerts log list placeholder (Phase 3) | Partial (Shell only) |
| `/dev-tools` | `DevToolsScreen` (`lib/features/dev_tools/presentation/dev_tools_screen.dart`) | Both | Developer debugging shell (state switcher, route inspection) | Built in code |

---

## 3. Auth and Onboarding Flow
1. **Welcome & Role Selection:** User taps "I need care" or "I am a caregiver" on `RoleSelectionScreen`, routing to `/register?role=patient` or `/register?role=caregiver`.
2. **Registration (`AuthService.register`):**
   - Calls Firebase Auth `createUserWithEmailAndPassword`.
   - Generates a 6-character uppercase alphanumeric `patientId` (for patients) using `Random.secure()` excluding ambiguous characters (e.g., `chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'`).
   - Writes atomic batch to Firestore:
     - Patient: `users/{uid}` (name, email, role, patientId), `patients/{patientId}` (ownerUid, createdAt), `patientCodes/{patientId}` (ownerUid), and `emailIndex/{email.toLowerCase()}` (uid).
     - Caregiver: `users/{uid}` and `emailIndex/{email.toLowerCase()}`.
3. **Onboarding Guard (`route_guard.dart` & `app_router.dart`):**
   - Patients without profile document get redirected to `/onboarding/patient` (`PatientOnboardingScreen`).
   - Patients submitting profile save name, age, details, and timezone to `patients/{patientId}` and mark `onboardingDone: true` on `users/{uid}`.
   - Caregivers enter `/caregiver/home`. If unlinked, the home displays a waiting empty state prompting them to link via `/onboarding/link-patient`.

---

## 4. Linking: Architecture & Cloud Functions Status
- **Mechanism:** Done entirely via **client-side Firestore transactions and batches (Free Mode / Spark)** in `LinkRepository.dart`.
  - `requestLink`: Caregiver enters 6-character `patientId`. Checks `patientCodes/{patientId}` and `patientPrimary/{patientId}`. If primary exists, creates secondary link with status `pending`. If primary does not exist, claims primary with status `active`. Writes atomic batch to `links/{patientId}_{caregiverUid}`, `patientPrimary/{patientId}`, and mirror `caregiverLinks/{caregiverUid}/patients/{patientId}`.
  - `addBackupCaregiver`: Primary caregiver looks up email via `emailIndex/{emailLower}` and adds backup caregiver.
  - `respondToLink`: Primary caregiver updates link status (`active`/`rejected`) and mirror.
  - `removeSecondary`: Primary caregiver updates link status (`removed`) and deletes mirror.
- **Cloud Functions Status:**
  - `functions/src/index.ts` contains legacy Cloud Functions (`requestLink`, `respondToLink`, `removeSecondary`), but **NO Dart code in `lib/` imports `cloud_functions` or calls any Cloud Function**.
  - All linking and data operations are 100% client-driven Firestore transactions.

---

## 5. Firestore Collections, Rules & Index Match
- **Collections & Fields in Active Use:**
  - `users/{uid}`: `uid`, `role`, `name`, `email`, `patientId`, `fcmTokens` (array), `onboardingDone`, `createdAt`.
  - `emailIndex/{emailLower}`: `uid`.
  - `patientCodes/{patientId}`: `ownerUid`.
  - `patientPrimary/{patientId}`: `caregiverUid`.
  - `patients/{patientId}`: `ownerUid`, `name`, `age`, `details`, `timezone`, `primaryCaregiverUid`, `secondaryCount`, `createdAt`.
  - `links/{patientId_caregiverUid}`: `patientId`, `caregiverUid`, `caregiverName`, `role` (`primary`|`secondary`), `status` (`active`|`pending`|`rejected`|`removed`), `requestedBy`, `createdAt`, `respondedAt`.
  - `caregiverLinks/{caregiverUid}/patients/{patientId}`: `patientId`, `role`, `status`.
  - Subcollections under `patients/{patientId}`: `reminders`, `reminderOccurrences`, `reminderEvents`, `safeZones`, `alerts`, `contacts`, `refills`, `weeks`.
- **Security Rules (`firestore.rules`):**
  - Uses `patientSelf(patientId)`, `activeLink(patientId)`, `primaryCaregiver(patientId)`.
  - Enforces role immutability, owner-only user updates, primary caregiver approval requirements, and subcollection access constraints.
  - *Gaps / Weak spots:* Unused helper warning in older drafts; client transactions handle counter increments for `secondaryCount` which malicious clients could attempt to race without server validation.
- **Indexes (`firestore.indexes.json`):**
  - Defines composite indexes for `reminderOccurrences` (`status` ASC, `scheduledTime` ASC) and collection-group `reminderOccurrences` (`status` ASC, `nextNotifyAt` ASC).
  - Matches the occurrence querying in `reminder_providers.dart`.

---

## 6. Theme and Color Migration
- **Definition:** Defined in `lib/core/theme/app_colors.dart` (Primary Purple: `0xFF6B4FBB`, Container: `0xFFE8E0F7`, Background: `0xFFF8F6FC`, Secondary Accent: `0xFF8E6FD8`).
- **Purple Palette Status:** Applied to core widgets, buttons, auth screens, caregiver screens, and app theme.
- **Remaining Hardcoded Colors / Green / Teal Files (11 files):**
  - `lib/data/repositories/reminder_repository.dart` (contains hardcoded teal string/color fallback)
  - `lib/features/reminders/presentation/patient_refills_screen.dart`
  - `lib/features/reminders/presentation/reminders_screen.dart`
  - `lib/features/patient_home/presentation/widgets/dashboard_notification_carousel.dart`
  - `lib/features/patient_home/presentation/patient_home_screen.dart`
  - `lib/features/medicine/presentation/medicine_taken_confirmation_screen.dart`
  - `lib/features/medicine/presentation/medicine_reminder_screen.dart`
  - `lib/features/medicine/presentation/medicine_incoming_reminder_screen.dart`
  - `lib/features/medicine/presentation/medicine_already_taken_screen.dart`
  - `lib/features/emergency_contacts/presentation/emergency_contacts_screen.dart`
  - `lib/features/voice_assistant/presentation/voice_assistant_modal.dart`

---

## 7. Layout Problems Visible by Inspection
- **Unconstrained / Overflow-Prone Rows:**
  - `lib/features/patient_home/presentation/patient_home_screen.dart`: Several header and action `Row`s contain text widgets without `Flexible`/`Expanded` wrappers, risking overflow on narrow viewports or large font accessibility settings.
  - `lib/features/reminders/presentation/reminders_screen.dart`: Reminder card header row containing title and action icons lacks `Expanded` on title text.
  - `lib/features/emergency_contacts/presentation/emergency_contacts_screen.dart`: Contact details row with phone number and relationship badge lacks `Expanded`.
- **Non-Scrolling Screens:**
  - `_SessionScreen` and error builders in `lib/core/router/app_router.dart` render centered layouts without `SingleChildScrollView`, risking vertical overflow on landscape or small screens with open keyboards.

---

## 8. Packages in `pubspec.yaml`
- **State Management:** `flutter_riverpod: ^2.5.1`
- **Navigation:** `go_router: ^17.0.0`
- **Firebase:** `firebase_core: ^3.0.0`, `firebase_auth: ^5.0.0`, `cloud_firestore: ^5.0.0`, `cloud_functions: ^5.0.0` (present in pubspec but unused in code), `firebase_messaging: ^15.0.0`, `firebase_storage: ^12.0.0`
- **UI / Design:** `google_fonts: ^6.2.1`, `cached_network_image: ^3.3.1`, `image_picker: ^1.1.2`, `flutter_image_compress: ^2.3.0`, `badges: ^3.1.2`, `cupertino_icons: ^1.0.8`
- **Notifications & Scheduling:** `flutter_local_notifications: ^18.0.0`, `timezone: ^0.9.4`
- **Permissions & OS:** `permission_handler: ^11.3.1`, `url_launcher: ^6.3.3`
- **Voice / AI:** `speech_to_text: ^7.5.0`, `flutter_tts: ^4.2.5`, `google_generative_ai: ^0.4.7`
- **Utilities:** `intl: ^0.20.3`, `http: ^1.2.0`
- **Unused Packages in Active Code:** `cloud_functions` (installed but zero imports/callables in `lib/`), `firebase_storage` (installed but storage setup is disabled in Free Mode).

---

## 9. Android Configuration
- **Application ID:** `com.memora.memora`
- **minSdk:** `26` (Android 8.0 Oreo), `targetSdk`: Flutter default
- **Main Manifest Permissions (`AndroidManifest.xml`):**
  - Network & System: `INTERNET`, `POST_NOTIFICATIONS`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `RECORD_AUDIO`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
  - Location: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`.
- **Notification Channels:**
  - `memora_reminders_v2`: "Patient Reminders" (Max importance, sound, vibration).
  - `memora_alerts`: "Care Circle Alerts" (Max importance, sound, vibration).
- **Foreground Service Declarations:** Declared via permissions (`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`); service component itself is pending Phase 3 geolocator integration.
- **Maps Key Wiring:** In `build.gradle.kts`, `manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey` reads `MAPS_API_KEY` from `android/local.properties`. In `AndroidManifest.xml`, injected via `<meta-data android:name="com.google.android.geo.API_KEY" android:value="${MAPS_API_KEY}" />`. If empty, OpenStreetMap fallback is configured in `AppConfig`.

---

## 10. Feature Status Table
| Feature | Status in Code | Evidence (File Names) |
|---|---|---|
| Sign up / Log in | Built in code | `lib/features/auth/presentation/login_screen.dart`, `register_screen.dart`, `auth_service.dart` |
| Onboarding | Built in code | `lib/features/onboarding/presentation/patient_onboarding_screen.dart`, `linking_screen.dart` |
| Linking & Care Circle | Built in code | `lib/data/repositories/link_repository.dart`, `lib/features/care_circle/presentation/caregivers_screen.dart` |
| Patient Home | Built in code | `lib/features/patient_home/presentation/patient_home_screen.dart` |
| Caregiver Home | Built in code | `lib/features/caregiver_home/presentation/caregiver_home_screen.dart` |
| Reminders (CRUD/Display) | Built in code | `lib/features/reminders/presentation/reminders_screen.dart`, `reminder_repository.dart` |
| Safe Zone | Partial (Route shell only) | `lib/core/router/app_router.dart` (`_FeatureShell`), `lib/features/safe_zone/presentation/.gitkeep` |
| Alerts | Partial (Route shell only) | `lib/core/router/app_router.dart` (`_FeatureShell`), `lib/features/alerts/presentation/.gitkeep` |
| SOS | Not built (Extension README) | `lib/features/sos/README.md` (flag defaults to false in `feature_flags.dart`) |
| Medicine | Partial (Dispatcher/UI stubs) | `lib/features/medicine/presentation/medicine_taken_confirmation_screen.dart`, `README.md` |
| Voice Assistant | Partial (UI modal exists) | `lib/features/voice_assistant/presentation/voice_assistant_modal.dart`, `README.md` |
| ML Weekly Report | Not built (Extension README) | `lib/features/weekly_report/README.md` |

---

## 11. Documentation Consistency & Contradictions
- **Present Documents:** `AGENTS.md`, `AGENT_RULES.md`, `PROGRESS.md`, `README.md`, `docs/BASE_PLAN.md`, `docs/FREE_MODE.md`, `docs/ARCHITECTURE.md`, `docs/STATUS.md`, `docs/DATA_MODEL.md`, `docs/TESTING.md`.
- **Contradictions / Drift:**
  - `docs/BASE_PLAN.md` mentions callable Cloud Functions (`requestLink`, `respondToLink`), but `docs/FREE_MODE.md` superseded this by adopting Spark-compatible client Firestore transactions.
  - `pubspec.yaml` still imports `cloud_functions`, conflicting with the Free Mode policy to avoid Cloud Functions.
  - `PROGRESS.md` shows P1.0-P2.4 done and P2.5 in progress, but Git repository tracking lives in `e:\Pro\memora` while `e:\memora-main` lacks `.git`.

---

## 12. Top 10 Problems / Risks & Pending User Actions
### Top 10 Problems & Risks:
1. **Workspace Git Disconnect:** `e:\memora-main` has no `.git` folder (repo is at `e:\Pro\memora`), risking divergence between edits and Git commits.
2. **Untested on Real Devices:** All recent features are verified only in code; physical Android behavior (exact alarms, background sync) is unknown.
3. **Firestore Security Rules Deployment Pending:** Local rules in `firestore.rules` must be deployed for Spark linking to work.
4. **Hardcoded Colors & Non-Purple Palette:** 11 files still retain hardcoded colors, green, or teal instead of `AppColors`.
5. **Layout Overflow Vulnerabilities:** Key rows in `PatientHomeScreen` and `RemindersScreen` lack `Flexible`/`Expanded`.
6. **Blaze Plan Requirement Blockers:** Deploying functions or storage fails on Firebase Spark tier.
7. **Client-Side Concurrency in Free Mode:** Without Cloud Functions, link approval and secondary counts rely on client transactions.
8. **npm Dependency Vulnerabilities:** `functions/` contains moderate to critical npm vulnerabilities.
9. **Dead Package Dependencies:** `cloud_functions` and `firebase_storage` in `pubspec.yaml` add build weight despite Free Mode deprecation.
10. **Incomplete Sub-features:** Safe zone, alerts, SOS, and ML reports remain empty placeholders.

### Manual Steps Pending for User:
1. Deploy Firestore rules and indexes:  
   `firebase deploy --only firestore:rules,firestore:indexes --project memora-3b359`
2. Configure Maps Key: Set `MAPS_API_KEY` in `android/local.properties` (optional).
3. Test Phase 2 linking on two Android devices following `docs/TESTING.md`.

---

## 13. What PROGRESS.md Says Is Next
- **Current Phase:** Phase 2 — Accounts, onboarding and care circle (Free Mode).
- **NEXT ACTION:** Complete P2.5 auth responsiveness and purple theme, then stop for phone testing.
