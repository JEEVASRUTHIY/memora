import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/data/models/emergency_contact_model.dart';
import 'package:memora/data/repositories/contact_repository.dart';
import 'package:memora/features/auth/data/auth_providers.dart';

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepository();
});

/// Live stream of emergency contacts for an explicit patientId.
final patientContactsProvider =
    StreamProvider.family<List<EmergencyContactModel>, String>((ref, patientId) {
  if (patientId.trim().isEmpty) {
    return Stream.value(const <EmergencyContactModel>[]);
  }
  return ref.watch(contactRepositoryProvider).watchContacts(patientId);
});

/// Resolves the relevant patientId for the authenticated session:
/// - Patient: their own assigned patientId
/// - Caregiver: the patientId of their active linked patient
final activePatientIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return null;

  if (user.isPatient) {
    final pid = user.patientId?.trim();
    return (pid != null && pid.isNotEmpty) ? pid : null;
  }

  if (user.isCaregiver) {
    final links = ref.watch(caregiverLinksProvider).valueOrNull;
    final activeLink = links?.where((l) => l.isActive).firstOrNull;
    final pid = activeLink?.patientId.trim();
    return (pid != null && pid.isNotEmpty) ? pid : null;
  }

  return null;
});

/// Live stream of emergency contacts for the currently active patient context.
final currentEmergencyContactsProvider =
    StreamProvider<List<EmergencyContactModel>>((ref) {
  final patientId = ref.watch(activePatientIdProvider);
  if (patientId == null || patientId.trim().isEmpty) {
    return Stream.value(const <EmergencyContactModel>[]);
  }
  return ref.watch(contactRepositoryProvider).watchContacts(patientId);
});
