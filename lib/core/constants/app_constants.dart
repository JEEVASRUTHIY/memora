/// App-wide constant values.
class AppConstants {
  AppConstants._();

  // Roles
  static const String rolePatient = 'patient';
  static const String roleCaregiver = 'caregiver';

  // Firestore collections
  static const String colUsers = 'users';
  static const String colLinks = 'links';
  static const String colPatients = 'patients';
  static const String colCaregiverLinks = 'caregiverLinks';
  static const String colEmailIndex = 'emailIndex';

  // Patient ID
  static const int patientIdLength = 6;

  // Password minimum length
  static const int minPasswordLength = 8;

  // Link statuses
  static const String linkStatusActive = 'active';
  static const String linkStatusPending = 'pending';
  static const String linkStatusRejected = 'rejected';
  static const String linkStatusRemoved = 'removed';

  // Link roles
  static const String linkRolePrimary = 'primary';
  static const String linkRoleSecondary = 'secondary';

  // Callable function names
  static const String fnRequestLink = 'requestLink';
  static const String fnRespondToLink = 'respondToLink';
  static const String fnRemoveSecondary = 'removeSecondary';
}
