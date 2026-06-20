import '../models/reminder_model.dart';
import '../models/reminder_log_model.dart';
import '../repositories/reminder_repository.dart';

class ReminderService {
  final ReminderRepository _repository;

  ReminderService({required ReminderRepository reminderRepository})
      : _repository = reminderRepository;

  /// Creates a new reminder.
  Future<ReminderModel> createReminder(ReminderModel reminder) {
    return _repository.createReminder(reminder);
  }

  /// Updates an existing reminder.
  Future<void> updateReminder(ReminderModel reminder) {
    return _repository.updateReminder(reminder);
  }

  /// Fetches reminders as a real-time stream.
  Stream<List<ReminderModel>> getReminders(String patientId) {
    return _repository.watchReminders(patientId);
  }

  /// Triggers a reminder: creates a new ReminderLogModel with 'Triggered' status.
  Future<ReminderLogModel> triggerReminder(ReminderModel reminder) async {
    final log = ReminderLogModel(
      logId: '',
      reminderId: reminder.reminderId,
      patientId: reminder.patientId,
      description: reminder.description,
      instructions: reminder.instructions,
      reminderType: reminder.reminderType,
      scheduledTime: reminder.scheduledTime,
      status: 'Triggered',
      actionTime: DateTime.now(),
      escalationNotified: false,
    );
    return _repository.createReminderLog(log);
  }

  /// Confirms a triggered reminder as Completed.
  Future<void> confirmReminder(String logId) {
    return _repository.updateReminderLogStatus(
      logId, 
      'Completed',
      completedAt: DateTime.now(),
    );
  }

  /// Snoozes a triggered reminder.
  Future<void> snoozeReminder(String logId) {
    return _repository.updateReminderLogStatus(logId, 'Snoozed');
  }

  /// Marks a triggered reminder as missed (escalated).
  Future<void> missReminder(String logId, {bool notifyCaregiver = true}) {
    return _repository.updateReminderLogStatus(
      logId,
      'Missed',
      escalationNotified: notifyCaregiver,
    );
  }

  /// Fetches log entries for the patient.
  Stream<List<ReminderLogModel>> getReminderLogs(String patientId) {
    return _repository.watchReminderLogs(patientId);
  }
}
