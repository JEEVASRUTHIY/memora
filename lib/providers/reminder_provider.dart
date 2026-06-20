import 'dart:async';
import 'package:flutter/material.dart';
import '../models/reminder_model.dart';
import '../models/reminder_log_model.dart';
import '../services/reminder_service.dart';

class ReminderProvider extends ChangeNotifier {
  final ReminderService _service;
  
  StreamSubscription<List<ReminderModel>>? _remindersSubscription;
  List<ReminderModel> _allReminders = [];
  List<ReminderModel> _activeReminders = [];
  
  // Maps to track pending triggered logs that the patient needs to confirm
  // Key: logId, Value: ReminderLogModel
  final Map<String, ReminderLogModel> _pendingTriggers = {};
  
  // Maps to track timers
  // Key: logId, Value: Timer
  final Map<String, Timer> _escalationTimers = {};
  
  // Periodic check timer to see if any reminder is due
  Timer? _dueCheckerTimer;
  
  // Sets of triggered reminder IDs for the current run to prevent double-triggering
  // in the same session
  final Set<String> _triggeredReminderIds = {};

  ReminderProvider({required ReminderService reminderService})
      : _service = reminderService;

  List<ReminderModel> get allReminders => _allReminders;
  List<ReminderModel> get activeReminders => _activeReminders;
  List<ReminderLogModel> get pendingTriggers => _pendingTriggers.values.toList();

  /// Starts listening to reminders for a patient.
  void initialize(String patientId) {
    cancelSubscriptions();
    
    // 1. Listen to all reminders
    _remindersSubscription = _service.getReminders(patientId).listen((reminders) {
      _allReminders = reminders;
      _activeReminders = reminders.where((r) => r.activeStatus).toList();
      notifyListeners();
    });

    // 2. Start due checker timer (every 10 seconds)
    _dueCheckerTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkDueReminders();
    });
  }

  void cancelSubscriptions() {
    _remindersSubscription?.cancel();
    _remindersSubscription = null;
    _dueCheckerTimer?.cancel();
    _dueCheckerTimer = null;
    
    for (var timer in _escalationTimers.values) {
      timer.cancel();
    }
    _escalationTimers.clear();
    _pendingTriggers.clear();
    _triggeredReminderIds.clear();
  }

  /// Scans active reminders to see if any are due.
  Future<void> _checkDueReminders() async {
    final now = DateTime.now();
    for (var reminder in _activeReminders) {
      // Check if scheduledTime is in the past (due or overdue)
      // and we haven't already triggered it in this session.
      if (reminder.scheduledTime.isBefore(now) &&
          !_triggeredReminderIds.contains(reminder.reminderId)) {
        
        _triggeredReminderIds.add(reminder.reminderId);
        
        try {
          // Trigger the reminder (creates log entry in Firestore)
          final log = await _service.triggerReminder(reminder);
          
          // Add to pending triggers list so the patient sees the screen overlay
          _pendingTriggers[log.logId] = log;
          notifyListeners();
          
          // Schedule escalation timer (in minutes)
          final duration = Duration(minutes: reminder.escalationWaitingDuration);
          _escalationTimers[log.logId] = Timer(duration, () {
            _handleEscalation(log.logId);
          });
        } catch (e) {
          debugPrint("Failed to trigger reminder: $e");
          _triggeredReminderIds.remove(reminder.reminderId); // Retry next check
        }
      }
    }
  }

  /// Handles escalation when the patient fails to acknowledge within the duration.
  Future<void> _handleEscalation(String logId) async {
    _escalationTimers.remove(logId);
    final log = _pendingTriggers[logId];
    if (log != null) {
      try {
        // Mark as missed & notify caregiver
        await _service.missReminder(logId, notifyCaregiver: true);
        _pendingTriggers.remove(logId);
        notifyListeners();
      } catch (e) {
        debugPrint("Failed to escalate reminder: $e");
      }
    }
  }

  /// Confirms/Acknowledges the reminder log.
  Future<void> confirmTrigger(String logId) async {
    // Cancel the escalation timer
    _escalationTimers[logId]?.cancel();
    _escalationTimers.remove(logId);
    
    try {
      await _service.confirmReminder(logId);
      _pendingTriggers.remove(logId);
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to confirm reminder log: $e");
      rethrow;
    }
  }

  /// Manually dismiss/miss the reminder log from UI.
  Future<void> dismissTrigger(String logId) async {
    _escalationTimers[logId]?.cancel();
    _escalationTimers.remove(logId);

    try {
      await _service.missReminder(logId, notifyCaregiver: false);
      _pendingTriggers.remove(logId);
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to dismiss reminder log: $e");
      rethrow;
    }
  }

  @override
  void dispose() {
    cancelSubscriptions();
    super.dispose();
  }
}
