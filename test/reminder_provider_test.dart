import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_async/fake_async.dart';
import 'package:memora/providers/reminder_provider.dart';
import 'package:memora/services/reminder_service.dart';
import 'package:memora/services/notification_service.dart';
import 'package:memora/models/reminder_model.dart';
import 'package:memora/models/reminder_log_model.dart';

// Mocks
class MockReminderService extends Mock implements ReminderService {}
class MockNotificationService extends Mock implements NotificationService {}

void main() {
  late MockReminderService mockService;
  late MockNotificationService mockNotificationService;
  late ReminderProvider reminderProvider;
  late StreamController<List<ReminderModel>> remindersStreamController;
  late StreamController<List<ReminderLogModel>> logsStreamController;
  late StreamController<NotificationActionEvent> actionStreamController;

  final testReminder = ReminderModel(
    reminderId: 'rem_123',
    patientId: 'patient123',
    description: 'Take Blood Pressure Tablet',
    instructions: 'Take 1 tablet after breakfast.',
    reminderType: 'Medication',
    scheduledTime: DateTime.now().subtract(const Duration(minutes: 1)), // In the past, so it's due
    severityLevel: 'High',
    escalationWaitingDuration: 15,
    activeStatus: true,
  );

  final testLog = ReminderLogModel(
    logId: 'log_123',
    reminderId: 'rem_123',
    patientId: 'patient123',
    description: 'Take Blood Pressure Tablet',
    instructions: 'Take 1 tablet after breakfast.',
    reminderType: 'Medication',
    scheduledTime: DateTime.now().subtract(const Duration(minutes: 1)),
    status: 'Triggered',
    actionTime: DateTime.now(),
    escalationNotified: false,
  );

  setUpAll(() {
    registerFallbackValue(testReminder);
    registerFallbackValue(testLog);
    registerFallbackValue(NotificationActionEvent('completed', 'log_123'));
  });

  setUp(() {
    mockService = MockReminderService();
    mockNotificationService = MockNotificationService();

    // Default setups for service
    when(() => mockService.triggerReminder(any())).thenAnswer((_) async => testLog);
    when(() => mockService.confirmReminder(any())).thenAnswer((_) async {});
    when(() => mockService.snoozeReminder(any())).thenAnswer((_) async {});
    when(() => mockService.missReminder(any(), notifyCaregiver: any(named: 'notifyCaregiver'))).thenAnswer((_) async {});

    // Default setups for notifications
    when(() => mockNotificationService.scheduleReminderNotification(any())).thenAnswer((_) async {});
    when(() => mockNotificationService.cancelReminderNotification(any())).thenAnswer((_) async {});
    when(() => mockNotificationService.showInstantNotification(any())).thenAnswer((_) async {});
  });

  void setupProviderAndMocks() {
    remindersStreamController = StreamController<List<ReminderModel>>.broadcast();
    logsStreamController = StreamController<List<ReminderLogModel>>.broadcast();
    actionStreamController = StreamController<NotificationActionEvent>.broadcast();

    when(() => mockService.getReminders(any())).thenAnswer((_) => remindersStreamController.stream);
    when(() => mockService.getReminderLogs(any())).thenAnswer((_) => logsStreamController.stream);
    when(() => mockNotificationService.actionStream).thenAnswer((_) => actionStreamController.stream);

    reminderProvider = ReminderProvider(
      reminderService: mockService,
      notificationService: mockNotificationService,
    );
  }

  tearDown(() {
    try { reminderProvider.dispose(); } catch (_) {}
    try { remindersStreamController.close(); } catch (_) {}
    try { logsStreamController.close(); } catch (_) {}
    try { actionStreamController.close(); } catch (_) {}
  });

  group('ReminderProvider Tests', () {
    test('initialize starts listening to stream and updates lists', () {
      fakeAsync((async) {
        setupProviderAndMocks();
        reminderProvider.initialize('patient123');

        remindersStreamController.add([testReminder]);
        logsStreamController.add([testLog]);
        async.elapse(const Duration(seconds: 1));

        expect(reminderProvider.allReminders, contains(testReminder));
        expect(reminderProvider.activeReminders, contains(testReminder));
        expect(reminderProvider.allLogs, contains(testLog));
      });
    });

    test('due reminder triggers creation of log and adds to pendingTriggers and schedules notification', () {
      fakeAsync((async) {
        setupProviderAndMocks();
        reminderProvider.initialize('patient123');
        remindersStreamController.add([testReminder]);

        // Elapse time past the 10-second periodic checker
        async.elapse(const Duration(seconds: 15));

        expect(reminderProvider.pendingTriggers, hasLength(1));
        expect(reminderProvider.pendingTriggers.first.logId, equals('log_123'));
        verify(() => mockService.triggerReminder(testReminder)).called(1);
        verify(() => mockNotificationService.showInstantNotification(any())).called(1);
      });
    });

    test('confirmTrigger cancels escalation timer/notification and confirms reminder', () {
      fakeAsync((async) {
        setupProviderAndMocks();
        reminderProvider.initialize('patient123');
        remindersStreamController.add([testReminder]);

        // Elapse to trigger
        async.elapse(const Duration(seconds: 15));
        expect(reminderProvider.pendingTriggers, hasLength(1));

        // Confirm trigger
        reminderProvider.confirmTrigger('log_123');
        async.elapse(const Duration(seconds: 1));

        expect(reminderProvider.pendingTriggers, isEmpty);
        verify(() => mockService.confirmReminder('log_123')).called(1);
        verify(() => mockNotificationService.cancelReminderNotification('log_123')).called(1);
      });
    });

    test('dismissTrigger cancels timer/notification and misses reminder without notifying caregiver', () {
      fakeAsync((async) {
        setupProviderAndMocks();
        reminderProvider.initialize('patient123');
        remindersStreamController.add([testReminder]);

        // Elapse to trigger
        async.elapse(const Duration(seconds: 15));
        expect(reminderProvider.pendingTriggers, hasLength(1));

        // Dismiss trigger
        reminderProvider.dismissTrigger('log_123');
        async.elapse(const Duration(seconds: 1));

        expect(reminderProvider.pendingTriggers, isEmpty);
        verify(() => mockService.missReminder('log_123', notifyCaregiver: false)).called(1);
        verify(() => mockNotificationService.cancelReminderNotification('log_123')).called(1);
      });
    });

    test('escalation timer triggers missReminder when patient does not acknowledge', () {
      fakeAsync((async) {
        setupProviderAndMocks();
        reminderProvider.initialize('patient123');
        remindersStreamController.add([testReminder]);

        // Elapse to trigger
        async.elapse(const Duration(seconds: 15));
        expect(reminderProvider.pendingTriggers, hasLength(1));

        // Elapse past escalation waiting duration (15 minutes)
        async.elapse(const Duration(minutes: 16));

        expect(reminderProvider.pendingTriggers, isEmpty);
        verify(() => mockService.missReminder('log_123', notifyCaregiver: true)).called(1);
      });
    });

    test('actionStream completed event triggers confirmTrigger', () {
      fakeAsync((async) {
        setupProviderAndMocks();
        reminderProvider.initialize('patient123');
        remindersStreamController.add([testReminder]);

        // Elapse to trigger
        async.elapse(const Duration(seconds: 15));
        expect(reminderProvider.pendingTriggers, hasLength(1));

        // Send completed action event
        actionStreamController.add(NotificationActionEvent('completed', 'log_123'));
        async.elapse(const Duration(seconds: 1));

        expect(reminderProvider.pendingTriggers, isEmpty);
        verify(() => mockService.confirmReminder('log_123')).called(1);
      });
    });

    test('actionStream snooze event triggers snoozeTrigger', () {
      fakeAsync((async) {
        setupProviderAndMocks();
        reminderProvider.initialize('patient123');
        remindersStreamController.add([testReminder]);

        // Elapse to trigger
        async.elapse(const Duration(seconds: 15));
        expect(reminderProvider.pendingTriggers, hasLength(1));

        // Send snooze action event
        actionStreamController.add(NotificationActionEvent('snooze', 'log_123'));
        async.elapse(const Duration(seconds: 1));

        expect(reminderProvider.pendingTriggers, isEmpty);
        verify(() => mockService.snoozeReminder('log_123')).called(1);
        verify(() => mockNotificationService.showInstantNotification(any())).called(1);
        verify(() => mockNotificationService.scheduleReminderNotification(any(that: isA<ReminderLogModel>()))).called(1);
      });
    });

    test('snoozeTrigger cancels old timer, snoozes log, schedules snooze notification, and starts new timer', () {
      fakeAsync((async) {
        setupProviderAndMocks();
        reminderProvider.initialize('patient123');
        remindersStreamController.add([testReminder]);

        // Elapse to trigger
        async.elapse(const Duration(seconds: 15));
        expect(reminderProvider.pendingTriggers, hasLength(1));

        // Call snoozeTrigger directly
        reminderProvider.snoozeTrigger('log_123');
        async.elapse(const Duration(seconds: 1));

        expect(reminderProvider.pendingTriggers, isEmpty);
        verify(() => mockService.snoozeReminder('log_123')).called(1);
        verify(() => mockNotificationService.cancelReminderNotification('log_123')).called(1);
        verify(() => mockNotificationService.showInstantNotification(any())).called(1);
        verify(() => mockNotificationService.scheduleReminderNotification(any(that: isA<ReminderLogModel>()))).called(1);

        // Elapse past 5 minutes to trigger escalation from snooze
        async.elapse(const Duration(minutes: 6));
        verify(() => mockService.missReminder('log_123', notifyCaregiver: true)).called(1);
      });
    });

    test('caregiver is notified locally when a missed log arrives with escalationNotified true', () {
      fakeAsync((async) {
        setupProviderAndMocks();
        reminderProvider.initialize('patient123');
        
        final missedLog = testLog.copyWith(
          logId: 'log_missed_999',
          status: 'Missed',
          escalationNotified: true,
        );

        logsStreamController.add([missedLog]);
        async.elapse(const Duration(seconds: 1));

        verify(() => mockNotificationService.scheduleReminderNotification(any(that: isA<ReminderLogModel>()))).called(1);
      });
    });
  });
}
