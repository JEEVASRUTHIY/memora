import 'dart:convert';
import 'package:memora/data/models/reminder_models.dart';
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

  // ── Confirm ───────────────────────────────────────────────────────────────

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

  // ── Snooze 5 min ──────────────────────────────────────────────────────────

  Future<void> snooze({
    required String patientId,
    required ReminderOccurrenceModel occ,
    required DateTime shownTime,
    int snoozeMinutes = 5,
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

    // Cancel existing notification and reschedule for the snoozed time
    await _notifs.cancel(occ.occurrenceId);
    await _notifs.scheduleOccurrence(
      occurrenceId: occ.occurrenceId,
      title: 'Snoozed Reminder',
      body: 'Time for your snoozed reminder.',
      scheduledTime: snoozedUntil,
      payload: jsonEncode({
        'occurrenceId': occ.occurrenceId,
        'patientId': patientId,
        'reminderId': occ.reminderId,
        'type': 'reminder',
      }),
    );
    await _writeEvent(patientId, updated, shownTime, now, 'snoozed');
  }

  // ── Missed ────────────────────────────────────────────────────────────────

  Future<void> miss({
    required String patientId,
    required ReminderOccurrenceModel occ,
    required DateTime shownTime,
  }) async {
    final now = DateTime.now();
    final updated = occ.copyWith(
      status: 'missed',
      shownTime: shownTime,
    );
    await _repo.updateOccurrence(patientId, updated);
    await _notifs.cancel(occ.occurrenceId);
    await _writeEvent(patientId, updated, shownTime, now, 'missed');
  }

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

  // ── Scheduled Reminders Synchronization ────────────────────────────────────

  /// Synchronizes Firestore occurrences and exact local notifications for active reminders.
  /// Generates upcoming occurrences for the next 48 hours, records them in Firestore
  /// if absent, and schedules notifications via NotificationService.
  Future<void> syncScheduledReminders(
    String patientId,
    List<ReminderModel> reminders,
  ) async {
    final now = DateTime.now();
    final windowEnd = now.add(const Duration(hours: 48));

    for (final rem in reminders) {
      if (!rem.active) {
        await _notifs.cancelReminder(rem.reminderId);
        continue;
      }

      final occTimes = computeOccurrenceTimes(rem, now, windowEnd);
      for (final occTime in occTimes) {
        final occId = '${rem.reminderId}_${formatOccId(occTime)}';
        final occ = ReminderOccurrenceModel(
          occurrenceId: occId,
          reminderId: rem.reminderId,
          scheduledTime: occTime,
          status: 'pending',
          repeatCount: 0,
          snoozeCount: 0,
        );

        // Record occurrence in Firestore if not yet generated
        await _repo.createOccurrenceIfAbsent(patientId, occ);

        // Schedule local exact notification
        await _notifs.scheduleOccurrence(
          occurrenceId: occId,
          title: rem.title,
          body: rem.note ?? 'Time for: ${rem.title}',
          scheduledTime: occTime,
          payload: jsonEncode({
            'occurrenceId': occId,
            'patientId': patientId,
            'reminderId': rem.reminderId,
            'type': 'reminder',
          }),
        );
      }
    }
  }

  /// Formats a DateTime into deterministic "yyyyMMddHHmm" string for stable occurrenceId.
  static String formatOccId(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$y$m$day$h$min';
  }

  /// Computes occurrence times for a reminder between [now] and [windowEnd].
  static List<DateTime> computeOccurrenceTimes(
    ReminderModel rem,
    DateTime now,
    DateTime windowEnd,
  ) {
    final result = <DateTime>[];
    final times = rem.times.isNotEmpty ? rem.times : ['09:00'];

    DateTime timeOfDayOnDate(DateTime base, String hhmm) {
      final parts = hhmm.split(':');
      final h = int.tryParse(parts[0]) ?? 9;
      final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      return DateTime(base.year, base.month, base.day, h, m);
    }

    if (rem.recurrence == 'once') {
      for (final t in times) {
        final candidate = timeOfDayOnDate(now, t);
        if (candidate.isAfter(now) && !candidate.isAfter(windowEnd)) {
          result.add(candidate);
        }
      }
      return result;
    }

    var cursor = DateTime(now.year, now.month, now.day);
    while (!cursor.isAfter(windowEnd)) {
      bool shouldFire = false;
      if (rem.recurrence == 'daily') {
        shouldFire = true;
      } else if (rem.recurrence == 'weekly') {
        shouldFire = cursor.weekday == rem.createdAt.weekday;
      }
      if (shouldFire) {
        for (final t in times) {
          final candidate = timeOfDayOnDate(cursor, t);
          if (candidate.isAfter(now) && !candidate.isAfter(windowEnd)) {
            result.add(candidate);
          }
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return result;
  }
}
