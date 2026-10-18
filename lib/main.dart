import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:memora/core/theme/app_theme.dart';
import 'package:memora/core/app_config.dart';
import 'package:memora/core/router/app_router.dart';
import 'package:memora/features/auth/data/auth_providers.dart';
import 'package:memora/core/constants/app_constants.dart';
import 'package:memora/data/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.loadPlatformConfig();
  await Firebase.initializeApp();
  await NotificationService().init();
  runApp(const ProviderScope(child: MemoraApp()));
}

class MemoraApp extends ConsumerWidget {
  const MemoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Pick theme based on logged-in user's role
    final userAsync = ref.watch(currentUserProvider);
    final isPatient = userAsync.valueOrNull?.role == AppConstants.rolePatient;

    return MaterialApp.router(
      title: 'Memora',
      debugShowCheckedModeBanner: false,
      theme: isPatient ? AppTheme.patientTheme : AppTheme.caregiverTheme,
      routerConfig: router,
    );
  }
}
