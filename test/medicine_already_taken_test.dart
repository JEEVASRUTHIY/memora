import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_theme.dart';
import 'package:memora/features/medicine/presentation/medicine_already_taken_screen.dart';

void main() {
  group('MedicineAlreadyTakenScreen Widget Tests', () {
    testWidgets('renders all screen elements accurately according to design mockup',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.patientTheme,
            home: const MedicineAlreadyTakenScreen(
              doseTitle: 'Morning dose',
              doseTime: '9:00 AM',
              nextDoseTime: '2:00 PM',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Top app bar checks
      expect(find.text('My Medicine'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Card 1: Taken medicine confirmation
      expect(find.text("You've taken your\nmedicine!"), findsOneWidget);
      expect(find.text('Morning dose · 9:00 AM'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsAtLeastNWidgets(1));

      // Card 2: Next dose
      expect(find.text('Next dose: 2:00 PM'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsAtLeastNWidgets(1));

      // Card 3: Timeline (Adapted from reference sketch)
      expect(find.text("Today's Medicine Timeline"), findsOneWidget);
      expect(find.text('Taken 9:00 AM'), findsOneWidget);
      expect(find.text('Morning dose · Successfully completed'), findsOneWidget);
      expect(find.text('Now....'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('You are all set · Resting between doses'), findsOneWidget);
      expect(find.text('2:00 PM'), findsOneWidget);
      expect(find.text('Next Dose'), findsOneWidget);
      expect(find.text('Scheduled · Memora will remind you'), findsOneWidget);

      // Section 4: Reassurance / Caregiver inquiry
      expect(find.text('Not sure if you took it?'), findsOneWidget);
      expect(find.text('Your caregiver can help you check.'), findsOneWidget);

      // Section 5: Action cards
      expect(find.text('Call Caregiver'), findsOneWidget);
      expect(find.text('Talk directly'), findsOneWidget);
      expect(find.byIcon(Icons.phone_outlined), findsOneWidget);

      expect(find.text('Ask Caregiver'), findsOneWidget);
      expect(find.text('Send an instant\nmessage'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);

      // Bottom arrow indicator
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });

    testWidgets('renders timeline with 9:00 PM next dose when provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.patientTheme,
            home: const MedicineAlreadyTakenScreen(
              doseTitle: 'Morning dose',
              doseTime: '9:00 am',
              nextDoseTime: '9:00 pm',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Today's Medicine Timeline"), findsOneWidget);
      expect(find.text('Taken 9:00 am'), findsOneWidget);
      expect(find.text('Now....'), findsOneWidget);
      expect(find.text('9:00 pm'), findsOneWidget);
    });

    testWidgets('tapping read aloud speaker button triggers speak without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.patientTheme,
            home: const MedicineAlreadyTakenScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final speakerBtn = find.byTooltip('Read aloud');
      expect(speakerBtn, findsOneWidget);
      await tester.tap(speakerBtn);
      await tester.pump();
      // Should complete gracefully without exceptions
    });
  });
}
