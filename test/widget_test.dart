import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memora/screens/login_screen.dart';
import 'package:memora/providers/auth_provider.dart';
import 'package:memora/services/user_service.dart';
import 'package:memora/services/notification_service.dart';

class MockAuthProvider extends Mock implements AuthProvider {}
class MockUserService extends Mock implements UserService {}
class MockNotificationService extends Mock implements NotificationService {}

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockUserService mockUserService;
  late MockNotificationService mockNotificationService;

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockUserService = MockUserService();
    mockNotificationService = MockNotificationService();

    // Mock loading state
    when(() => mockAuthProvider.isLoading).thenReturn(false);
    when(() => mockAuthProvider.errorMessage).thenReturn(null);
    when(() => mockAuthProvider.firebaseUser).thenReturn(null);
  });

  testWidgets('LoginScreen renders logo, title and textfields', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<UserService>.value(value: mockUserService),
          Provider<NotificationService>.value(value: mockNotificationService),
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Verify presence of title
    expect(find.text('Memora'), findsOneWidget);
    // Verify email and password text fields
    expect(find.byType(TextFormField), findsNWidgets(2));
    // Verify button
    expect(find.text('Log In'), findsOneWidget);
    // Verify Sign Up redirection
    expect(find.text('Sign Up'), findsOneWidget);
  });
}
