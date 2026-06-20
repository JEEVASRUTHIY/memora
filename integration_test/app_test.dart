import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:memora/theme/app_theme.dart';
import 'package:memora/providers/auth_provider.dart';
import 'package:memora/services/user_service.dart';
import 'package:memora/services/notification_service.dart';
import 'package:memora/models/user_model.dart';
import 'package:memora/screens/login_screen.dart';
import 'package:memora/screens/home_screen.dart';

// Mocks
class MockAuthProvider extends Mock implements AuthProvider {}
class MockUserService extends Mock implements UserService {}
class MockNotificationService extends Mock implements NotificationService {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthProvider mockAuthProvider;
  late MockUserService mockUserService;
  late MockNotificationService mockNotificationService;

  final caregiverUser = UserModel(
    userId: 'caregiver123',
    role: 'Caregiver',
    name: 'Jane Doe',
    contactDetails: 'jane@example.com',
  );

  final patientUser = UserModel(
    userId: 'patient123',
    role: 'Patient',
    name: 'John Doe',
    contactDetails: 'john@example.com',
  );

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockUserService = MockUserService();
    mockNotificationService = MockNotificationService();

    // Default mock setups
    when(() => mockAuthProvider.isLoading).thenReturn(false);
    when(() => mockAuthProvider.errorMessage).thenReturn(null);
    when(() => mockAuthProvider.firebaseUser).thenReturn(null);
    when(() => mockAuthProvider.userModel).thenReturn(null);
    
    // Clear error fallback
    when(() => mockAuthProvider.clearError()).thenAnswer((_) {});
  });

  Widget buildTestWidget({required Widget child}) {
    return MultiProvider(
      providers: [
        Provider<UserService>.value(value: mockUserService),
        Provider<NotificationService>.value(value: mockNotificationService),
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: child,
      ),
    );
  }

  group('Memora App Integration Tests', () {
    testWidgets('Full User Journey: Login, Navigation, and Role Registration', (WidgetTester tester) async {
      // 1. Initial State: Unauthenticated user launched into LoginScreen
      await tester.pumpWidget(buildTestWidget(child: const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Memora'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);

      // Verify email and password text fields exist
      expect(find.byType(TextFormField), findsNWidgets(2));

      // 2. Click on "Sign Up" to navigate to Role Selection
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // Verify we are on Role Selection Screen
      expect(find.text('Welcome to Memora'), findsOneWidget);
      expect(find.text('I am a Patient'), findsOneWidget);
      expect(find.text('I am a Caregiver'), findsOneWidget);

      // Continue button should be disabled initially (since no role selected)
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);

      // Select "Caregiver" role
      await tester.tap(find.text('I am a Caregiver'));
      await tester.pumpAndSettle();

      // Continue button should now be enabled
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNotNull);

      // 3. Click "Continue" to navigate to Registration Screen
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Verify Registration Screen for Caregiver
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Registering as a Caregiver'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(4)); // Name, Email, Password, Contact Details

      // 4. Fill registration form
      await tester.enterText(find.byType(TextFormField).at(0), 'Jane Doe');
      await tester.enterText(find.byType(TextFormField).at(1), 'jane@example.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.enterText(find.byType(TextFormField).at(3), '1234567890');
      await tester.pumpAndSettle();

      // Mock register function call
      when(() => mockAuthProvider.register(
            email: 'jane@example.com',
            password: 'password123',
            name: 'Jane Doe',
            role: 'Caregiver',
            contactDetails: '1234567890',
          )).thenAnswer((_) async => true);

      // Tap Register
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      // Verify that register was invoked
      verify(() => mockAuthProvider.register(
            email: 'jane@example.com',
            password: 'password123',
            name: 'Jane Doe',
            role: 'Caregiver',
            contactDetails: '1234567890',
          )).called(1);
    });

    testWidgets('Home Screen Flow: Caregiver Links Patient successfully', (WidgetTester tester) async {
      // Setup mock auth provider state to represent logged in Caregiver
      when(() => mockAuthProvider.firebaseUser).thenReturn(mock<User>());
      when(() => mockAuthProvider.userModel).thenReturn(caregiverUser);
      
      // Mock UserService watchUserProfile for caregiver and patient profile streams
      when(() => mockUserService.watchUserProfile('caregiver123'))
          .thenAnswer((_) => Stream.value(caregiverUser));
      when(() => mockUserService.watchUserProfile('patient123'))
          .thenAnswer((_) => Stream.value(patientUser));
      when(() => mockAuthProvider.linkPatient('patient123'))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(buildTestWidget(child: const HomeScreen()));
      await tester.pumpAndSettle();

      // Verify Caregiver dashboard details
      expect(find.text('Welcome back,'), findsOneWidget);
      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('Caregiver'), findsOneWidget);
      expect(find.text('Connect to a Patient'), findsOneWidget);

      // Enter Patient ID in text field
      await tester.enterText(find.byType(TextFormField), 'patient123');
      await tester.pumpAndSettle();

      // Click "Link Patient Account" button
      await tester.tap(find.text('Link Patient Account'));
      await tester.pumpAndSettle();

      // Verify linkPatient was invoked in AuthProvider
      verify(() => mockAuthProvider.linkPatient('patient123')).called(1);
    });
  });
}

// Helper utility to mock classes dynamically
T mock<T extends Object>() => _MockHelper<T>();
class _MockHelper<T extends Object> extends Mock implements T {}
