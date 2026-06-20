import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:memora/providers/auth_provider.dart';
import 'package:memora/services/user_service.dart';
import 'package:memora/services/notification_service.dart';
import 'package:memora/models/user_model.dart';

// Mocks
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUserCredential extends Mock implements UserCredential {}
class MockUser extends Mock implements User {}
class MockUserService extends Mock implements UserService {}
class MockNotificationService extends Mock implements NotificationService {}

void main() {
  late MockFirebaseAuth mockAuth;
  late MockUserCredential mockUserCredential;
  late MockUser mockUser;
  late MockUserService mockUserService;
  late MockNotificationService mockNotificationService;
  late AuthProvider authProvider;

  final testUserModel = UserModel(
    userId: 'user123',
    role: 'Patient',
    name: 'John Doe',
    contactDetails: 'john@example.com',
  );

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockUserCredential = MockUserCredential();
    mockUser = MockUser();
    mockUserService = MockUserService();
    mockNotificationService = MockNotificationService();

    // Setup standard mock behavior
    when(() => mockAuth.authStateChanges()).thenAnswer((_) => Stream.value(null));
    when(() => mockNotificationService.getToken()).thenAnswer((_) async => 'fcm-token-123');
    when(() => mockUserService.updateFcmToken(any(), any())).thenAnswer((_) async {});

    authProvider = AuthProvider(
      auth: mockAuth,
      userService: mockUserService,
      notificationService: mockNotificationService,
    );
  });

  group('AuthProvider Tests', () {
    test('login successfully logs in user', () async {
      when(() => mockAuth.signInWithEmailAndPassword(
            email: 'john@example.com',
            password: 'password123',
          )).thenAnswer((_) async => mockUserCredential);

      final result = await authProvider.login('john@example.com', 'password123');

      expect(result, isTrue);
      expect(authProvider.isLoading, isFalse);
      expect(authProvider.errorMessage, isNull);
    });

    test('login with error sets error message', () async {
      when(() => mockAuth.signInWithEmailAndPassword(
            email: 'john@example.com',
            password: 'password123',
          )).thenThrow(FirebaseAuthException(
        code: 'user-not-found',
        message: 'No user found for that email.',
      ));

      final result = await authProvider.login('john@example.com', 'password123');

      expect(result, isFalse);
      expect(authProvider.isLoading, isFalse);
      expect(authProvider.errorMessage, equals('No user found for that email.'));
    });

    test('register successfully registers patient profile', () async {
      when(() => mockAuth.createUserWithEmailAndPassword(
            email: 'john@example.com',
            password: 'password123',
          )).thenAnswer((_) async => mockUserCredential);
      when(() => mockUserCredential.user).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('user123');
      when(() => mockUserService.registerUser(
            userId: 'user123',
            role: 'Patient',
            name: 'John Doe',
            contactDetails: 'john@example.com',
          )).thenAnswer((_) async => testUserModel);

      final result = await authProvider.register(
        email: 'john@example.com',
        password: 'password123',
        name: 'John Doe',
        role: 'Patient',
        contactDetails: 'john@example.com',
      );

      expect(result, isTrue);
      expect(authProvider.isLoading, isFalse);
      expect(authProvider.errorMessage, isNull);
    });

    test('register failure rolls back (deletes) firebase user', () async {
      when(() => mockAuth.createUserWithEmailAndPassword(
            email: 'john@example.com',
            password: 'password123',
          )).thenAnswer((_) async => mockUserCredential);
      when(() => mockUserCredential.user).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('user123');
      when(() => mockUser.delete()).thenAnswer((_) async {});
      when(() => mockUserService.registerUser(
            userId: 'user123',
            role: 'Patient',
            name: 'John Doe',
            contactDetails: 'john@example.com',
          )).thenThrow(Exception('Firestore write failed'));

      final result = await authProvider.register(
        email: 'john@example.com',
        password: 'password123',
        name: 'John Doe',
        role: 'Patient',
        contactDetails: 'john@example.com',
      );

      expect(result, isFalse);
      expect(authProvider.isLoading, isFalse);
      expect(authProvider.errorMessage, equals('Firestore write failed'));
      verify(() => mockUser.delete()).called(1);
    });

    test('linkPatient successfully links caregiver to patient', () async {
      // Mock the current user as a Caregiver
      final caregiverUser = UserModel(
        userId: 'caregiver123',
        role: 'Caregiver',
        name: 'Jane Doe',
        contactDetails: 'jane@example.com',
      );

      // Let's create an AuthProvider with a mocked user state directly to test linking
      // Since _subscribeToUserProfile is called when auth changes, we can mock authStateChanges returning mockUser
      when(() => mockAuth.authStateChanges()).thenAnswer((_) => Stream.value(mockUser));
      when(() => mockUser.uid).thenReturn('caregiver123');
      when(() => mockUserService.watchUserProfile('caregiver123'))
          .thenAnswer((_) => Stream.value(caregiverUser));
      
      // Re-init provider
      final provider = AuthProvider(
        auth: mockAuth,
        userService: mockUserService,
        notificationService: mockNotificationService,
      );

      // Wait briefly for stream subscription to trigger
      await Future.delayed(Duration.zero);

      expect(provider.userModel, isNotNull);
      expect(provider.userModel!.role, equals('Caregiver'));

      // Mock link success
      when(() => mockUserService.linkPatient(
            caregiverId: 'caregiver123',
            patientId: 'patient123',
          )).thenAnswer((_) async {});

      final linkResult = await provider.linkPatient('patient123');
      expect(linkResult, isTrue);
      expect(provider.errorMessage, isNull);
    });

    test('linkPatient fails when user is not a caregiver', () async {
      // Current user is a Patient, not Caregiver
      when(() => mockAuth.authStateChanges()).thenAnswer((_) => Stream.value(mockUser));
      when(() => mockUser.uid).thenReturn('user123');
      when(() => mockUserService.watchUserProfile('user123'))
          .thenAnswer((_) => Stream.value(testUserModel));

      final provider = AuthProvider(
        auth: mockAuth,
        userService: mockUserService,
        notificationService: mockNotificationService,
      );

      await Future.delayed(Duration.zero);

      final linkResult = await provider.linkPatient('patient123');
      expect(linkResult, isFalse);
      expect(provider.errorMessage, equals('Only caregivers can link patients.'));
    });
  });
}
