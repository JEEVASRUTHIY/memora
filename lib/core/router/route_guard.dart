import 'app_routes.dart';

/// Pure redirect policy; access to patient data is also enforced by rules.
String? routeRedirect({
  required String location,
  required bool loading,
  required bool signedIn,
  required String? role,
  bool onboardingDone = true,
  bool patientProfileExists = true,
  required bool devToolsEnabled,
}) {
  const public = {
    AppRoutes.welcome, AppRoutes.login, AppRoutes.register,
    AppRoutes.forgotPassword,
  };
  if (loading) return location == '/session' ? null : '/session';
  if (!signedIn) {
    return location == AppRoutes.welcome || location == AppRoutes.login || location == AppRoutes.register ||
            location == AppRoutes.forgotPassword
        ? null
        : AppRoutes.login;
  }
  if (role != 'patient' && role != 'caregiver') {
    return location == '/session' ? null : '/session';
  }
  final home = role == 'patient'
      ? AppRoutes.patientHome : AppRoutes.caregiverHome;
  if (role == 'patient' && !patientProfileExists &&
      location != AppRoutes.patientOnboarding) {
    return AppRoutes.patientOnboarding;
  }
  if (role == 'patient' && patientProfileExists &&
      location == AppRoutes.patientOnboarding) {
    return home;
  }
  if (public.contains(location) || location == '/session') return home;
  if (location == AppRoutes.devTools && !devToolsEnabled) return home;
  if (role == 'patient' &&
      (location.startsWith('/caregiver/') ||
       location == AppRoutes.linkPatient || location == AppRoutes.caregiverSetup)) {
    return home;
  }
  if (role == 'caregiver' &&
      (location.startsWith('/patient/') ||
       location == AppRoutes.patientId || location == AppRoutes.permissions)) {
    return home;
  }
  return null;
}
