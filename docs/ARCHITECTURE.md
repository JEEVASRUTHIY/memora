# Memora — Architecture

## Directory Structure

```
lib/
  main.dart                 App entry point (MaterialApp.router)
  core/
    app_config.dart         Runtime flags (Maps backend, devTools)
    feature_flags.dart      Feature on/off switches (all false by default)
    constants/app_constants.dart   Firestore paths, role strings, etc.
    errors/app_error_handler.dart  Firebase error → friendly message mapper
    router/
      app_router.dart       go_router definition + auth/role redirect
      app_routes.dart       Route path constants
    theme/app_theme.dart    Material 3 light teal theme (patient + caregiver)
    widgets/app_widgets.dart AppButton, AppCard, StatusChip, EmptyState, …
  data/
    models/                 Immutable Dart models (fromJson / toJson)
    repositories/           One repository per Firestore collection group
    services/               auth_service.dart, notification_service.dart
  features/
    auth/                   Login, register, role selection
    onboarding/             Patient ID screen, permissions flow
    care_circle/            Caregiver management (primary + backups)
    patient_home/           Patient home screen
    caregiver_home/         Caregiver home screen
    reminders/              Reminder list + add/edit (both roles)
    safe_zone/              Map + zone editor (caregiver) + warning (patient)
    alerts/                 Alert list + acknowledge
    dev_tools/              Developer tools (location debug, test buttons)
    sos/                    README only — extension point
    medicine/               README only — extension point
    voice_assistant/        README only — extension point
    weekly_report/          README only — extension point
functions/
  src/
    index.ts                Cloud Functions (requestLink, dispatchReminders, …)
    helpers/sendToUsers.ts  FCM helper (server-side only)
```

## How to Add a Feature in 5 Steps

1. Create `lib/features/<name>/{data,presentation}/` folders and a README.md.
2. Add a flag in `lib/core/feature_flags.dart` defaulting to `false`.
3. Build the screens inside `presentation/` using only Riverpod providers — no Firestore calls in widgets.
4. Add routes to `lib/core/router/app_router.dart` and constants to `app_routes.dart`.
5. Gate any nav entry points with `if (FeatureFlags.<name>)`.

## Feature Flags

See `lib/core/feature_flags.dart`. Setting a flag to `true` enables the UI.
Disabled extension features render nothing; their server implementations do not exist yet.

## State Management

- New code uses Riverpod `AsyncNotifier` / `Notifier`.
- Legacy `StateNotifierProvider` is migrated when the surrounding code is touched.
- Providers live in `features/<feature>/data/`; widgets live in `presentation/`. Shared repositories live in `lib/data/repositories/`.

## Navigation

`go_router` with a single top-level `GoRouter` in `lib/core/router/app_router.dart`.
The router auto-redirects unauthenticated users to `/` (welcome) and routes authenticated
users to the correct home based on their role.

## Phase boundaries
Auth and care-circle screens are retained pending Phase 2. Safe-zone/alerts routes are honest shells for Phase 3. Reminder generation/delivery code predates this phase and needs Phase 4 completion. Developer test actions are disabled. Existing explicit screen styles are replaced as each feature is completed.

