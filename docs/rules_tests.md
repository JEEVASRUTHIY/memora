# Firestore Rules Tests

Run these manually in the Firebase Emulator or a test project after deploying the free-mode rules.

1. A signed-out user cannot read users, patients, links, or emailIndex.
2. A signed-in user can get one exact emailIndex document but cannot list emailIndex.
3. A user cannot create an emailIndex document for another UID.
4. A patient registration creates users, patients, and emailIndex in one transaction.
5. A patient can read their own patient root and linked caregiver list.
6. A caregiver can get a patient by ID but cannot list the patients collection.
7. The first caregiver can create one active primary link for the patient.
8. A second caregiver can create only their own pending secondary link.
9. A caregiver cannot create a link using another caregiver's UID or link ID.
10. A pending caregiver cannot read reminders or other patient subcollections.
11. The active primary can approve or reject a pending link and the secondary count changes.
12. The active primary can remove a backup; a secondary cannot approve, remove, or edit links.# Firestore Security Rules — Manual Test Cases

Run these tests using the Firebase Emulator Suite:
```bash
firebase emulators:start --only firestore
```
Or verify manually against a deployed project using the Firebase Rules Playground in the Console.

---

## Test Setup

| Actor | UID | Role | patientId |
|---|---|---|---|
| Alice | `uid-alice` | `patient` | `ALICE001` |
| Bob | `uid-bob` | `caregiver` | — |
| Carol | `uid-carol` | `patient` | `CAROL002` |
| Eve | `uid-eve` | `caregiver` | — |

Assume Bob is linked to Alice (link document + caregiverLinks index written).  
Eve is NOT linked to anyone.

---

## Test Cases

### TC-01: Patient reads own profile ✅ ALLOW
- **Actor:** Alice (`uid-alice`)
- **Operation:** `GET /users/uid-alice`
- **Expected:** ALLOWED
- **Rule:** `isOwner(uid)`

---

### TC-02: Patient reads another user's profile ❌ DENY
- **Actor:** Alice (`uid-alice`)
- **Operation:** `GET /users/uid-bob`
- **Expected:** DENIED
- **Rule:** `isOwner(uid)` fails because `uid-alice ≠ uid-bob`

---

### TC-03: Patient tries to change their role ❌ DENY
- **Actor:** Alice (`uid-alice`)
- **Operation:** `UPDATE /users/uid-alice` with `{ role: "caregiver" }`
- **Expected:** DENIED
- **Rule:** Update rule checks `request.resource.data.role == resource.data.role`

---

### TC-04: Caregiver creates a link to valid patient ✅ ALLOW
- **Actor:** Bob (`uid-bob`)
- **Operation:** `CREATE /links/{auto-id}` with `{ caregiverUid: "uid-bob", patientUid: "uid-alice", patientId: "ALICE001", status: "active", createdAt: now }`
- **Expected:** ALLOWED
- **Rule:** `caregiverUid == request.auth.uid`, `callerDoc().role == 'caregiver'`, status is `"active"`

---

### TC-05: Unauthenticated user creates a link ❌ DENY
- **Actor:** Anonymous (no auth)
- **Operation:** `CREATE /links/{auto-id}`
- **Expected:** DENIED
- **Rule:** `isAuthed()` fails

---

### TC-06: Linked caregiver creates a reminder ✅ ALLOW
- **Actor:** Bob (`uid-bob`, linked to `ALICE001`)
- **Operation:** `CREATE /patients/ALICE001/reminders/{id}` with valid fields
- **Expected:** ALLOWED
- **Rule:** `existsLink(uid-bob, ALICE001)` returns true, `callerDoc().role == 'caregiver'`

---

### TC-07: Unlinked caregiver creates a reminder ❌ DENY
- **Actor:** Eve (`uid-eve`, NOT linked to any patient)
- **Operation:** `CREATE /patients/ALICE001/reminders/{id}`
- **Expected:** DENIED
- **Rule:** `existsLink(uid-eve, ALICE001)` returns false

---

### TC-08: Patient updates a reminderOccurrence status field ✅ ALLOW
- **Actor:** Alice (`uid-alice`)
- **Operation:** `UPDATE /patients/ALICE001/reminderOccurrences/{id}` changing only `{ status: "confirmed" }`
- **Expected:** ALLOWED
- **Rule:** `isPatientSelf(ALICE001)` + `affectedKeys().hasOnly([...permitted fields])`

---

### TC-09: Patient tries to update reminderOccurrence reminderId ❌ DENY
- **Actor:** Alice (`uid-alice`)
- **Operation:** `UPDATE /patients/ALICE001/reminderOccurrences/{id}` changing `{ reminderId: "other-id" }`
- **Expected:** DENIED
- **Rule:** `affectedKeys().hasOnly([...])` fails — `reminderId` is not in allowed fields

---

### TC-10: Client tries to write to weeks collection ❌ DENY
- **Actor:** Alice (`uid-alice`)
- **Operation:** `CREATE /patients/ALICE001/weeks/{weekId}`
- **Expected:** DENIED
- **Rule:** `allow write: if false` — only Admin SDK can write

---

### TC-11: Linked caregiver reads patient's weeks data ✅ ALLOW
- **Actor:** Bob (`uid-bob`, linked to `ALICE001`)
- **Operation:** `GET /patients/ALICE001/weeks/{weekId}`
- **Expected:** ALLOWED
- **Rule:** `existsLink(uid-bob, ALICE001)` returns true

---

### TC-12: Patient creates an SOS alert ✅ ALLOW
- **Actor:** Alice (`uid-alice`)
- **Operation:** `CREATE /patients/ALICE001/alerts/{id}` with `{ type: "sos", acknowledged: false, createdAt: now, message: "Help!" }`
- **Expected:** ALLOWED
- **Rule:** `isPatientSelf(ALICE001)`, `type in [...]`, `acknowledged == false`

---

### TC-13: Patient creates alert with acknowledged=true ❌ DENY
- **Actor:** Alice (`uid-alice`)
- **Operation:** `CREATE /patients/ALICE001/alerts/{id}` with `{ acknowledged: true, ... }`
- **Expected:** DENIED
- **Rule:** `request.resource.data.acknowledged == false` check fails

---

### TC-14: Caregiver acknowledges an alert ✅ ALLOW
- **Actor:** Bob (`uid-bob`, linked to `ALICE001`)
- **Operation:** `UPDATE /patients/ALICE001/alerts/{id}` changing only `{ acknowledged: true, acknowledgedBy: "uid-bob", acknowledgedAt: now }`
- **Expected:** ALLOWED
- **Rule:** `existsLink(uid-bob, ALICE001)`, `affectedKeys().hasOnly([...ack fields...])`

---

### TC-15: Patient deletes a reminder ❌ DENY
- **Actor:** Alice (`uid-alice`)
- **Operation:** `DELETE /patients/ALICE001/reminders/{id}`
- **Expected:** DENIED
- **Rule:** Only caregivers can delete reminders

---

## Running with Firebase Emulator

```bash
# Install emulator (if not yet installed)
npx -y firebase-tools@latest emulators:start --only firestore

# Or use the Firebase Emulator UI at http://localhost:4000
```

For automated testing, use the `@firebase/rules-unit-testing` npm package:

```bash
npm install --save-dev @firebase/rules-unit-testing firebase-admin
```

Reference: https://firebase.google.com/docs/firestore/security/test-rules-emulator
