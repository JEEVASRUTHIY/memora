# Weekly Report extension

Not implemented in the base.

- Collections: `patients/{pid}/reminderEvents (input), patients/{pid}/weeks (future output)`.
- Functions: A future server-only report generator.
- Add providers under data/ and widgets under presentation/ when implementing.
- Gate the UI with `FeatureFlags.weeklyReport` in `lib/core/feature_flags.dart` (false by default). A disabled feature renders nothing (`SizedBox.shrink()`); do not add a placeholder or navigation item.
