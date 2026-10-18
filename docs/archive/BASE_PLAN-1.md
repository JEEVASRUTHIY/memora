PLAN VERSION: BASE-1
# MEMORA BASE BUILD PLAN

GOAL
Deliver a clean, working BASE that teammates can extend with feature branches.
It contains: accounts + onboarding, caregiver linking with backup caregivers,
an alert pipeline, a safe zone, reminders, and a polished UI for both roles.
Real Android phones only (min SDK 26). Firebase backend (Auth, Firestore,
Cloud Functions Node.js/TypeScript, FCM). Flutter + Riverpod + go_router.

OUT OF SCOPE (leave empty extension points only): SOS button logic, medicine
management, voice assistant, ML weekly report, reminder photos and voice notes.
Create lib/features/{sos,medicine,voice_assistant,weekly_report}/ each with only
a README.md that states which Firestore collections/functions the feature will
use and how to plug into the UI through lib/core/feature_flags.dart. Those
flags default to false, and the screens must render nothing for a disabled
feature.

## RULES
1. Start of every session: read docs/BASE_PLAN.md and PROGRESS.md, check
   `git log --oneline -10`, continue from the first unfinished step. Check the
   real code, not only the file.
2. Before a step write "IN PROGRESS: <step>" in PROGRESS.md and commit; after it
   write "DONE: <step>" and commit. Commit after every sub-part.
3. Reuse existing code that is good (see docs/STATUS.md). Rewrite what the plan
   changes. Delete dead code (git history keeps it). Keep code compact.
4. Run `flutter analyze` after each step. Build the release APK once at the end
   of each phase.
5. Never print, hardcode or commit API keys or service-account files. The Maps
   key lives only in android/local.properties (MAPS_API_KEY). Keep
   local.properties, .env and key files in .gitignore.
6. Never claim anything works on a device. Do not push to any remote.
7. Docs are short. PROGRESS.md format: header (last updated, current phase,
   NEXT ACTION), a table (step | TODO / IN PROGRESS / DONE | files | notes),
   and sections "Manual steps pending for the user" and "Known issues".

## ARCHITECTURE (so teammates can work in parallel)
- lib/core/: theme, design-system widgets, router, constants, error handling,
  feature_flags.dart, app_config.dart.
- lib/data/: models, repositories (one per collection group), services.
- lib/features/<feature>/{data,presentation}: auth, onboarding, care_circle,
  safe_zone, reminders, alerts, patient_home, caregiver_home, plus the empty
  extension folders above.
