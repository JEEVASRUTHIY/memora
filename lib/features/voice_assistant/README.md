# Voice Assistant extension

Not implemented in the base.

- Collections: `patients/{pid}/reminders and reminderOccurrences through existing repositories`.
- Functions: Existing reminder functions; any new callable must enforce the caller role.
- Add providers under data/ and widgets under presentation/ when implementing.
- Gate the UI with `FeatureFlags.voice` in `lib/core/feature_flags.dart` (false by default). A disabled feature renders nothing (`SizedBox.shrink()`); do not add a placeholder or navigation item.
