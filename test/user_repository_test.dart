import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:memora/repositories/user_repository.dart';
import 'package:memora/models/user_model.dart';

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
  late UserRepository userRepository;

  final testUser = UserModel(
    userId: 'user123',
    role: 'Patient',
    name: 'John Doe',
    contactDetails: 'john@example.com',
  );

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockDocument = MockDocumentReference();
    mockSnapshot = MockDocumentSnapshot();
    userRepository = UserRepository(firestore: mockFirestore);

    // Mock collection call
    when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
    // Mock document call
    when(() => mockCollection.doc(any())).thenReturn(mockDocument);
  });

  group('UserRepository Tests', () {
    test('getUser returns UserModel when document exists', () async {
      when(() => mockDocument.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.exists).thenReturn(true);
      when(() => mockSnapshot.data()).thenReturn(testUser.toJson());

      final result = await userRepository.getUser('user123');

      expect(result, isNotNull);
      expect(result!.userId, equals('user123'));
      expect(result.name, equals('John Doe'));
      expect(result.role, equals('Patient'));
      verify(() => mockFirestore.collection('users')).called(1);
      verify(() => mockCollection.doc('user123')).called(1);
    });

    test('getUser returns null when document does not exist', () async {
      when(() => mockDocument.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.exists).thenReturn(false);

      final result = await userRepository.getUser('user123');

      expect(result, isNull);
    });

    test('saveUser executes set on firestore document', () async {
      when(() => mockDocument.set(any(), any())).thenAnswer((_) async {});

      await userRepository.saveUser(testUser);

      verify(() => mockDocument.set(
            any(that: equals(testUser.toJson())),
            any(that: isA<SetOptions>()),
          )).called(1);
    });
  });
}
