import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:memora/services/user_service.dart';
import 'package:memora/repositories/user_repository.dart';
import 'package:memora/models/user_model.dart';

// Mocks
class MockUserRepository extends Mock implements UserRepository {}
class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockUserRepository mockRepository;
  late MockHttpClient mockHttpClient;
  late UserService userService;

  final testUser = UserModel(
    userId: 'user123',
    role: 'Patient',
    name: 'John Doe',
    contactDetails: 'john@example.com',
  );

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    mockRepository = MockUserRepository();
    mockHttpClient = MockHttpClient();
    userService = UserService(
      userRepository: mockRepository,
      client: mockHttpClient,
      baseUrl: 'https://test-api.com',
    );
  });

  group('UserService Tests', () {
    test('registerUser returns UserModel on HTTP 201', () async {
      final mockResponseJson = {
        'message': 'User registered successfully',
        'user': testUser.toJson()
      };

      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(jsonEncode(mockResponseJson), 201));

      final result = await userService.registerUser(
        userId: 'user123',
        role: 'Patient',
        name: 'John Doe',
        contactDetails: 'john@example.com',
      );

      expect(result.userId, equals('user123'));
      expect(result.role, equals('Patient'));
      expect(result.name, equals('John Doe'));

      verify(() => mockHttpClient.post(
            Uri.parse('https://test-api.com/register'),
            headers: {'Content-Type': 'application/json'},
            body: any(named: 'body'),
          )).called(1);
    });

    test('registerUser throws Exception on HTTP error code', () async {
      final mockErrorResponse = {'error': 'User already exists'};

      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(jsonEncode(mockErrorResponse), 400));

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

    test('linkPatient completes successfully on HTTP 200', () async {
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(jsonEncode({'message': 'Success'}), 200));

      await expectLater(
        userService.linkPatient(caregiverId: 'caregiver1', patientId: 'patient1'),
        completes,
      );

      verify(() => mockHttpClient.post(
            Uri.parse('https://test-api.com/link-patient'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'caregiverId': 'caregiver1', 'patientId': 'patient1'}),
          )).called(1);
    });

    test('linkPatient throws Exception on non-200 code', () async {
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(jsonEncode({'error': 'Failed to link'}), 500));

      expect(
        () => userService.linkPatient(caregiverId: 'caregiver1', patientId: 'patient1'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
