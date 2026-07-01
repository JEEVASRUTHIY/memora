import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'repositories/user_repository.dart';
import 'services/user_service.dart';
import 'services/notification_service.dart';
import 'providers/auth_provider.dart';
import 'repositories/reminder_repository.dart';
import 'services/reminder_service.dart';
import 'providers/reminder_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'repositories/safe_zone_repository.dart';
import 'services/safe_zone_service.dart';
import 'services/background_location_service.dart';
import 'providers/safe_zone_provider.dart';

const bool useEmulator = false; // Set to true to use local Firebase Emulators in debug mode

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyD9icq-KItmRMBHvGr_udUN_qLPZhGhqeI",
          authDomain: "memora-3b359.firebaseapp.com",
          projectId: "memora-3b359",
          storageBucket: "memora-3b359.firebasestorage.app",
          messagingSenderId: "365872702190",
          appId: "1:365872702190:web:70d7ad4b0eaa17457109ff",
          measurementId: "G-2L0FT4897G",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
    
    if (useEmulator && kDebugMode) {
      final host = defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
      FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      debugPrint("Connecting to Firebase Emulators at $host...");
    }
  } catch (e) {
    debugPrint("Firebase Core initialization warning: $e");
    // Fallback: in debug/emulator mode on other platforms, try initializing with mock options if emulator is enabled
    if (useEmulator && kDebugMode) {
      try {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: "mock-api-key-12345",
            appId: "mock-app-id-12345",
            messagingSenderId: "mock-sender-id",
            projectId: "memora-3b359",
          ),
        );
        final host = defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
        FirebaseAuth.instance.useAuthEmulator(host, 9099);
        FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
        debugPrint("Connecting to Firebase Emulators with mock options at $host...");
      } catch (innerError) {
        debugPrint("Fallback Firebase initialization failed: $innerError");
      }
    }
  }

  // Set up service/repository layer instances
  final userRepository = UserRepository();
  final notificationService = NotificationService();
  final reminderRepository = ReminderRepository();
  final safeZoneRepository = SafeZoneRepository();
  
  // Initialize Notification Services
  await notificationService.initialize();

  // Initialize Background Location Service
  await BackgroundLocationService.initialize();

  // Create UserService pointing to our repository
  final userService = UserService(
    userRepository: userRepository,
  );

  final reminderService = ReminderService(
    reminderRepository: reminderRepository,
  );

  final String safeZoneBaseUrl = useEmulator && kDebugMode
      ? (defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:5001/memora-3b359/us-central1/users'
          : 'http://localhost:5001/memora-3b359/us-central1/users')
      : 'https://us-central1-memora-app.cloudfunctions.net/users';

  final safeZoneService = SafeZoneService(
    baseUrl: safeZoneBaseUrl,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<UserRepository>.value(value: userRepository),
        Provider<NotificationService>.value(value: notificationService),
        Provider<UserService>.value(value: userService),
        Provider<ReminderRepository>.value(value: reminderRepository),
        Provider<ReminderService>.value(value: reminderService),
        Provider<SafeZoneRepository>.value(value: safeZoneRepository),
        Provider<SafeZoneService>.value(value: safeZoneService),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            userService: userService,
            notificationService: notificationService,
          ),
        ),
        ChangeNotifierProvider<ReminderProvider>(
          create: (context) => ReminderProvider(
            reminderService: reminderService,
            notificationService: notificationService,
          ),
        ),
        ChangeNotifierProvider<SafeZoneProvider>(
          create: (context) => SafeZoneProvider(
            safeZoneRepository: safeZoneRepository,
            safeZoneService: safeZoneService,
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
      return Scaffold(
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