- Screens use Riverpod providers only; no Firestore calls inside widgets.
- Docs: README.md (setup in 10 steps), docs/ARCHITECTURE.md (structure, "how to
  add a feature in 5 steps", feature flags), docs/DATA_MODEL.md, docs/CONTRIBUTING.md
  (feature/<name> branches from main, one feature per branch, small PRs, run
  flutter analyze before a PR, do not edit lib/core without a note in the PR),
  docs/TESTING.md, .github/pull_request_template.md. Keep each short.

## DATA MODEL (reuse existing collection names where they already match;
## otherwise add a migration script and note it in docs/DATA_MODEL.md)
- users/{uid}: role (patient|caregiver; immutable), name, email, patientId
  (patients only; written by a function), fcmTokens[], timezone, createdAt.
- patients/{pid}: ownerUid, name, timezone, primaryCaregiverUid|null,
  createdAt. pid = 8 characters from "ABCDEFGHJKMNPQRSTUVWXYZ23456789".
- links/{linkId}: patientId, caregiverUid, caregiverName, role
  (primary|backup), status (pending|active|rejected|removed), requestedBy
  (caregiver|primary), createdAt, respondedAt. Max 3 backups (pending + active).
- patients/{pid}/safeZone/current: centerLat, centerLng, radiusMeters, enabled,
  updatedBy, updatedAt.
- patients/{pid}/status/live: lat, lng, accuracy, insideSafeZone (bool|null),
  updatedAt.
- patients/{pid}/alerts/{id}: type (outsideSafeZone|backInside|missedReminder|
  sos), message, lat, lng, audience (all|primary), severity, createdAt,
  notifiedUids[], acknowledgedBy, acknowledgedAt.
- patients/{pid}/reminders/{rid}: type, title, note, recurrence {kind: once|
  daily|weekly, times ["08:00"], weekdays [1-7], date}, maxRepeats (default 3),
  repeatEveryMinutes (default 5), snoozeMinutes (default 10), active,
  patientCanEdit (default true), createdBy, createdByRole, createdAt, updatedAt.
- patients/{pid}/reminderOccurrences/{occId}: occId = "{rid}_{yyyyMMddHHmm}".
  reminderId, title, type, scheduledTime, status (pending|confirmed|snoozed|
  missed), nextNotifyAt, repeatCount, snoozeCount, shownTime, respondedAt,
  missedAlerted.
- patients/{pid}/reminderEvents/{id} (ML data for later): occurrenceId,
  reminderId, type, scheduledTime, shownTime, responseTime,
  responseDelaySeconds, action (confirmed|snoozed|missed), repeatCount,
  snoozeCount, hourOfDay, createdAt.

## DESIGN SYSTEM (calm, clean, not cluttered)
- Material 3, light theme. A calm teal primary, soft off-white background,
  white cards with 20 px radius and very light shadow, spacing scale 8/12/16/
  24, rounded icons. Green = done/safe, amber = needs attention, red ONLY for
  emergencies. One clear primary action per screen.
- Two themes: PATIENT (body text at least 24 sp, headings 32 sp+, buttons at
  least 64 dp high, high contrast, at most 4 elements per screen, simple words)
  and CAREGIVER (16 sp body, compact cards, bottom NavigationBar).
- Shared widgets in lib/core/widgets: AppButton (primary/secondary/danger/
  large), AppCard, StatusChip, SectionHeader, EmptyState, LoadingView,
  ErrorView, BigTile. Every screen has loading, empty and error states with
  friendly wording. Firebase errors are mapped to short friendly messages.

## SCREENS
AUTH AND ONBOARDING (replace the current registration flow)
- Welcome: app name + two large choices, "I am a patient" and "I am a
  caregiver", and a small "Log in" link.
- Sign up: name, email, password (min 8). Log in. Forgot password.
- Patient first run: (1) "Your Patient ID" shown very large with Copy and Share
  buttons and one line: "Give this ID to your caregiver"; (2) a short consent
  line: "Your caregivers can see your location and your reminders"; (3) a step
  screen asking for notification and location permissions, one at a time, with
  plain explanations; (4) "Continue" or "Use the app on my own".
- Caregiver first run: (1) "Connect to your patient": enter the patient ID; the
  first caregiver becomes PRIMARY and active; (2) primary only: "Add backup
  caregivers (recommended 2-3)": add by email (the person must already have a
  caregiver account) and/or Share an invite text (patient ID + "sign up as a
  caregiver and enter this ID"); a list shows each backup with status; "Done" or
  "Skip for now". A caregiver who requests a link as a later caregiver sees a
  "Waiting for approval" screen.
- Session persists across restarts; role-based routing guards; logout.

PATIENT APP (no menus)
- Home (top to bottom): "Hi, <name>" with Good morning/afternoon/evening; big
  "Today is <Day>, <date>" and a live clock; a large reminders button with
  today's count of due reminders; a small profile icon (top right). Nothing else.
- My reminders: big cards sorted by time (icon, title, time, status tick); a "+"
  only if allowed; tap a card to edit if patientCanEdit is true or the patient
  created it.
- Reminder popup (opens when a reminder notification is tapped or arrives in the
  foreground): icon, big title, time, two big buttons "Done" and "Later".
- Add/Edit reminder in 3 simple steps: pick a box (grid of 10: Hydration,
  Medication, Breakfast, Lunch, Dinner, Walk, Exercise, Sleep, Call family,
  Custom), set the time(s) and repeat (once/daily/weekdays), review and save.
- Profile sheet: name, my patient ID, my caregivers (read only), log out.
  Tapping the version text 5 times opens Developer tools (see below).
- Safe-zone warning screen on the patient phone when outside the zone (big
  text, spoken is NOT required yet): "You are outside your safe area".

CAREGIVER APP (bottom navigation: Home, Reminders, Safe zone, Care circle)
- Home: a patient card (name, status chip Safe / Outside / Unknown with "last
  seen X min ago"); today's progress ("3 of 5 reminders done" with a progress
  bar and the next reminder); the last 3 alerts with an Acknowledge button and
  "See all"; a banner "Add backup caregivers" while fewer than 2 are active.
- Reminders: list grouped by Today / Upcoming; a floating "+" button; each item
  shows type icon, title, schedule, an Active switch, and a "Patient can edit"
  switch (ON by default). Add/Edit: the grid of 10 boxes, then title
  (prefilled), time(s), repeat, "If no response, repeat [3] times every [5]
  minutes" steppers, the "Allow patient to edit" switch, Save.
- Safe zone: a map (about 60% of the screen) with a circle; a bottom sheet with
  radius chips (100 m, 200 m, 500 m, 1 km, 2 km) and a custom value (50 m to
  5 km, validated), a button "Use patient's current location", an Enabled
  switch, and Save. A warning appears under 100 m about GPS accuracy.
- Care circle: the patient card (name, ID with Copy); the primary caregiver;
  backups with status; pending requests with Approve/Reject; Remove; "Add
  backup caregiver" (by email or Share invite). Backups see it read-only.
- Alerts list (from Home): newest first, type icon, message, time, location
  link, Acknowledge. Tapping a push notification opens it.

## CLOUD FUNCTIONS (TypeScript, in functions/)
- registerPatientProfile(name, timezone): callable; creates a unique pid, the
  patients/{pid} doc and sets users/{uid}.patientId. Clients can never write
  patientId.
- requestLink(patientId): first caregiver -> primary + active; later ones ->
  backup + PENDING. Reject duplicates and more than 3 backups.
- addBackupCaregiver(email): primary only; the account must exist as a
  caregiver; creates an ACTIVE backup link. Respond with a clear error if the
  email is not found, so the app can offer the Share invite.
- respondToLink(linkId, approve) and removeCaregiver(linkId): primary only.
  Clients never write the links collection.
- sendToUsers(uids, payload): shared helper; sends FCM (high priority) and
  removes tokens FCM reports as invalid.
- onAlertCreated: finds the ACTIVE caregivers of that patient (all of them when
  audience = all; only the primary when audience = primary), sends the push
  (for example "<Name> left the safe zone"), and records notifiedUids. If there
  are no caregivers it does nothing.
- generateOccurrences: scheduled every 15 minutes and also on reminder
  create/update/delete. Creates the next 48 hours of occurrences for active
  reminders with create-if-absent, using the patient's timezone (store the
  device timezone at registration). When a reminder is edited or deactivated,
  delete its future pending occurrences and regenerate them.
