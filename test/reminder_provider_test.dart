import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_async/fake_async.dart';
import 'package:memora/providers/reminder_provider.dart';
import 'package:memora/services/reminder_service.dart';
import 'package:memora/models/reminder_model.dart';
import 'package:memora/models/reminder_log_model.dart';

// Mocks
class MockReminderService extends Mock implements ReminderService {}

void main() {
  late MockReminderService mockService;
  late ReminderProvider reminderProvider;
  late StreamController<List<ReminderModel>> remindersStreamController;

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
  });

  setUp(() {
    mockService = MockReminderService();
    reminderProvider = ReminderProvider(reminderService: mockService);
    remindersStreamController = StreamController<List<ReminderModel>>.broadcast();

    // Default setups
    when(() => mockService.getReminders(any())).thenAnswer((_) => remindersStreamController.stream);
    when(() => mockService.triggerReminder(any())).thenAnswer((_) async => testLog);
    when(() => mockService.confirmReminder(any())).thenAnswer((_) async {});
    when(() => mockService.missReminder(any(), notifyCaregiver: any(named: 'notifyCaregiver'))).thenAnswer((_) async {});
  });

  tearDown(() {
    remindersStreamController.close();
  });

  group('ReminderProvider Tests', () {
    test('initialize starts listening to stream and updates lists', () async {
      reminderProvider.initialize('patient123');

      remindersStreamController.add([testReminder]);
      await Future.delayed(Duration.zero);

      expect(reminderProvider.allReminders, contains(testReminder));
      expect(reminderProvider.activeReminders, contains(testReminder));
    });

    test('due reminder triggers creation of log and adds to pendingTriggers', () {
      fakeAsync((async) {
        reminderProvider.initialize('patient123');
        remindersStreamController.add([testReminder]);

        // Elapse time past the 10-second periodic checker
        async.elapse(const Duration(seconds: 15));

        expect(reminderProvider.pendingTriggers, hasLength(1));
        expect(reminderProvider.pendingTriggers.first.logId, equals('log_123'));
        verify(() => mockService.triggerReminder(testReminder)).called(1);
      });
    });

    test('confirmTrigger cancels escalation timer and confirms reminder', () {
      fakeAsync((async) {
        reminderProvider.initialize('patient123');
        remindersStreamController.add([testReminder]);

        // Elapse to trigger
        async.elapse(const Duration(seconds: 15));
        expect(reminderProvider.pendingTriggers, hasLength(1));

        // Confirm trigger
        reminderProvider.confirmTrigger('log_123');
        async.elapse(Duration.zero);

        expect(reminderProvider.pendingTriggers, isEmpty);
        verify(() => mockService.confirmReminder('log_123')).called(1);
      });
    });

    test('dismissTrigger cancels timer and misses reminder without notifying caregiver', () {
      fakeAsync((async) {
        reminderProvider.initialize('patient123');
        remindersStreamController.add([testReminder]);

        // Elapse to trigger
        async.elapse(const Duration(seconds: 15));
        expect(reminderProvider.pendingTriggers, hasLength(1));

        // Dismiss trigger
        reminderProvider.dismissTrigger('log_123');
        async.elapse(Duration.zero);

        expect(reminderProvider.pendingTriggers, isEmpty);
        verify(() => mockService.missReminder('log_123', notifyCaregiver: false)).called(1);
      });
    });

    test('escalation timer triggers missReminder when patient does not acknowledge', () {
      fakeAsync((async) {
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
  });
}
