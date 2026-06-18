import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'repositories/user_repository.dart';
import 'services/user_service.dart';
import 'services/notification_service.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Note: Flutter fire init is typically run dynamically or configured in a Firebase options file.
  // We will initialize standard Firebase. If testing locally or building without Firebase configurations,
  // we catch initialization error.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase Core initialization warning: $e");
    debugPrint("Ensure you have added google-services.json (Android) and GoogleService-Info.plist (iOS).");
  }

  // Set up service/repository layer instances
  final userRepository = UserRepository();
  final notificationService = NotificationService();
  
  // Initialize Notification Services
  await notificationService.initialize();

  // Create UserService pointing to our deployed Firebase Cloud Functions
  // (In emulator mode, you can override the baseUrl to http://10.0.2.2:5001/YOUR-PROJECT/us-central1/users)
  final userService = UserService(
    userRepository: userRepository,
    baseUrl: 'https://us-central1-memora-app.cloudfunctions.net/users', 
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<UserRepository>.value(value: userRepository),
        Provider<NotificationService>.value(value: notificationService),
        Provider<UserService>.value(value: userService),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            userService: userService,
            notificationService: notificationService,
          ),
        ),
      ],
      child: const MemoraApp(),
    ),
  );
}

class MemoraApp extends StatelessWidget {
  const MemoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memora',
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Dynamic auth state routing
    if (authProvider.firebaseUser == null) {
      return const LoginScreen();
    }

    if (authProvider.userModel == null) {
      return const Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.bgGradient,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
                SizedBox(height: 16),
                Text(
                  'Loading your profile...',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const HomeScreen();
  }
}
