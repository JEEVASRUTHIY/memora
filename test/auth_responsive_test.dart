import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/router/app_routes.dart';
import 'package:memora/features/auth/data/auth_providers.dart';
import 'package:memora/features/auth/presentation/login_screen.dart';
import 'package:memora/features/auth/presentation/register_screen.dart';
import 'package:memora/features/auth/presentation/role_selection_screen.dart';

Widget testHost(Widget child, {double textScale = 1}) {
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith((ref) => AuthNotifier.test()),
    ],
    child: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(home: child),
    ),
  );
}

Future<void> pumpAtWidth(WidgetTester tester, Widget child, double scale) async {
  await tester.pumpWidget(SizedBox(width: 320, child: testHost(child, textScale: scale)));
  await tester.pump();
}

void main() {
  testWidgets('login, welcome, and sign up fit at narrow widths', (tester) async {
    for (final scale in [1.0, 1.5]) {
      await pumpAtWidth(tester, const LoginScreen(), scale);
      expect(tester.takeException(), isNull);
      await pumpAtWidth(tester, const RoleSelectionScreen(), scale);
      expect(tester.takeException(), isNull);
      await pumpAtWidth(tester, const RegisterScreen(role: 'patient'), scale);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Create new account opens role selection', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.login,
      routes: [
        GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
        GoRoute(path: AppRoutes.welcome, builder: (_, __) => const RoleSelectionScreen()),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [authNotifierProvider.overrideWith((ref) => AuthNotifier.test())],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create new account'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Memora'), findsOneWidget);
    router.dispose();
  });
}