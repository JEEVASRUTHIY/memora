import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:memora/repositories/reminder_repository.dart';
import 'package:memora/models/reminder_model.dart';
import 'package:memora/models/reminder_log_model.dart';

// Mocks
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late MockDocumentReference mockDocument;
  late MockDocumentSnapshot mockSnapshot;
  late ReminderRepository reminderRepository;

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
    actionTime: DateTime(2026, 6, 20, 8, 5),
    escalationNotified: false,
  );

  setUpAll(() {
    registerFallbackValue(SetOptions(merge: true));
  });

  String docId = 'mock_id_123';

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockDocument = MockDocumentReference();
    mockSnapshot = MockDocumentSnapshot();
    reminderRepository = ReminderRepository(firestore: mockFirestore);

    docId = 'mock_id_123';

    when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
    
    // For both doc() and doc(any), return mockDocument and update docId
    when(() => mockCollection.doc()).thenAnswer((_) {
      docId = 'mock_id_123';
      return mockDocument;
    });
    when(() => mockCollection.doc(any())).thenAnswer((invocation) {
      final idArg = invocation.positionalArguments.isNotEmpty 
          ? invocation.positionalArguments[0] as String? 
          : null;
      docId = idArg ?? 'mock_id_123';
      return mockDocument;
    });

    when(() => mockDocument.id).thenAnswer((_) => docId);
    when(() => mockDocument.set(any())).thenAnswer((_) async {});
    when(() => mockDocument.set(any(), any())).thenAnswer((_) async {});
    when(() => mockDocument.update(any())).thenAnswer((_) async {});
    when(() => mockDocument.get()).thenAnswer((_) async => mockSnapshot);
    
    // Stub snapshot ID
    when(() => mockSnapshot.id).thenReturn('rem_123');
  });

  group('ReminderRepository Tests', () {
    test('createReminder generates ID and saves reminder when ID is empty', () async {
      final inputReminder = testReminder.copyWith(reminderId: '');
      when(() => mockDocument.set(any())).thenAnswer((_) async {});

      final result = await reminderRepository.createReminder(inputReminder);

      expect(result.reminderId, equals('mock_id_123'));
      verify(() => mockFirestore.collection('reminders')).called(1);
      verify(() => mockCollection.doc()).called(1);
      verify(() => mockDocument.set(any())).called(1);
    });

    test('createReminder saves with existing ID when ID is provided', () async {
      when(() => mockDocument.set(any())).thenAnswer((_) async {});

      final result = await reminderRepository.createReminder(testReminder);

      expect(result.reminderId, equals('rem_123'));
      verify(() => mockFirestore.collection('reminders')).called(1);
      verify(() => mockCollection.doc('rem_123')).called(1);
      verify(() => mockDocument.set(any())).called(1);
    });

    test('updateReminder sets data with merge option', () async {
      when(() => mockDocument.set(any(), any())).thenAnswer((_) async {});

      await reminderRepository.updateReminder(testReminder);

      verify(() => mockCollection.doc('rem_123')).called(1);
      verify(() => mockDocument.set(any(), any())).called(1);
    });

    test('getReminder returns ReminderModel when document exists', () async {
      when(() => mockDocument.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.exists).thenReturn(true);
      when(() => mockSnapshot.data()).thenReturn(testReminder.toJson());

      final result = await reminderRepository.getReminder('rem_123');

      expect(result, isNotNull);
      expect(result!.reminderId, equals('rem_123'));
      expect(result.description, equals('Take Blood Pressure Tablet'));
    });

    test('getReminder returns null when document does not exist', () async {
      when(() => mockDocument.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.exists).thenReturn(false);

      final result = await reminderRepository.getReminder('rem_123');

      expect(result, isNull);
    });

    test('createReminderLog generates ID and saves reminder log', () async {
      final inputLog = testLog.copyWith(logId: '');
      when(() => mockDocument.set(any())).thenAnswer((_) async {});

      final result = await reminderRepository.createReminderLog(inputLog);

      expect(result.logId, equals('mock_id_123'));
      verify(() => mockFirestore.collection('reminderLogs')).called(1);
      verify(() => mockCollection.doc()).called(1);
      verify(() => mockDocument.set(any())).called(1);
    });

    test('updateReminderLogStatus updates status and actionTime', () async {
      when(() => mockDocument.update(any())).thenAnswer((_) async {});

      await reminderRepository.updateReminderLogStatus('log_123', 'Confirmed');

      verify(() => mockCollection.doc('log_123')).called(1);
      verify(() => mockDocument.update(any(that: isA<Map<String, dynamic>>()))).called(1);
    });

    test('deleteReminder deletes document from collection', () async {
      when(() => mockDocument.delete()).thenAnswer((_) async {});

      await reminderRepository.deleteReminder('rem_123');

      verify(() => mockCollection.doc('rem_123')).called(1);
      verify(() => mockDocument.delete()).called(1);
    });
  });
}
