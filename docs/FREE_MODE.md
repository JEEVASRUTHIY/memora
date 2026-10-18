# Memora Free Mode

This mode keeps Memora compatible with Firebase Spark. Cloud Functions, Cloud Scheduler, and Storage are not used by the app. The existing `functions/` folder remains untouched and unused. The BASE-2 data model remains unchanged so a later move to Cloud Functions needs no data migration.

## Phase 2 linking

The app performs `requestLink`, `addBackupCaregiver`, `respondToLink`, and `removeSecondary` with Firestore transactions or batches in `LinkRepository`. It reads `patients/{patientId}` for `primaryCaregiverUid` and `secondaryCount`, enforces at most three secondary caregivers, and updates these documents together:

- `links/{linkId}`
- `caregiverLinks/{caregiverUid}/patients/{patientId}`
- the patient root fields needed for primary and secondary counts

Registration writes `emailIndex/{emailLower}` with the account UID and role. The index is readable only for an exact lookup and is written as part of account creation.

The MVP supports one current patient per caregiver. Existing Cloud Functions remain unused; no deploy of functions, Scheduler, or Storage is part of this mode.

## Later free-mode worker

Later phases may add a local worker under `tools/worker` using Node 22 and `firebase-admin`. The worker will send FCM pushes for new alerts, create the next 48 hours of reminder occurrences every 15 minutes, and mark overdue occurrences as missed. Reminder occurrences will be scheduled on the patient phone with `flutter_local_notifications` zoned scheduling and exact alarms.

## Security limitations

Rules enforce authentication, ownership, immutable roles, exact email-index reads, caregiver ownership of links, primary-only approval/removal, the first-primary condition, and the secondary limit where the rules can observe the complete transaction with `getAfter`.

Rules cannot provide the same trusted server boundary as Admin SDK functions. A malicious client may still race legitimate clients around counters or exploit any field-validation gap that rules do not explicitly cover. FCM delivery, alert fan-out, occurrence generation, missed-reminder processing, and notification cleanup are not guaranteed until the local worker or Cloud Functions is running. Clients must therefore treat link and notification data as eventually consistent and must not assume a push was delivered.

## Deployment checks

Only these Firebase checks belong to free mode:

```text
firebase deploy --only firestore:rules,firestore:indexes
```

Do not deploy functions or Storage. Do not add API keys, service-account files, or other secrets to Git.