- dispatchReminders: scheduled every minute. Uses a collection-group query for
  occurrences with status pending|snoozed and nextNotifyAt <= now. For each, in
  a transaction (so it never sends twice): send an FCM notification message to
  the patient (high priority, Android channel "reminders", data:
  occurrenceId + patientId); set shownTime on the first send; repeatCount += 1;
  if repeatCount < maxRepeats set nextNotifyAt = now + repeatEveryMinutes;
  otherwise set status missed, write a reminderEvent (action missed) and create
  an alert type=missedReminder with audience = primary.
- Create every Firestore index that these queries need in
  firestore.indexes.json (including the collection-group index).

## ANDROID/CLIENT BEHAVIOR
- Reminders: the patient phone creates the notification channel "reminders"
  (max importance, sound), requests POST_NOTIFICATIONS, shows foreground FCM
  messages through flutter_local_notifications, opens the reminder popup when a
  notification is tapped, and lists occurrences from Firestore. Done: a
  transaction sets status confirmed + respondedAt and writes a reminderEvent
  (action confirmed, responseDelaySeconds). Later: status snoozed, snoozeCount
  + 1, nextNotifyAt = now + snoozeMinutes. A confirmed or missed occurrence
  never shows again, and re-login never recreates old reminders (all state
  lives on the server). Known limitation, to document: reminders need internet.
- Safe zone, patient side: when an enabled zone exists, start a
  foreground-service location stream (geolocator with a persistent notification
  "Memora is keeping you safe"). Permissions: ACCESS_FINE_LOCATION,
  ACCESS_COARSE_LOCATION, ACCESS_BACKGROUND_LOCATION (in two steps with an
  explanation), FOREGROUND_SERVICE, FOREGROUND_SERVICE_LOCATION. Update
  status/live at most every 60 s or every 50 m of movement. The phone computes
  the distance itself. Ignore fixes with accuracy worse than 50 m; alert only
  after 2 consecutive readings outside; 10-minute cooldown between outside
  alerts; when the patient comes back inside, create a "backInside" alert. An
  outside alert is created with audience = all. Guide the user once to turn off
  battery optimization for the app.
- Maps: google_maps_flutter with the key read from android/local.properties via
  manifestPlaceholders (never hardcoded). Fallback: flutter_map + OpenStreetMap
  (no key), chosen by one flag in app_config.dart, with identical behavior.
- FCM tokens: arrayUnion on login/refresh, arrayRemove on logout.
- Developer tools screen (reachable in release builds): the patient's distance
  from the zone center, GPS accuracy, inside/outside, last upload time; buttons
  "Create test reminder in 1 minute" and "Send test alert". A flag in
  app_config.dart can disable it.

## FIRESTORE SECURITY RULES (and tests)
- Users read/write only their own users doc; role is immutable; patientId is
  not client-writable.
