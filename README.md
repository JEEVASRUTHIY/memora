# MEMORA

MEMORA is a Flutter and Firebase mobile app for dementia care.
It helps a patient stay connected with caregivers.
It also helps caregivers view reminders and manage care links.
The app has two roles: Patient and Caregiver.

## Working Together

### Start Here

1. Read [README.md](README.md).
2. Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
3. Read [docs/DATA_MODEL.md](docs/DATA_MODEL.md).
4. Read [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md).

The code is organised by feature folders under `lib/features/`.

### Project Notes

- [AGENTS.md](AGENTS.md): Session rules for the coding assistant.
- [AGENT_RULES.md](AGENT_RULES.md): Project rules for working safely.
- [PROGRESS.md](PROGRESS.md): Current phase and completed work.
- [MEMORA_PROJECT_AUDIT.md](MEMORA_PROJECT_AUDIT.md): Project audit notes.
- [docs/BASE_PLAN.md](docs/BASE_PLAN.md): The main build plan.
- [docs/FREE_MODE.md](docs/FREE_MODE.md): Firebase free-plan limits.
- [docs/STATUS.md](docs/STATUS.md): Current project status.
- [docs/TESTING.md](docs/TESTING.md): Testing guidance.
- [docs/rules_tests.md](docs/rules_tests.md): Firestore rules test notes.
- [.github/pull_request_template.md](.github/pull_request_template.md): Pull request checklist.
- [lib/features/sos/README.md](lib/features/sos/README.md): Planned SOS feature.
- [lib/features/medicine/README.md](lib/features/medicine/README.md): Planned medicine feature.
- [lib/features/voice_assistant/README.md](lib/features/voice_assistant/README.md): Planned voice feature.
- [lib/features/weekly_report/README.md](lib/features/weekly_report/README.md): Planned weekly report feature.

### Simple Team Routine

1. Create a branch for your change.
2. Make small commits with clear messages.
3. Push the branch.
4. Open a pull request for review.

`google-services.json` and `functions/.env` are not on GitHub. Ask the project owner for them.

## How It Works

### Patient
1. Create a patient account with email and password.
2. MEMORA creates a six-character Patient ID.
3. Complete the patient profile.
4. Share the Patient ID with a caregiver.

### Caregiver
1. Create a caregiver account.
2. Enter the patient's six-character Patient ID.
3. The first caregiver becomes the primary caregiver.
4. Later caregivers become backup caregivers and may wait for approval.

### Linking
The caregiver enters the Patient ID on the Link to a Patient screen.
The app checks that the ID exists, then saves the link.
A pending backup link must be approved by the primary caregiver.

## Features

### Built Now
- Email and password sign-in.
- Patient and caregiver account roles.
- Patient profile setup.
- Six-character Patient IDs.
- Patient and caregiver linking.
- Primary and backup caregiver status.
- Caregiver dashboard and profile.
- Care circle management.
- Reminder screens.
- Local notification setup.
- Purple patient and caregiver themes.

### Planned / Not Built Yet
- Safe-zone monitoring and maps.
- Alerts and SOS.
- Medicine tracking.
- Voice assistant.
- Weekly reports.
- Full production reminder automation.

The project uses Firebase free-plan client logic. Cloud Functions are not used by the current app flow.

## Screens

- **Login:** Sign in or open account creation.
- **Welcome:** Choose Patient or Caregiver.
- **Create Account:** Enter name, email, and password.
- **Patient Onboarding:** Create the profile, view the Patient ID, and continue.
- **Link to a Patient:** Caregivers enter a Patient ID.
- **Patient Home:** View the patient ID, reminders, and caregivers.
- **Caregiver Home:** View the caregiver dashboard and link status.
- **Caregiver Profile:** View caregiver details and the linked patient.
- **Manage Caregivers:** Approve and manage backup caregivers.
- **Reminders:** View or manage reminders.
- **Developer Tools:** Open development-only tools when enabled.

## Folder Map

| Folder | What it holds |
|---|---|
| `lib/core/` | Routing, themes, colors, constants, errors, and shared widgets. |
| `lib/data/` | Firestore models, repositories, and services. |
| `lib/features/auth/` | Login, registration, roles, and auth providers. |
| `lib/features/onboarding/` | Patient setup and caregiver linking. |
| `lib/features/patient_home/` | Patient home screen. |
| `lib/features/caregiver_home/` | Caregiver dashboard and profile. |
| `lib/features/care_circle/` | Caregiver approval and management. |
| `lib/features/reminders/` | Reminder data and screens. |
| `lib/features/alerts/` | Reserved alert feature area. |
| `lib/features/safe_zone/` | Reserved safe-zone feature area. |
| `lib/features/sos/` | Planned SOS extension point. |
| `lib/features/medicine/` | Planned medicine extension point. |
| `lib/features/voice_assistant/` | Planned voice extension point. |
| `lib/features/weekly_report/` | Planned report extension point. |

## Tech Used

These packages are listed in `pubspec.yaml`:

- Flutter and Dart.
- Firebase Core, Auth, Firestore, Functions, Messaging, and Storage.
- Riverpod for state management.
- go_router for navigation.
- Google Fonts, cached_network_image, image_picker, image compression, and badges.
- flutter_local_notifications and timezone.
- permission_handler.
- flutter_test and flutter_lints for development.

## Database

`firestore.rules` controls who can read and write each path.

- `users/{uid}`: Account profile for one signed-in user.
- `emailIndex/{email}`: Email lookup used for caregiver accounts.
- `patientCodes/{patientId}`: Patient ID ownership marker.
- `patientPrimary/{patientId}`: First primary caregiver marker.
- `patients/{patientId}`: Patient profile and patient settings.
- `patients/{patientId}/reminders`: Patient reminders.
- `patients/{patientId}/reminderOccurrences`: Reminder occurrences.
- `patients/{patientId}/reminderEvents`: Reminder history events.
- `patients/{patientId}/safeZones`: Reserved safe-zone data.
- `patients/{patientId}/alerts`: Patient alerts.
- `patients/{patientId}/weeks`: Reserved weekly report data.
- `links/{patientId}_{caregiverUid}`: Patient-caregiver links.
- `caregiverLinks/{uid}/patients/{patientId}`: Caregiver link mirrors.

## Run on an Android Phone

1. Install Flutter with Dart 3.7.2 or newer.
2. Install Android Studio and an Android SDK.
3. Get access to the MEMORA Firebase project.
4. Check that `android/app/google-services.json` exists.
5. If it is missing, get `google-services.json` from the project owner and place it in `android/app/`. Do not edit or publish its contents.
6. Open the project root in VS Code.
7. Connect an Android phone with USB debugging enabled.
8. From the project root, run `flutter pub get`.
9. Run `flutter run` and choose the connected phone.
10. Complete the patient and caregiver test flow below.

## Test Flow

1. Create a Patient account.
2. Complete the patient profile.
3. Copy or note the six-character Patient ID.
4. Log out.
5. Create a Caregiver account.
6. Open Link to a Patient.
7. Enter the Patient ID.
8. Confirm the caregiver appears as primary or backup.
9. For a pending backup, approve it from the primary caregiver account.

## Tips and Known Issues

- Press `r` in the `flutter run` terminal for hot reload.
- Press `R` for a full hot restart.
- Use a real Android phone for the main test flow.
- Do not commit passwords, API keys, or `google-services.json`.
- Firebase rules must be published separately by the project owner.
- Some feature folders are placeholders. See Planned / Not Built Yet.
