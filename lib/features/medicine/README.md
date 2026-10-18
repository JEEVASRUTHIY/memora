# Medicine extension

Not implemented in the base.

- Collections: `patients/{pid}/reminders, reminderOccurrences and reminderEvents`.
- Functions: generateOccurrences and dispatchReminders.
- Add providers under data/ and widgets under presentation/ when implementing.
- Gate the UI with `FeatureFlags.medicine` in `lib/core/feature_flags.dart` (false by default). A disabled feature renders nothing (`SizedBox.shrink()`); do not add a placeholder or navigation item.