- A patient reads/writes own patient data; creates alerts for own patientId
  (validate the type and fields); may edit a reminder only when patientCanEdit
  is true or createdBy is the patient, and can never change patientCanEdit or
  createdBy; writes own status/live, own occurrence status fields and
  reminderEvents.
- The ACTIVE primary caregiver has full read/write on that patient's reminders
  and safe zone and can read everything else. ACTIVE backups read everything
  and may update ONLY the acknowledgement fields of alerts. Pending, rejected
  and removed links get no access.
- The links collection and patient root fields (primaryCaregiverUid) are
  writable only by functions. Deny everything else.
- Write docs/rules_tests.md with at most 15 manual test cases.

## PHASES
PHASE 1: Foundation. Branch, folder structure, design system, theme, router
with role guards, feature flags, app_config, empty extension folders, developer
tools shell, docs skeletons, deletion of dead code.
PHASE 2: Accounts, onboarding and care circle: functions registerPatientProfile,
requestLink, addBackupCaregiver, respondToLink, removeCaregiver, sendToUsers;
rules; all auth/onboarding/care-circle screens; a migration script if existing
data must be converted.
 Acceptance: a patient registers and sees an ID; caregiver 1 links and becomes
 primary; the primary adds a backup by email and another by invite (pending ->
 approve); a 4th backup is refused; a pending caregiver sees no data.
PHASE 3: Alerts pipeline and safe zone: onAlertCreated, alerts UI, safe-zone
screens, patient location stream, status/live, developer tools.
 Acceptance: with a 200 m zone, walking about 300 m away gives ONE alert to the
 primary and every active backup, then a back-inside alert; the patient phone
 shows the warning; the caregiver can acknowledge.
PHASE 4: Reminders: reminder screens for both roles, generateOccurrences,
dispatchReminders, indexes, reminderEvents, rules.
 Acceptance: a caregiver creates a reminder for 2 minutes ahead and the
 patient phone rings; with no response it repeats 3 times then becomes missed
 and the primary gets an alert; Done never comes back after logout/login; Later
 returns after 10 minutes; with "Patient can edit" off, the patient cannot edit.
PHASE 5: Polish, docs, Firebase deploy, APK. Fix UI inconsistencies, write the
docs, deploy, build. STRETCH ONLY if all else is done: reminder photos.

## END-OF-PHASE CHECKS
a. `flutter analyze` clean; `cd functions && npm run build` clean.
b. Deploy to Firebase if the CLI is logged in: `firebase deploy --only
   firestore:rules,firestore:indexes,functions` (and storage rules if used).
   Paste the result. If you cannot deploy, list the exact commands for me.
c. `flutter build apk --release`; report the exact path
   (build/app/outputs/flutter-apk/app-release.apk).
d. Confirm the MAIN android/app/src/main/AndroidManifest.xml has INTERNET,
   POST_NOTIFICATIONS, location, foreground-service permissions and the Maps key
   placeholder, and that minSdk is 26.
e. Update PROGRESS.md and commit. Give me: manual steps (firebase login,
   firebase use <project>, enable Blaze, Maps key, SHA-1), and a 3-line phone
   test checklist. Then STOP.
After Phase 5 also: write docs/TESTING.md (a two-phone checklist, max 40 lines),
make sure README.md explains the 10-step setup for a new teammate, and tag the
commit `v0.1-base`.
=== ADDENDUM (from the audit of the current code; this wins over any
=== conflicting text above) ===

