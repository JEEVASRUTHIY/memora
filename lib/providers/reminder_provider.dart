import 'dart:async';
import 'package:flutter/material.dart';
import '../models/reminder_model.dart';
import '../models/reminder_log_model.dart';
import '../services/reminder_service.dart';
import '../services/notification_service.dart';

class ReminderProvider extends ChangeNotifier {
  final ReminderService _service;
  final NotificationService? _notificationService;
  
  StreamSubscription<List<ReminderModel>>? _remindersSubscription;
  StreamSubscription<List<ReminderLogModel>>? _logsSubscription;
  StreamSubscription<NotificationActionEvent>? _actionSubscription;
  
  List<ReminderModel> _allReminders = [];
  List<ReminderModel> _activeReminders = [];
  List<ReminderLogModel> _allLogs = [];
  
  // Set to keep track of missed log IDs we've already notified the caregiver about
  final Set<String> _notifiedMissedLogs = {};
  
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
  bool _isPatient = false;

  ReminderProvider({
    required ReminderService reminderService,
    NotificationService? notificationService,
  })  : _service = reminderService,
        _notificationService = notificationService {
    _listenToNotificationActions();
  }

  List<ReminderModel> get allReminders => _allReminders;
  List<ReminderModel> get activeReminders => _activeReminders;
  List<ReminderLogModel> get allLogs => _allLogs;
  List<ReminderLogModel> get pendingTriggers => _pendingTriggers.values.toList();

