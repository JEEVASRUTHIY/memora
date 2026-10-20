import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:memora/data/models/reminder_models.dart';
import 'package:memora/data/models/patient_models.dart';

/// All Firestore operations for reminders, occurrences, events, and alerts.
class ReminderRepository {
  final FirebaseFirestore _db;

  ReminderRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ── Reminders ──────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _reminders(String patientId) =>
      _db.collection('patients').doc(patientId).collection('reminders');

  String newReminderId(String patientId) => _reminders(patientId).doc().id;

  Stream<List<ReminderModel>> watchReminders(String patientId) {
    return _reminders(patientId)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => ReminderModel.fromMap(d.data(), d.id))
            .toList());
  }

  Future<void> createReminder(String patientId, ReminderModel reminder) {
    return _reminders(patientId).doc(reminder.reminderId).set(reminder.toMap());
  }

  Future<void> updateReminder(String patientId, ReminderModel reminder) {
    return _reminders(patientId)
        .doc(reminder.reminderId)
        .update(reminder.toMap());
  }

  Future<void> deleteReminder(String patientId, String reminderId) {
    // Soft delete: mark inactive so occurrences stay intact for audit.
    return _reminders(patientId)
        .doc(reminderId)
        .update({'active': false});
  }

  // ── Occurrences ────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _occurrences(String patientId) =>
      _db.collection('patients').doc(patientId).collection('reminderOccurrences');

  /// Returns only pending/snoozed occurrences whose time has come.
  Stream<List<ReminderOccurrenceModel>> watchActionableOccurrences(
      String patientId) {
    return _occurrences(patientId)
        .where('status', whereIn: ['pending', 'snoozed'])
        .snapshots()
        .map((s) {
          final now = DateTime.now();
          return s.docs
              .map((d) => ReminderOccurrenceModel.fromMap(d.data(), d.id))
              .where((occ) {
                if (occ.status == 'snoozed' && occ.snoozedUntil != null) {
                  return now.isAfter(occ.snoozedUntil!);
                }
                return now.isAfter(occ.scheduledTime);
              })
              .toList()
            ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
        });
  }

  /// Returns all pending and snoozed occurrences in real time for caregivers,
  /// so they can see snoozed status immediately even before the snooze window expires.
  Stream<List<ReminderOccurrenceModel>> watchActiveOccurrences(
      String patientId) {
    return _occurrences(patientId)
        .where('status', whereIn: ['pending', 'snoozed'])
        .snapshots()
        .map((s) => s.docs
            .map((d) => ReminderOccurrenceModel.fromMap(d.data(), d.id))
            .toList()
          ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime)));
  }

  /// Returns all pending/snoozed future occurrences (for notification scheduling).
  Future<List<ReminderOccurrenceModel>> getPendingFutureOccurrences(
      String patientId) async {
    final snap = await _occurrences(patientId)
        .where('status', whereIn: ['pending', 'snoozed'])
        .where('scheduledTime',
            isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .get();
    return snap.docs
        .map((d) => ReminderOccurrenceModel.fromMap(d.data(), d.id))
        .toList();
  }

  /// create-if-absent: only writes if the document doesn't already exist.
  Future<void> createOccurrenceIfAbsent(
      String patientId, ReminderOccurrenceModel occ) async {
    final ref = _occurrences(patientId).doc(occ.occurrenceId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, occ.toMap());
      }
    });
  }

  Future<void> updateOccurrence(
      String patientId, ReminderOccurrenceModel occ) {
    return _occurrences(patientId)
        .doc(occ.occurrenceId)
        .update(occ.toMap());
  }

  Future<ReminderOccurrenceModel?> getOccurrence(
      String patientId, String occurrenceId) async {
    final snap =
        await _occurrences(patientId).doc(occurrenceId).get();
    if (!snap.exists) return null;
    return ReminderOccurrenceModel.fromMap(snap.data()!, snap.id);
  }

  // ── Events (ML audit log) ─────────────────────────────────────────────────

  Future<void> writeEvent(String patientId, ReminderEventModel event) {
    return _db
        .collection('patients')
        .doc(patientId)
        .collection('reminderEvents')
        .doc(event.eventId)
        .set(event.toMap());
  }

  // ── Alerts ────────────────────────────────────────────────────────────────

  Future<void> createAlert(String patientId, AlertModel alert) {
    return _db
        .collection('patients')
        .doc(patientId)
        .collection('alerts')
        .doc(alert.alertId)
        .set(alert.toMap());
  }
}