A. HOUSEKEEPING (do first)
1. Run `flutter analyze` (the audit's result was pending) and fix errors.
2. MASTER_PLAN.md (untracked, an old plan) is obsolete: delete it. Move the old
   PROGRESS.md content into docs/archive/ and create a fresh PROGRESS.md for
   BASE-1.
3. Delete lib/functions_helpers/send_to_users.dart. The push helper lives in
   functions/src/helpers/sendToUsers.ts. Delete the client-callable
   `notifyUsers` Cloud Function and every client call to it: clients must never
   be able to send pushes to arbitrary users. Alerts use onAlertCreated and
   reminders use dispatchReminders instead.
4. firestore.indexes.json: remove the stale indexes (reminderLogs, locationLogs,
   dailyBehavior, weeklySummaries). Keep only the indexes the current queries
   need, including the collection-group index for reminderOccurrences
   (status + nextNotifyAt).

B. KEEP EXISTING NAMES (do not rename)
- Keep register, login and role selection as they are, and keep the 6-character
  patientId (not 8).
- Keep link role values primary|secondary in code and rules. The UI calls a
  secondary caregiver a "Backup caregiver".
- Keep caregiverLinks/{uid}/patients/{pid} and keep it in sync in every link
  function (requestLink, addBackupCaregiver, respondToLink, removeSecondary).
- Keep the safeZones collection and use ONE doc with the id "current".
- Keep alerts, reminders, reminderOccurrences and reminderEvents.
- NEW: the patients/{pid} root doc (ownerUid, name, timezone,
  primaryCaregiverUid|null, createdAt). Create it together with users/{uid} in
  ONE Firestore transaction at patient registration. The same transaction
  checks that the patientId is unique, replacing the retry loop and fixing the
  partial-write problem. Backfill the root doc for existing patients with a
  one-time script. Store the device timezone (flutter_timezone package).

C. NAVIGATION AND STATE
- Adopt go_router with a redirect for auth and role (replace AuthGate). Migrate
  existing screens as you touch them.
- New code uses Riverpod Notifier/AsyncNotifier. Migrate existing
  StateNotifierProvider code only when you touch it.

D. FUNCTIONS
- Upgrade the functions runtime from Node 18 to a currently supported Node
  version (20 or 22). If deploy complains, follow its message.
- Make deploy run `npm run build` first (predeploy hook), because functions/lib
  is not committed.
- Extend, do not rewrite: requestLink, respondToLink, removeSecondary. Add
  addBackupCaregiver. Enforce at most 3 secondaries (pending + active) in
  requestLink.
- Reuse scheduleReminderOccurrences as generateOccurrences. Fix the weekly bug
  (it fires only on Mondays) by using a weekdays array. Add nextNotifyAt,
  repeatCount and missedAlerted to occurrences. Run a one-time cleanup that
  deletes existing FUTURE pending occurrences so they regenerate in the new
  format.

E. REMINDERS MIGRATION
- Keep the existing ReminderModel field names. Add weekdays (List<int> 1-7),
  patientCanEdit (default true), maxRepeats (3), repeatEveryMinutes (5),
  snoozeMinutes (10), createdByRole. A migration script sets these defaults on
  existing reminders.
- Delivery is SERVER-DRIVEN (dispatchReminders). Remove the existing on-device
  scheduled-notification code for reminders, so there is exactly ONE delivery
  path (otherwise the patient gets double notifications). Keep
  flutter_local_notifications only to display foreground FCM messages.
- Use a NEW notification channel id "memora_reminders_v2" (max importance and
  sound), because Android keeps the settings of an already-created channel.
  dispatchReminders must send to that channel id.
- Done and Later are written from the client as ONE batched write (occurrence
  fields + reminderEvent), so they also work with a weak connection.

F. ANDROID
- minSdk 26.
- Remove permissions the base does not use: SCHEDULE_EXACT_ALARM,
  USE_EXACT_ALARM, RECEIVE_BOOT_COMPLETED (and WAKE_LOCK if nothing uses it).
  Keep INTERNET, POST_NOTIFICATIONS, the location permissions,
  FOREGROUND_SERVICE, FOREGROUND_SERVICE_LOCATION and
  REQUEST_IGNORE_BATTERY_OPTIMIZATIONS.
- Maps key: in android/app/build.gradle.kts read MAPS_API_KEY from
  android/local.properties into manifestPlaceholders, and use ${MAPS_API_KEY}
  in the manifest (replace the empty string). When the key is empty, the app
  uses the OpenStreetMap fallback.
- Location foreground service: use geolocator's foregroundNotificationConfig.
  After a build, check the merged manifest: a service with
  foregroundServiceType "location" must be present. Add the declaration only if
  it is missing.
- Release signing: keep debug signing for now (test APKs only). In the README
  note that each developer's machine has its own debug SHA-1, which must be
  added to the Maps key restriction (and Firebase if needed). A production
  keystore is future work.

G. RULES UPDATES
- reminders: the ACTIVE primary writes everything. The patient may create
  reminders for own patientId, and update/delete one only if patientCanEdit is
  true or createdBy is the patient. The patient can never change
  patientCanEdit, createdBy or createdByRole.
- reminderOccurrences: the patient may update only status, respondedAt,
  snoozeCount and nextNotifyAt. reminderEvents stay create-only.
- patients/{pid} root: created only by the owner (ownerUid == auth uid, doc must
  not exist yet). primaryCaregiverUid is writable only by functions.
- patients/{pid}/status/live: written by the patient only, read by active
  caregivers.
- alerts: validate the type and audience values on create.
- safeZones: the ACTIVE primary writes, the patient reads.
- Update docs/DATA_MODEL.md and docs/rules_tests.md for all of the above.
