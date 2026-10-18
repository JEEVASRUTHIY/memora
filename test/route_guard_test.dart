import 'package:flutter_test/flutter_test.dart';
import 'package:memora/core/router/route_guard.dart';

void main() {
  String? redirect(String path, {bool loading = false, bool signedIn = true,
    String? role = 'patient', bool dev = true,
    bool patientProfileExists = true}) => routeRedirect(
      location: path, loading: loading, signedIn: signedIn, role: role,
      devToolsEnabled: dev, patientProfileExists: patientProfileExists);

  test('signed-out deep links return to login', () {
    for (final path in ['/patient/home', '/caregiver/reminders', '/dev-tools']) {
      expect(redirect(path, signedIn: false), '/login');
    }
    expect(redirect('/login', signedIn: false), isNull);
    expect(redirect('/', signedIn: false), isNull);
    expect(redirect('/forgot-password', signedIn: false), isNull);
  });
  test('loading or missing profiles cannot expose protected screens', () {
    expect(redirect('/patient/home', loading: true), '/session');
    expect(redirect('/caregiver/home', role: null), '/session');
    expect(redirect('/session', role: 'invalid'), isNull);
  });
  test('roles cannot visit each other or their onboarding routes', () {
    expect(redirect('/caregiver/reminders'), '/patient/home');
    expect(redirect('/onboarding/link-patient'), '/patient/home');
    expect(redirect('/patient/home', role: 'caregiver'), '/caregiver/home');
    expect(redirect('/onboarding/permissions', role: 'caregiver'), '/caregiver/home');
    expect(redirect('/patient/home'), isNull);
    expect(redirect('/caregiver/home', role: 'caregiver'), isNull);
  });
  test('signed-in public routes and disabled tools return to role home', () {
    expect(redirect('/login'), '/patient/home');
    expect(redirect('/session', role: 'caregiver'), '/caregiver/home');
    expect(redirect('/dev-tools', dev: false), '/patient/home');
  });

  test('incomplete patients stay on profile onboarding', () {
    expect(redirect('/patient/home', patientProfileExists: false), '/onboarding/patient');
    expect(redirect('/onboarding/patient', patientProfileExists: false), isNull);
  });
}
