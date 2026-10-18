import 'package:memora/data/models/reminder_models.dart';
import 'package:memora/data/models/patient_models.dart';
import 'package:memora/data/repositories/reminder_repository.dart';
import 'package:memora/data/services/notification_service.dart';

/// Business logic for all patient reminder actions.
/// Writes occurrences, events, alerts and cancels notifications.
class ReminderService {
  final ReminderRepository _repo;
  final NotificationService _notifs;

  ReminderService({
    ReminderRepository? repo,
    NotificationService? notifs,
  })  : _repo = repo ?? ReminderRepository(),
        _notifs = notifs ?? NotificationService();

  // ── Confirm ────────────────────────────────────────────────────────────────

  Future<void> confirm({
    required String patientId,
    required ReminderOccurrenceModel occ,
    required DateTime shownTime,
  }) async {
    final now = DateTime.now();
    final updated = occ.copyWith(
      status: 'confirmed',
      shownTime: shownTime,
    );
    await _repo.updateOccurrence(patientId, updated);
    await _notifs.cancel(occ.occurrenceId);
    await _writeEvent(patientId, updated, shownTime, now, 'confirmed');
  }

  // ── Snooze 10 min ─────────────────────────────────────────────────────────

  Future<void> snooze({
    required String patientId,
    required ReminderOccurrenceModel occ,
    required DateTime shownTime,
    int snoozeMinutes = 10,
  }) async {
    final now = DateTime.now();
    final snoozedUntil = now.add(Duration(minutes: snoozeMinutes));
    final updated = occ.copyWith(
      status: 'snoozed',
      snoozedUntil: snoozedUntil,
      snoozeCount: occ.snoozeCount + 1,
      shownTime: shownTime,
    );
    await _repo.updateOccurrence(patientId, updated);
    // Reschedule notification for the snoozed time
    // (full reschedule is triggered on next app open; for immediate snooze we
    //  cancel + re-add just this one)
    await _notifs.cancel(occ.occurrenceId);
    await _writeEvent(patientId, updated, shownTime, now, 'snoozed');
  }

  // ── Auto-repeat (called by background/FCM trigger or timer) ───────────────

  /// Called when [repeatEveryMinutes] has elapsed and the occurrence is still
  /// pending/snoozed. Increments repeatCount; if over limit → missed.
  Future<void> handleRepeat({
    required String patientId,
    required ReminderOccurrenceModel occ,
    required ReminderModel reminder,
  }) async {
    final effectiveMax = reminder.importance == 'high'
        ? reminder.maxRepeats + 2
        : reminder.maxRepeats;

    if (occ.repeatCount >= effectiveMax) {
      await _markMissed(patientId: patientId, occ: occ, reminder: reminder);
      return;
    }

    final updated = occ.copyWith(
      repeatCount: occ.repeatCount + 1,
      status: 'pending',
      snoozedUntil: null,
    );
    await _repo.updateOccurrence(patientId, updated);
    await _writeEvent(
        patientId, updated, occ.shownTime ?? occ.scheduledTime, DateTime.now(), 'pending');
  }

  // ── Mark Missed ───────────────────────────────────────────────────────────

  Future<void> _markMissed({
    required String patientId,
    required ReminderOccurrenceModel occ,
    required ReminderModel reminder,
  }) async {
    final now = DateTime.now();
    final updated = occ.copyWith(status: 'missed');
    await _repo.updateOccurrence(patientId, updated);
    await _notifs.cancel(occ.occurrenceId);
    await _writeEvent(
        patientId, updated, occ.shownTime ?? occ.scheduledTime, now, 'missed');

    // Create missedReminder alert
    final alertId = '${occ.occurrenceId}_alert';
    final alert = AlertModel(
      alertId: alertId,
      type: 'missedReminder',
      message: 'Missed: ${reminder.title}',
      createdAt: now,
      acknowledged: false,
      reminderId: reminder.reminderId,
      occurrenceId: occ.occurrenceId,
      escalationLevel: 0,
      escalateAt: now.add(const Duration(minutes: 3)),
    );
    await _repo.createAlert(patientId, alert);

    // Push delivery belongs to the server alert pipeline (Phase 3).
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _writeEvent(
    String patientId,
    ReminderOccurrenceModel occ,
    DateTime shownTime,
    DateTime responseTime,
    String status,
  ) async {
    final delay = responseTime.difference(shownTime).inSeconds;
    final event = ReminderEventModel(
      eventId: '${occ.occurrenceId}_${responseTime.millisecondsSinceEpoch}',
      occurrenceId: occ.occurrenceId,
      reminderId: occ.reminderId,
      scheduledTime: occ.scheduledTime,
      shownTime: shownTime,
      responseTime: responseTime,
      responseDelaySeconds: delay >= 0 ? delay : null,
      snoozeCount: occ.snoozeCount,
      repeatCount: occ.repeatCount,
      status: status,
      hourOfDay: shownTime.hour,
      createdAt: responseTime,
    );
    await _repo.writeEvent(patientId, event);
  }

}
