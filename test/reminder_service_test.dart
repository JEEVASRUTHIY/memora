import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memora/repositories/reminder_repository.dart';
import 'package:memora/services/reminder_service.dart';
import 'package:memora/models/reminder_model.dart';
import 'package:memora/models/reminder_log_model.dart';

// Mocks
class MockReminderRepository extends Mock implements ReminderRepository {}

void main() {
  late MockReminderRepository mockRepository;
  late ReminderService reminderService;

  final testReminder = ReminderModel(
    reminderId: 'rem_123',
    patientId: 'patient123',
    description: 'Take Blood Pressure Tablet',
    instructions: 'Take 1 tablet after breakfast.',
    reminderType: 'Medication',
    scheduledTime: DateTime(2026, 6, 20, 8, 0),
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
    scheduledTime: DateTime(2026, 6, 20, 8, 0),
    status: 'Triggered',
    actionTime: DateTime(2026, 6, 20, 8, 0),
    escalationNotified: false,
  );

  setUpAll(() {
    registerFallbackValue(testReminder);
    registerFallbackValue(testLog);
    registerFallbackValue(DateTime(2026, 6, 20));
  });

  setUp(() {
    mockRepository = MockReminderRepository();
    reminderService = ReminderService(reminderRepository: mockRepository);
  });

  group('ReminderService Tests', () {
    test('createReminder calls repository', () async {
      when(() => mockRepository.createReminder(any())).thenAnswer((_) async => testReminder);

      final result = await reminderService.createReminder(testReminder);

      expect(result, equals(testReminder));
      verify(() => mockRepository.createReminder(testReminder)).called(1);
    });

    test('updateReminder calls repository', () async {
      when(() => mockRepository.updateReminder(any())).thenAnswer((_) async {});

      await reminderService.updateReminder(testReminder);

      verify(() => mockRepository.updateReminder(testReminder)).called(1);
    });

    test('getReminders watches stream from repository', () {
      final stream = Stream.value([testReminder]);
      when(() => mockRepository.watchReminders(any())).thenAnswer((_) => stream);

      final result = reminderService.getReminders('patient123');

      expect(result, emits([testReminder]));
      verify(() => mockRepository.watchReminders('patient123')).called(1);
    });

    test('triggerReminder creates log entry in triggered status', () async {
      when(() => mockRepository.createReminderLog(any())).thenAnswer((_) async => testLog);

      final result = await reminderService.triggerReminder(testReminder);

      expect(result.status, equals('Triggered'));
      verify(() => mockRepository.createReminderLog(any(that: isA<ReminderLogModel>()))).called(1);
    });

    test('confirmReminder updates log status to Completed with completedAt', () async {
      when(() => mockRepository.updateReminderLogStatus(
        any(),
        any(),
        escalationNotified: any(named: 'escalationNotified'),
        completedAt: any(named: 'completedAt'),
      )).thenAnswer((_) async {});

      await reminderService.confirmReminder('log_123');

      verify(() => mockRepository.updateReminderLogStatus(
        'log_123',
        'Completed',
        completedAt: any(named: 'completedAt'),
      )).called(1);
    });

    test('snoozeReminder updates log status to Snoozed', () async {
      when(() => mockRepository.updateReminderLogStatus(
        any(),
        any(),
        escalationNotified: any(named: 'escalationNotified'),
        completedAt: any(named: 'completedAt'),
      )).thenAnswer((_) async {});

      await reminderService.snoozeReminder('log_123');

      verify(() => mockRepository.updateReminderLogStatus('log_123', 'Snoozed')).called(1);
    });

    test('missReminder updates log status to Missed with notification setting', () async {
      when(() => mockRepository.updateReminderLogStatus(
        any(),
        any(),
        escalationNotified: any(named: 'escalationNotified'),
        completedAt: any(named: 'completedAt'),
      )).thenAnswer((_) async {});

      await reminderService.missReminder('log_123', notifyCaregiver: true);

      verify(() => mockRepository.updateReminderLogStatus(
        'log_123',
        'Missed',
        escalationNotified: true,
      )).called(1);
    });

    test('deleteReminder calls repository to delete', () async {
      when(() => mockRepository.deleteReminder(any())).thenAnswer((_) async {});

      await reminderService.deleteReminder('rem_123');

      verify(() => mockRepository.deleteReminder('rem_123')).called(1);
    });
  });
}
