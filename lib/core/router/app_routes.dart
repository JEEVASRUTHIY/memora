/// Route path constants. Single source of truth for all route strings.
class AppRoutes {
  AppRoutes._();

  static const String welcome        = '/';
  static const String login          = '/login';
  static const String register       = '/register';
  static const String forgotPassword = '/forgot-password';

  // Patient onboarding
  static const String patientId      = '/onboarding/patient-id';
  static const String patientOnboarding = '/onboarding/patient';
  static const String permissions    = '/onboarding/permissions';

  // Caregiver onboarding
  static const String linkPatient    = '/onboarding/link-patient';
  static const String caregiverSetup = '/onboarding/caregiver-setup';

  // Patient shell
  static const String patientHome    = '/patient/home';
  static const String patientReminders = '/patient/reminders';
  static const String patientProfile = '/patient/profile';
  static const String safeZoneWarning = '/patient/safe-zone-warning';

  // Caregiver shell
  static const String caregiverHome    = '/caregiver/home';
  static const String caregiverProfile  = '/caregiver/profile';
  static const String caregiverReminders = '/caregiver/reminders';
  static const String caregiverSafeZone  = '/caregiver/safe-zone';
  static const String careCircle         = '/caregiver/care-circle';
  static const String alertsList         = '/caregiver/alerts';

  // Shared
  static const String devTools = '/dev-tools';
}
