PLAN VERSION: BASE-2
# MEMORA BASE BUILD PLAN

GOAL
Deliver a clean, working BASE that teammates can extend with feature branches:
accounts + onboarding, caregiver linking with backup caregivers, an alert
pipeline, a safe zone, reminders, and a polished UI for both roles. Real
Android phones only (min SDK 26). Firebase backend (Auth, Firestore, Cloud
Functions Node.js/TypeScript, FCM). Flutter + Riverpod + go_router.

OUT OF SCOPE (leave empty extension points only): SOS button logic, medicine
management, voice assistant, ML weekly report, reminder photos and voice notes.
Create lib/features/{sos,medicine,voice_assistant,weekly_report}/ each with only
a README.md that states which Firestore collections/functions the feature will
use and how to plug into the UI through lib/core/feature_flags.dart. Those flags
default to false, and screens render nothing for a disabled feature.

## RULES
1. Start of every session: read AGENTS.md, docs/BASE_PLAN.md and PROGRESS.md,
   check `git log --oneline -10`, continue from the first unfinished step. Check
   the real code, not only the file.
2. Before a step write "IN PROGRESS: <step>" in PROGRESS.md and commit; after it
   write "DONE: <step>" and commit. Commit after every sub-part.
3. Reuse existing code that is good (see docs/STATUS.md). Rewrite only what the
   plan changes. Delete dead code (git history keeps it). Keep code compact.
4. Run `flutter analyze` after each step. Build the release APK once at the end
   of each phase.
5. Never print, hardcode or commit API keys or service-account files. The Maps
   key lives only in android/local.properties (MAPS_API_KEY). Keep
   local.properties, .env and key files in .gitignore.
6. Never claim anything works on a device or in Firebase unless you actually ran
   it. Do not push to any remote.
7. Docs are short. PROGRESS.md format: header (last updated, current phase, NEXT
   ACTION), a table (step | TODO / IN PROGRESS / DONE | files | notes), and
   sections "Manual steps pending for the user" and "Known issues".

## CURRENT CODE (from the audit; keep what is good)
Good and kept: login/register/role selection, the 6-character patientId, the
Firestore rules (well structured), the linking callable functions
(requestLink, respondToLink, removeSecondary), the caregivers management
screen. Not built: safe zone UI/service, SOS, alerts UI, medicine, voice, ML
report. Problems to fix: release signing uses debug keys (fine for test APKs),
empty Maps key in the manifest, location permissions without a registered
foreground service, weekly recurrence only fires on Mondays, stale entries in
firestore.indexes.json, functions/lib not built before deploy, imperative
navigation, deprecated StateNotifierProvider, partial writes at registration,
and a client-callable `notifyUsers` function that is unsafe.

## ARCHITECTURE (so teammates can work in parallel)
- lib/core/: theme, design-system widgets, router, constants, error handling,
  feature_flags.dart, app_config.dart.
- lib/data/: models, repositories (one per collection group), services.
- lib/features/<feature>/{data,presentation}: auth, onboarding, care_circle,
  safe_zone, reminders, alerts, patient_home, caregiver_home, plus the empty
  extension folders above.
- Screens use Riverpod providers only; no Firestore calls inside widgets. New
  code uses Riverpod Notifier/AsyncNotifier; migrate old StateNotifierProvider
  code only when you touch it.
