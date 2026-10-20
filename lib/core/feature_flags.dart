/// Feature flags — all default to false.
/// Set a flag to true to enable its feature. Gated screens render nothing
/// while the flag is false.
///
/// See the README.md in each feature folder for how to enable.
class FeatureFlags {
  FeatureFlags._();

  /// SOS button on patient home screen.
  static const bool sos = false;

  /// Medicine management tab (caregiver) and tracking (patient).
  static const bool medicine = true;

  /// Voice assistant FAB on patient home screen.
  static const bool voice = true;

  /// Weekly behaviour report card on caregiver home screen.
  static const bool weeklyReport = false;

  /// Reminder photos and voice notes.
  static const bool reminderMedia = false;
}