  /// Starts listening to reminders for a patient.
  void initialize(String patientId, {bool isPatient = true}) {
    _isPatient = isPatient;
    cancelSubscriptions();
    
    _remindersSubscription = _service.getReminders(patientId).listen((reminders) async {
      // Cancel previous scheduled notifications
      if (_isPatient) {
        for (var reminder in _allReminders) {
          await _notificationService?.cancelReminderNotification('rem_notif_${reminder.reminderId}');
        }
      }
      
      _allReminders = reminders;
      _activeReminders = reminders.where((r) => r.activeStatus).toList();

      // Cancel pending triggers and timers for deleted reminders
      final activeReminderIds = reminders.map((r) => r.reminderId).toSet();
      final triggersToRemove = <String>[];
      for (var entry in _pendingTriggers.entries) {
        if (!activeReminderIds.contains(entry.value.reminderId)) {
          triggersToRemove.add(entry.key);
        }
      }
      for (var targetLogId in triggersToRemove) {
        _escalationTimers[targetLogId]?.cancel();
        _escalationTimers.remove(targetLogId);
        _pendingTriggers.remove(targetLogId);
        await _notificationService?.cancelReminderNotification(targetLogId);
      }

      notifyListeners();

      // Schedule new future notifications
      if (_isPatient) {
        _scheduleFutureNotifications();
      }
    });

    // 2. Listen to logs (for caregiver alerts and stats)
    _logsSubscription = _service.getReminderLogs(patientId).listen((logs) {
      for (var log in logs) {
        if (log.status.toLowerCase() == 'missed' &&
            log.escalationNotified &&
            !_notifiedMissedLogs.contains(log.logId)) {
          _notifiedMissedLogs.add(log.logId);
          _showCaregiverLocalNotification(log);
        }
      }
      _allLogs = logs;
      notifyListeners();
    });

    // 3. Start due checker timer (every 10 seconds)
    if (_isPatient) {
      _dueCheckerTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        _checkDueReminders();
      });
    }
  }

  void _listenToNotificationActions() {
    _actionSubscription?.cancel();
    _actionSubscription = _notificationService?.actionStream.listen((event) {
      if (event.actionId == 'completed') {
        confirmTrigger(event.logId);
      } else if (event.actionId == 'snooze') {
        snoozeTrigger(event.logId);
      }
    });
  }

  Future<void> _scheduleFutureNotifications() async {
    if (_notificationService == null) return;
    
    final now = DateTime.now();
    for (var reminder in _activeReminders) {
      if (reminder.scheduledTime.isAfter(now)) {
        final tempLog = ReminderLogModel(
          logId: 'rem_notif_${reminder.reminderId}',
          reminderId: reminder.reminderId,
          patientId: reminder.patientId,
          description: reminder.description,
          instructions: reminder.instructions,
          reminderType: reminder.reminderType,
          scheduledTime: reminder.scheduledTime,
          status: 'Scheduled',
          actionTime: now,
          imageUrl: reminder.imageUrl,
        );
        await _notificationService!.scheduleReminderNotification(tempLog);
      }
    }
  }

  void _showCaregiverLocalNotification(ReminderLogModel log) {
    _notificationService?.scheduleReminderNotification(
      ReminderLogModel(
        logId: 'caregiver_alert_${log.logId}',
        reminderId: log.reminderId,
        patientId: log.patientId,
        description: 'Patient Missed: ${log.description}',
        instructions: 'Escalated reminder scheduled at ${log.scheduledTime}.',
        reminderType: log.reminderType,
        scheduledTime: DateTime.now().add(const Duration(seconds: 1)),
        status: 'Triggered',
        actionTime: DateTime.now(),
      ),
    );
  }

  void cancelSubscriptions() {
    _remindersSubscription?.cancel();
    _remindersSubscription = null;
    _logsSubscription?.cancel();
    _logsSubscription = null;
    _dueCheckerTimer?.cancel();
    _dueCheckerTimer = null;
    
    for (var timer in _escalationTimers.values) {
      timer.cancel();
    }
    _escalationTimers.clear();
    _pendingTriggers.clear();
    _triggeredReminderIds.clear();
    _notifiedMissedLogs.clear();
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

          // Trigger local device notification immediately in the foreground!
          await _notificationService?.showInstantNotification(log);
          
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
  Future<void> _handleEscalation(String logId, {ReminderLogModel? fallbackLog}) async {
    _escalationTimers.remove(logId);
    final log = _pendingTriggers[logId] ?? fallbackLog;
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

  /// Confirms/Acknowledges the reminder log as Completed.
  Future<void> confirmTrigger(String logId) async {
    _escalationTimers[logId]?.cancel();
    _escalationTimers.remove(logId);
    await _notificationService?.cancelReminderNotification(logId);
    
    try {
      await _service.confirmReminder(logId);
      _pendingTriggers.remove(logId);
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to confirm reminder log: $e");
      rethrow;
    }
  }

  /// Snoozes the reminder log for 5 minutes.
  Future<void> snoozeTrigger(String logId) async {
    _escalationTimers[logId]?.cancel();
    _escalationTimers.remove(logId);
    await _notificationService?.cancelReminderNotification(logId);

    final log = _pendingTriggers[logId];
    if (log != null && log.snoozeEnabled) {
      try {
        await _service.snoozeReminder(logId);
        _pendingTriggers.remove(logId);
        notifyListeners();

        // Reschedule snooze notification & new escalation timer (5 minutes from now)
        final snoozeTime = DateTime.now().add(const Duration(minutes: 5));
        
        await _notificationService?.scheduleReminderNotification(
          log.copyWith(
            status: 'Snoozed',
            scheduledTime: snoozeTime,
          ),
        );

        // Schedule next escalation timer
        _escalationTimers[logId] = Timer(const Duration(minutes: 5), () {
          _handleEscalation(logId, fallbackLog: log);
        });
      } catch (e) {
        debugPrint("Failed to snooze reminder log: $e");
      }
    }
  }

  /// Manually dismiss/miss the reminder log from UI.
  Future<void> dismissTrigger(String logId) async {
    _escalationTimers[logId]?.cancel();
    _escalationTimers.remove(logId);
    await _notificationService?.cancelReminderNotification(logId);

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
    _actionSubscription?.cancel();
    _actionSubscription = null;
    super.dispose();
  }
}