- Navigation: go_router with a redirect for auth and role (replace AuthGate).
- Docs: README.md (setup in 10 steps), docs/ARCHITECTURE.md (structure, "how to
  add a feature in 5 steps", feature flags), docs/DATA_MODEL.md,
  docs/CONTRIBUTING.md (feature/<name> branches from main, one feature per
  branch, small PRs, run flutter analyze before a PR, do not edit lib/core
  without a note in the PR), docs/TESTING.md, .github/pull_request_template.md.
  Keep each short.

## DATA MODEL (keep existing names; add migration scripts where needed)
- users/{uid}: role (patient|caregiver; immutable), name, email, patientId
  (patients only, 6 characters, keep the current generator), fcmTokens[],
  timezone, createdAt.
- patients/{pid} (NEW root doc): ownerUid, name, timezone,
  primaryCaregiverUid|null, createdAt. Create it together with users/{uid} in
  ONE Firestore transaction at patient registration; the same transaction
  checks that the patientId is unique (replacing the retry loop and fixing
  partial writes). Backfill existing patients with a one-time script. Store the
  device timezone (flutter_timezone).
- links/{linkId}: patientId, caregiverUid, caregiverName, role
  (primary|secondary; the UI calls secondary "Backup caregiver"), status
  (pending|active|rejected|removed), requestedBy, createdAt, respondedAt. Max 3
  secondaries (pending + active). Keep caregiverLinks/{uid}/patients/{pid} in
  sync in EVERY link function.
- patients/{pid}/safeZones/current (ONE doc): centerLat, centerLng,
  radiusMeters, enabled, updatedBy, updatedAt.
- patients/{pid}/status/live: lat, lng, accuracy, insideSafeZone (bool|null),
  updatedAt.
- patients/{pid}/alerts/{id}: type (outsideSafeZone|backInside|missedReminder|
  sos), message, lat, lng, audience (all|primary), severity, createdAt,
  notifiedUids[], acknowledgedBy, acknowledgedAt.
- patients/{pid}/reminders/{rid}: keep existing fields; add type, weekdays
  (List<int> 1-7), patientCanEdit (default true), maxRepeats (3),
  repeatEveryMinutes (5), snoozeMinutes (10), createdByRole. Migration script
  sets defaults on existing reminders.
- patients/{pid}/reminderOccurrences/{occId}: occId = "{rid}_{yyyyMMddHHmm}".
  reminderId, title, type, scheduledTime, status (pending|confirmed|snoozed|
  missed), nextNotifyAt, repeatCount, snoozeCount, shownTime, respondedAt,
  missedAlerted.
- patients/{pid}/reminderEvents/{id} (ML data for later): occurrenceId,
  reminderId, type, scheduledTime, shownTime, responseTime,
  responseDelaySeconds, action (confirmed|snoozed|missed), repeatCount,
  snoozeCount, hourOfDay, createdAt.

## DESIGN SYSTEM (calm, clean, not cluttered)
- Material 3, light theme. A calm teal primary, soft off-white background, white
  cards with 20 px radius and a very light shadow, spacing scale 8/12/16/24,
  rounded icons. Green = done/safe, amber = needs attention, red ONLY for
  emergencies. One clear primary action per screen.
- Two themes: PATIENT (body text at least 24 sp, headings 32 sp+, buttons at
  least 64 dp high, high contrast, at most 4 elements per screen, simple words)
  and CAREGIVER (16 sp body, compact cards, bottom NavigationBar).
- Shared widgets in lib/core/widgets: AppButton (primary/secondary/danger/
  large), AppCard, StatusChip, SectionHeader, EmptyState, LoadingView,
  ErrorView, BigTile. Every screen has loading, empty and error states with
  friendly wording. Firebase errors map to short friendly messages.

## SCREENS
AUTH AND ONBOARDING (rework the current flow)
- Welcome: app name + two large choices, "I am a patient" and "I am a
  caregiver", and a small "Log in" link. Sign up: name, email, password (min 8).
  Log in. Forgot password.
- Patient first run: (1) "Your Patient ID" shown very large with Copy and Share
  buttons and one line "Give this ID to your caregiver"; (2) a consent line:
  "Your caregivers can see your location and your reminders"; (3) a step screen
  asking for notification and location permissions one at a time with plain
  explanations; (4) "Continue" or "Use the app on my own".
- Caregiver first run: (1) "Connect to your patient": enter the patient ID; the
  first caregiver becomes PRIMARY and active; (2) primary only: "Add backup
  caregivers (recommended 2-3)": add by email (the person must already have a
  caregiver account) and/or Share an invite text (patient ID + "sign up as a
  caregiver and enter this ID"); a list shows each backup with its status;
  "Done" or "Skip for now". A caregiver who requests a link later sees "Waiting
  for approval".
- Session persists across restarts; role guards; logout.

PATIENT APP (no menus)
- Home (top to bottom): "Hi, <name>" with Good morning/afternoon/evening; big
  "Today is <Day>, <date>" and a live clock; a large reminders button with
  today's count of due reminders; a small profile icon (top right). Nothing
  else.
- My reminders: big cards sorted by time (icon, title, time, status tick); a "+"
  only if allowed; tapping a card edits it if patientCanEdit is true or the
  patient created it.
- Reminder popup (opens when a reminder notification is tapped or arrives in the
  foreground): icon, big title, time, two big buttons "Done" and "Later".
- Add/Edit reminder in 3 steps: pick a box (grid of 10: Hydration, Medication,
  Breakfast, Lunch, Dinner, Walk, Exercise, Sleep, Call family, Custom), set
  time(s) and repeat (once/daily/weekdays), review and save.
- Profile sheet: name, my patient ID, my caregivers (read only), log out.
  Tapping the version text 5 times opens Developer tools.
- Warning screen when outside the safe zone: "You are outside your safe area".

CAREGIVER APP (bottom navigation: Home, Reminders, Safe zone, Care circle)
- Home: a patient card (name, status chip Safe / Outside / Unknown with "last
  seen X min ago"); today's progress ("3 of 5 reminders done" with a progress
  bar and the next reminder); the last 3 alerts with Acknowledge and "See all";
  a banner "Add backup caregivers" while fewer than 2 are active.
- Reminders: list grouped Today / Upcoming; a floating "+" button; each item has
  a type icon, title, schedule, an Active switch and a "Patient can edit" switch
  (ON by default). Add/Edit: the grid of 10 boxes, then title (prefilled),
  time(s), repeat, "If no response, repeat [3] times every [5] minutes"
  steppers, the "Allow patient to edit" switch, Save.
- Safe zone: a map (about 60% of the screen) with a circle; a bottom sheet with
  radius chips (100 m, 200 m, 500 m, 1 km, 2 km), a custom value (50 m to 5 km,
  validated), a button "Use patient's current location", an Enabled switch and
  Save. A warning under 100 m about GPS accuracy.
- Care circle: the patient card (name, ID with Copy); the primary caregiver;
  backups with status; pending requests with Approve/Reject; Remove; "Add backup
  caregiver" (by email or Share invite). Backups see it read-only.
- Alerts list (from Home): newest first, type icon, message, time, location link,
  Acknowledge. Tapping a push notification opens it.

## CLOUD FUNCTIONS (TypeScript, in functions/)
- Upgrade the runtime from Node 18 to a supported version (20 or 22). Add a
  predeploy hook so `npm run build` runs before every deploy.
- Delete the client-callable `notifyUsers` function and every client call to it.
  Delete lib/functions_helpers/send_to_users.dart.
- sendToUsers helper (functions/src/helpers/sendToUsers.ts): sends FCM (high
  priority) and removes tokens FCM reports as invalid.
- Extend requestLink, respondToLink, removeSecondary (enforce max 3 secondaries
  in requestLink). New addBackupCaregiver(email): primary only; the account must
  exist as a caregiver; creates an ACTIVE secondary link; if the email is not
  found, return a clear error so the app can offer the Share invite. Clients
  never write links. Every link function also updates
  patients/{pid}.primaryCaregiverUid and caregiverLinks.
- onAlertCreated: finds ACTIVE caregivers of the patient (all when audience =
  all; only the primary when audience = primary), pushes (for example "<Name>
  left the safe zone") and records notifiedUids. With no caregivers it does
  nothing.
- generateOccurrences (reuse scheduleReminderOccurrences): every 15 minutes AND
  on reminder create/update/delete. Creates the next 48 hours of occurrences for
  active reminders with create-if-absent, using the patient's timezone. Fix the
  weekly bug with the weekdays array. When a reminder is edited or deactivated,
  delete its future pending occurrences and regenerate them. A one-time cleanup
  deletes existing future pending occurrences so they regenerate in the new
  format.
- dispatchReminders: scheduled every minute. A collection-group query for
  occurrences with status pending|snoozed and nextNotifyAt <= now. For each, in
  a transaction (so it never sends twice): send an FCM notification message to
  the patient (high priority, Android channel "memora_reminders_v2", data:
  occurrenceId + patientId); set shownTime on the first send; repeatCount += 1;
  if repeatCount < maxRepeats set nextNotifyAt = now + repeatEveryMinutes;
  otherwise set status missed, write a reminderEvent (action missed) and create
  an alert type=missedReminder with audience = primary.
- Rebuild firestore.indexes.json: remove the stale indexes (reminderLogs,
  locationLogs, dailyBehavior, weeklySummaries) and add exactly what the queries
  need, including the collection-group index (status + nextNotifyAt).

## ANDROID / CLIENT BEHAVIOR
- Reminder delivery is SERVER-DRIVEN. Remove the existing on-device scheduled
  reminder notifications, so there is exactly ONE delivery path (otherwise the
  patient gets duplicates). Keep flutter_local_notifications only to display
  foreground FCM messages. Create the NEW channel "memora_reminders_v2" (max
  importance, sound), because Android keeps the settings of an existing
  channel. Request POST_NOTIFICATIONS. Tapping a notification opens the reminder
  popup. Done: ONE batched write sets status confirmed + respondedAt and creates
  a reminderEvent (action confirmed, responseDelaySeconds). Later: status
  snoozed, snoozeCount + 1, nextNotifyAt = now + snoozeMinutes. A confirmed or
  missed occurrence never shows again, and re-login never recreates old
  reminders (all state lives on the server). Document the limitation: reminders
  need internet.
- Safe zone, patient side: when an enabled zone exists, start a foreground
  service location stream (geolocator foregroundNotificationConfig with the
  persistent notification "Memora is keeping you safe"). After a build, check
  the merged manifest for a service with foregroundServiceType "location"; add
  the declaration only if it is missing. Update status/live at most every 60 s
  or every 50 m. The phone computes the distance itself. Ignore fixes with
  accuracy worse than 50 m; alert only after 2 consecutive readings outside;
  10-minute cooldown between outside alerts; when back inside, create a
  "backInside" alert. Outside alerts use audience = all. Guide the user once to
  turn off battery optimization.
- Maps: google_maps_flutter. In android/app/build.gradle.kts read MAPS_API_KEY
  from android/local.properties into manifestPlaceholders and use
  ${MAPS_API_KEY} in the manifest (replace the empty string). When the key is
  empty the app uses flutter_map + OpenStreetMap (no key), chosen by one flag in
  app_config.dart, with identical behavior.
- Permissions: set minSdk 26. Remove SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM,
  RECEIVE_BOOT_COMPLETED and WAKE_LOCK unless something still uses them. Keep
  INTERNET, POST_NOTIFICATIONS, the location permissions, FOREGROUND_SERVICE,
  FOREGROUND_SERVICE_LOCATION and REQUEST_IGNORE_BATTERY_OPTIMIZATIONS.
- Release signing stays on debug keys for now (test APKs only). In the README
  note that each developer's machine has its own debug SHA-1, which must be added
  to the Maps key restriction (and Firebase if needed). A production keystore is
  future work.
- FCM tokens: arrayUnion on login/refresh, arrayRemove on logout.
- Developer tools screen (works in release builds; an app_config flag can
  disable it): the patient's distance from the zone center, GPS accuracy,
  inside/outside, last upload time; buttons "Create test reminder in 1 minute"
  and "Send test alert".

## FIRESTORE SECURITY RULES (keep the good rules; change only these)
- Users read/write only their own users doc; role immutable; patientId not
  client-writable.
- patients/{pid} root: created only by the owner (ownerUid == auth uid, doc must
  not exist); primaryCaregiverUid writable only by functions.
- A patient reads/writes own patient data; may create reminders for own
  patientId; may update/delete a reminder only if patientCanEdit is true or
  createdBy is the patient; can never change patientCanEdit, createdBy or
  createdByRole. A patient may update only status, respondedAt, snoozeCount and
  nextNotifyAt on occurrences; reminderEvents stay create-only. Only the patient
  writes status/live. The patient creates alerts for own patientId with
  validated type and audience values.
- The ACTIVE primary writes reminders and safeZones/current and reads
  everything. ACTIVE secondaries read everything and may update ONLY the
  acknowledgement fields of alerts. Pending, rejected and removed links get no
  access. links and caregiverLinks are written only by functions. Deny the rest.
- Write docs/rules_tests.md with at most 15 manual test cases.

## PHASES
PHASE 1: Foundation. Branch, folder structure, design system and theme,
go_router with role guards, feature flags, app_config, empty extension folders,
developer tools shell, docs skeletons, housekeeping (delete the obsolete
MASTER_PLAN.md; move the old PROGRESS.md to docs/archive/; delete notifyUsers
and send_to_users.dart; rebuild firestore.indexes.json; Node upgrade and
predeploy build; Android manifest and Maps key wiring; minSdk 26; fix
`flutter analyze`).
PHASE 2: Accounts, onboarding and care circle: the registration transaction and
patients root doc, backfill script, sendToUsers, link functions
(requestLink/addBackupCaregiver/respondToLink/removeSecondary), rules, and all
auth/onboarding/care-circle screens.
 Acceptance: a patient registers and sees an ID; caregiver 1 links and becomes
 primary; the primary adds one backup by email and another by invite (pending ->
 approve); a 4th backup is refused; a pending caregiver sees no data.
PHASE 3: Alerts pipeline and safe zone: onAlertCreated, alerts UI, safe-zone
screens, patient location stream, status/live, developer tools.
 Acceptance: with a 200 m zone, walking about 300 m away gives ONE alert to the
 primary and every active backup, then a back-inside alert; the patient phone
 shows the warning; the caregiver can acknowledge.
PHASE 4: Reminders: screens for both roles, generateOccurrences,
dispatchReminders, indexes, reminderEvents, rules, migrations.
 Acceptance: a caregiver creates a reminder for 2 minutes ahead and the patient
 phone rings; with no response it repeats 3 times then becomes missed and the
 primary gets an alert; Done never comes back after logout/login; Later returns
 after 10 minutes; with "Patient can edit" off the patient cannot edit it.
PHASE 5: Polish, docs, Firebase deploy, APK. Fix UI inconsistencies; write
docs/TESTING.md (a two-phone checklist, max 40 lines); make README.md a 10-step
setup for a new teammate; tag the commit `v0.1-base`. STRETCH ONLY if all else
is done: reminder photos.

## END-OF-PHASE CHECKS
a. `flutter analyze` clean; `cd functions && npm run build` clean.
b. Deploy if the Firebase CLI is logged in: `firebase deploy --only
   firestore:rules,firestore:indexes,functions` (and storage rules if used).
   Paste the result. If you cannot deploy, give me the exact commands.
c. `flutter build apk --release`; report the exact path
   (build/app/outputs/flutter-apk/app-release.apk).
d. Confirm the MAIN android/app/src/main/AndroidManifest.xml has INTERNET,
   POST_NOTIFICATIONS, location and foreground-service permissions and the Maps
   key placeholder, and that minSdk is 26.
e. Update PROGRESS.md and commit. Give me: the manual steps (firebase login,
   firebase use memora-3b359, Blaze plan, Maps key, SHA-1) and a 3-line phone
   test checklist. Then STOP.
