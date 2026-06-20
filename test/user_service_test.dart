import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memora/services/user_service.dart';
import 'package:memora/repositories/user_repository.dart';
import 'package:memora/models/user_model.dart';

// Mocks
class MockUserRepository extends Mock implements UserRepository {}

void main() {
  late MockUserRepository mockRepository;
  late UserService userService;

  final testUser = UserModel(
    userId: 'user123',
    role: 'Patient',
    name: 'John Doe',
    contactDetails: 'john@example.com',
  );

  setUpAll(() {
    registerFallbackValue(UserModel(
      userId: '',
      role: '',
      name: '',
      contactDetails: '',
    ));
  });

  setUp(() {
    mockRepository = MockUserRepository();
    userService = UserService(
      userRepository: mockRepository,
    );
  });

  group('UserService Tests', () {
    test('registerUser saves user profile directly in repository', () async {
      when(() => mockRepository.saveUser(any())).thenAnswer((_) async {});

      final result = await userService.registerUser(
        userId: 'user123',
        role: 'Patient',
        name: 'John Doe',
        contactDetails: 'john@example.com',
      );

      expect(result.userId, equals('user123'));
      expect(result.role, equals('Patient'));
      expect(result.name, equals('John Doe'));

      verify(() => mockRepository.saveUser(any())).called(1);
    });

    test('registerUser throws Exception when repository save fails', () async {
      when(() => mockRepository.saveUser(any())).thenThrow(Exception('Firestore error'));

      expect(
        () => userService.registerUser(
          userId: 'user123',
          role: 'Patient',
          name: 'John Doe',
          contactDetails: 'john@example.com',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('linkPatient completes successfully when repository linking succeeds', () async {
      when(() => mockRepository.linkPatient(
            caregiverId: any(named: 'caregiverId'),
            patientId: any(named: 'patientId'),
          )).thenAnswer((_) async {});

      await expectLater(
        userService.linkPatient(caregiverId: 'caregiver1', patientId: 'patient1'),
        completes,
      );

      verify(() => mockRepository.linkPatient(
            caregiverId: 'caregiver1',
            patientId: 'patient1',
          )).called(1);
    });

    test('linkPatient throws Exception when repository linking fails', () async {
      when(() => mockRepository.linkPatient(
            caregiverId: any(named: 'caregiverId'),
            patientId: any(named: 'patientId'),
          )).thenThrow(Exception('Firestore linking error'));

      expect(
        () => userService.linkPatient(caregiverId: 'caregiver1', patientId: 'patient1'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
