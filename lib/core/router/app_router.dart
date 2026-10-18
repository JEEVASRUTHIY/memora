import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memora/core/app_config.dart';
import 'package:memora/core/widgets/app_widgets.dart';
import 'package:memora/features/auth/data/auth_providers.dart';
import 'package:memora/features/auth/presentation/login_screen.dart';
import 'package:memora/features/auth/presentation/register_screen.dart';
import 'package:memora/features/auth/presentation/role_selection_screen.dart';
import 'package:memora/features/onboarding/presentation/linking_screen.dart';
import 'package:memora/features/patient_home/presentation/patient_home_screen.dart';
import 'package:memora/features/caregiver_home/presentation/caregiver_home_screen.dart';
import 'package:memora/features/caregiver_home/presentation/caregiver_profile_screen.dart';
import 'package:memora/features/care_circle/presentation/caregivers_screen.dart';
import 'package:memora/features/reminders/presentation/reminders_screen.dart';
import 'package:memora/features/dev_tools/presentation/dev_tools_screen.dart';
import 'package:memora/features/onboarding/presentation/patient_onboarding_screen.dart';
import 'app_routes.dart';
import 'route_guard.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(firebaseAuthStateProvider, (_, __) => refresh.update());
  ref.listen(currentUserProvider, (_, __) => refresh.update());
  ref.listen(patientProfileProvider, (_, __) => refresh.update());
  ref.listen(caregiverLinksProvider, (_, __) => refresh.update());
  final router = GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(firebaseAuthStateProvider);
      final profile = ref.read(currentUserProvider);
      final signedIn = auth.valueOrNull != null;
      final role = profile.valueOrNull?.role;
      final patientProfile = ref.read(patientProfileProvider);
      final redirect = routeRedirect(
        location: state.matchedLocation,
        loading: auth.isLoading || (signedIn && profile.isLoading) ||
          (role == 'patient' && patientProfile.isLoading),
        signedIn: signedIn,
        role: role,
        onboardingDone: profile.valueOrNull?.onboardingDone ?? false,
        patientProfileExists: patientProfile.valueOrNull != null,
        devToolsEnabled: AppConfig.devToolsEnabled,
      );
      if (redirect != null) {
        return redirect;
      }
      // Pending caregivers must stay on their waiting home, even on deep links.
      if (role == 'caregiver' && state.matchedLocation.startsWith('/caregiver/') &&
          state.matchedLocation != AppRoutes.caregiverHome) {
        final links = ref.read(caregiverLinksProvider).valueOrNull;
        if (links == null || !links.any((link) => link.isActive)) {
          return AppRoutes.caregiverHome;
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/session', builder: (_, __) => const _SessionScreen()),
      GoRoute(path: AppRoutes.welcome, builder: (_, __) => const RoleSelectionScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (_, state) {
        final role = state.uri.queryParameters['role'];
        if (role != 'patient' && role != 'caregiver') return const RoleSelectionScreen();
        return RegisterScreen(role: role!);
      }),
      GoRoute(path: AppRoutes.forgotPassword, builder: (_, __) =>
          const _FeatureShell(title: 'Forgot password', phase: 2)),
      GoRoute(path: AppRoutes.linkPatient, builder: (_, __) => const LinkingScreen()),
        GoRoute(path: AppRoutes.patientOnboarding,
          builder: (_, __) => const PatientOnboardingScreen()),
      GoRoute(path: AppRoutes.patientHome, builder: (_, __) => const PatientHomeScreen()),
      GoRoute(path: AppRoutes.patientProfile, builder: (_, __) =>
          const _FeatureShell(title: 'Profile', phase: 2)),
      ShellRoute(
        builder: (_, state, child) => _CaregiverShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: AppRoutes.caregiverHome, builder: (_, __) => const CaregiverHomeScreen()),
          GoRoute(path: AppRoutes.caregiverProfile, builder: (_, __) => const CaregiverProfileScreen()),
          GoRoute(path: AppRoutes.caregiverReminders, builder: (_, __) => const _CaregiverReminders()),
          GoRoute(path: AppRoutes.careCircle, builder: (_, __) => const CaregiversScreen()),
          GoRoute(path: AppRoutes.caregiverSafeZone, builder: (_, __) =>
              const _FeatureShell(title: 'Safe zone', phase: 3)),
        ],
      ),
      GoRoute(path: AppRoutes.alertsList, builder: (_, __) =>
          const _FeatureShell(title: 'Alerts', phase: 3)),
      GoRoute(path: AppRoutes.devTools, builder: (_, __) => const DevToolsScreen()),
    ],
    errorBuilder: (context, _) => Scaffold(body: EmptyState(
      icon: Icons.search_rounded, title: 'This page is not available',
      action: AppButton(label: 'Go home', onPressed: () => context.go(AppRoutes.welcome)),
    )),
  );
  ref.onDispose(router.dispose);
  ref.onDispose(refresh.dispose);
  return router;
});

