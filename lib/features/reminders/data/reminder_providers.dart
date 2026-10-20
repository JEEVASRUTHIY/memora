import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/data/models/reminder_models.dart';
import 'package:memora/data/repositories/reminder_repository.dart';
import 'package:memora/data/services/reminder_service.dart';
import 'package:memora/data/services/notification_service.dart';

// ── Singletons ─────────────────────────────────────────────────────────────

final reminderRepositoryProvider = Provider<ReminderRepository>(
  (_) => ReminderRepository(),
);

final notificationServiceProvider = Provider<NotificationService>(
  (_) => NotificationService(),
);

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(
    repo: ref.watch(reminderRepositoryProvider),
    notifs: ref.watch(notificationServiceProvider),
  );
});

// ── Streams ────────────────────────────────────────────────────────────────

/// Active reminders for the given patient — used by caregivers.
final remindersProvider =
    StreamProvider.family<List<ReminderModel>, String>((ref, patientId) {
  return ref.watch(reminderRepositoryProvider).watchReminders(patientId);
});

/// Actionable occurrences for the patient home screen.
/// Filters to only pending/snoozed whose time has come; NEVER shows confirmed/missed.
final actionableOccurrencesProvider =
    StreamProvider.family<List<ReminderOccurrenceModel>, String>(
        (ref, patientId) {
  return ref
      .watch(reminderRepositoryProvider)
      .watchActionableOccurrences(patientId);
});

/// All active (pending or currently snoozed) occurrences for the caregiver dashboard.
final activeOccurrencesProvider =
    StreamProvider.family<List<ReminderOccurrenceModel>, String>(
        (ref, patientId) {
  return ref
      .watch(reminderRepositoryProvider)
      .watchActiveOccurrences(patientId);
});

// ── Caregiver: manage reminders ───────────────────────────────────────────

class ReminderManagementNotifier
    extends FamilyNotifier<AsyncValue<void>, String> {
  ReminderRepository get _repo => ref.read(reminderRepositoryProvider);
  late String _patientId;
  @override
  AsyncValue<void> build(String patientId) {
    _patientId = patientId;
    return const AsyncData(null);
  }

  Future<bool> create(ReminderModel reminder) async {
    state = const AsyncLoading();
    try {
      final ref = _repo.createReminder(_patientId, reminder);
      await ref;
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> update(ReminderModel reminder) async {
    state = const AsyncLoading();
    try {
      await _repo.updateReminder(_patientId, reminder);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> delete(String reminderId) async {
    state = const AsyncLoading();
    try {
      await _repo.deleteReminder(_patientId, reminderId);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final reminderManagementProvider = NotifierProvider.family<
    ReminderManagementNotifier,
    AsyncValue<void>,
    String>(ReminderManagementNotifier.new);

// ── Patient: action notifier ───────────────────────────────────────────────

class ReminderActionNotifier extends FamilyNotifier<AsyncValue<void>, String> {
  ReminderService get _service => ref.read(reminderServiceProvider);
  late String _patientId;
  @override
  AsyncValue<void> build(String patientId) {
    _patientId = patientId;
    return const AsyncData(null);
  }

  Future<void> confirm(ReminderOccurrenceModel occ) async {
    state = const AsyncLoading();
    try {
      await _service.confirm(
        patientId: _patientId,
        occ: occ,
        shownTime: occ.shownTime ?? DateTime.now(),
      );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> snooze(ReminderOccurrenceModel occ) async {
    state = const AsyncLoading();
    try {
      await _service.snooze(
        patientId: _patientId,
        occ: occ,
        shownTime: occ.shownTime ?? DateTime.now(),
      );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final reminderActionProvider = NotifierProvider.family<
    ReminderActionNotifier,
    AsyncValue<void>,
    String>(ReminderActionNotifier.new);