class _RouterRefresh extends ChangeNotifier {
  void update() => notifyListeners();
}

class _SessionScreen extends ConsumerWidget {
  const _SessionScreen();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(firebaseAuthStateProvider);
    final user = ref.watch(currentUserProvider);
    if (!auth.isLoading && auth.valueOrNull == null) {
      return const LoginScreen();
    }
    if (auth.isLoading || user.isLoading) {
      return const Scaffold(body: LoadingView(message: 'Opening Memora…'));
    }
    return Scaffold(body: EmptyState(
      icon: Icons.person_outline_rounded,
      title: 'We could not open your profile',
      subtitle: 'Check your connection and try again.',
      action: Column(mainAxisSize: MainAxisSize.min, children: [
        AppButton(label: 'Try again', onPressed: () => ref.invalidate(currentUserProvider)),
        TextButton(
          onPressed: () async {
            await ref.read(authServiceProvider).logout();
            if (context.mounted) context.go(AppRoutes.login);
          },
          child: const Text('Log out'),
        ),
      ]),
    ));
  }
}

class _CaregiverReminders extends ConsumerWidget {
  const _CaregiverReminders();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(caregiverLinksProvider);
    return links.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (_, __) => Scaffold(body: ErrorView(message: 'We could not load your care circle.',
        onRetry: () => ref.invalidate(caregiverLinksProvider))),
      data: (items) {
        final active = items.where((link) => link.isActive);
        if (active.isEmpty) {
          return const Scaffold(body: EmptyState(
            icon: Icons.people_outline, title: 'Connect to a patient first'));
        }
        final link = active.first;
        return RemindersScreen(patientId: link.patientId, isPrimary: link.isPrimary);
      },
    );
  }
}

class _CaregiverShell extends ConsumerWidget {
  final String location;
  final Widget child;
  const _CaregiverShell({required this.location, required this.child});
  static const paths = [AppRoutes.caregiverHome, AppRoutes.caregiverReminders,
    AppRoutes.caregiverSafeZone, AppRoutes.careCircle];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(caregiverLinksProvider).valueOrNull?.any((l) => l.isActive) ?? false;
    return Scaffold(
      body: child,
      bottomNavigationBar: active ? NavigationBar(
        selectedIndex: paths.contains(location) ? paths.indexOf(location) : 0,
        onDestinationSelected: (index) => context.go(paths[index]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.alarm_rounded), label: 'Reminders'),
          NavigationDestination(icon: Icon(Icons.location_on_rounded), label: 'Safe zone'),
          NavigationDestination(icon: Icon(Icons.people_rounded), label: 'Care circle'),
        ],
      ) : null,
    );
  }
}

class _FeatureShell extends StatelessWidget {
  final String title;
  final int phase;
  const _FeatureShell({required this.title, required this.phase});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: EmptyState(icon: Icons.construction_rounded, title: '$title is being prepared',
      subtitle: 'Available in a later test build.'),
  );
}
