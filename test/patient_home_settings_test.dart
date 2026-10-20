import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_theme.dart';
import 'package:memora/data/models/user_model.dart';
import 'package:memora/features/auth/data/auth_providers.dart';
import 'package:memora/features/reminders/data/reminder_providers.dart';
import 'package:memora/features/emergency_contacts/data/contact_providers.dart';
import 'package:memora/features/patient_home/presentation/patient_home_screen.dart';

void main() {
  group('PatientHomeScreen Settings & Patient ID Tests', () {
    final mockPatientUser = UserModel(
      uid: 'user_123',
      email: 'john.doe@example.com',
      name: 'John Doe',
      role: 'patient',
      patientId: 'PT9876',
      createdAt: DateTime(2026, 1, 1),
    );

    testWidgets(
        'shows patient ID badge in top header and removes patient ID card from middle',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => Stream.value(mockPatientUser)),
            patientLinksProvider.overrideWith((ref) => Stream.value([])),
            remindersProvider('PT9876').overrideWith((ref) => Stream.value([])),
            actionableOccurrencesProvider('PT9876')
                .overrideWith((ref) => Stream.value([])),
            patientContactsProvider('PT9876')
                .overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: AppTheme.patientTheme,
            home: const PatientHomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Top header checks
      expect(find.text('Hello, John!'), findsOneWidget);
      expect(find.text('Patient Account'), findsOneWidget);
      expect(find.text('ID: PT9876'), findsOneWidget);

      // Verify that "Your Patient ID" card is NOT in the middle of the homescreen initially
      expect(find.text('Your Patient ID'), findsNothing);
      // Verify reminders, caregivers card, and version number are removed from the home screen
      expect(find.text('All caught up! No reminders right now.'), findsNothing);
      expect(find.text('Your Caregivers'), findsNothing);
      expect(find.text('Memora 1.0.0'), findsNothing);

      // Tap the settings icon in the top header
      final settingsBtn = find.byTooltip('Settings');
      expect(settingsBtn, findsOneWidget);
      await tester.tap(settingsBtn);
      await tester.pumpAndSettle();

      // Verify Settings modal sheet opened
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Your Patient ID'), findsOneWidget);
      expect(find.text('PT9876'), findsOneWidget);
      expect(find.text('Copy ID'), findsOneWidget);
      expect(find.text('Voice & Read Aloud'), findsOneWidget);
      expect(find.text('Read aloud every time'), findsOneWidget);
      expect(find.text('Read aloud when speaker button is pressed'),
          findsOneWidget);
      expect(find.text('My Caregivers & Relatives'), findsOneWidget);
      expect(find.text('Add Caregiver / Relative / Parent'), findsOneWidget);
      expect(find.text('Safe Locations (Where Am I?)'), findsOneWidget);
      expect(find.textContaining('123 Maple Avenue'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);

      // Tap Add Caregiver button to open dialog
      final addCaregiverBtn = find.text('Add Caregiver / Relative / Parent');
      await tester.ensureVisible(addCaregiverBtn);
      await tester.pumpAndSettle();
      await tester.tap(addCaregiverBtn);
      await tester.pumpAndSettle();

      expect(find.text('Add Caregiver / Family'), findsOneWidget);
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Memora ID'), findsOneWidget);
      expect(find.text('Send Request'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'front screen displays live date, time, and read aloud speaker button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider
                .overrideWith((ref) => Stream.value(mockPatientUser)),
            patientLinksProvider.overrideWith((ref) => Stream.value([])),
            remindersProvider('PT9876').overrideWith((ref) => Stream.value([])),
            actionableOccurrencesProvider('PT9876')
                .overrideWith((ref) => Stream.value([])),
            patientContactsProvider('PT9876')
                .overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: AppTheme.patientTheme,
            home: const PatientHomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Front screen should display speaker button with tooltip 'Read Date and Time Aloud'
      final readAloudBtn = find.byTooltip('Read Date and Time Aloud');
      expect(readAloudBtn, findsOneWidget);
      await tester.tap(readAloudBtn);
      await tester.pump();
    });

    testWidgets('tapping patient ID badge in header opens Settings sheet',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider
                .overrideWith((ref) => Stream.value(mockPatientUser)),
            patientLinksProvider.overrideWith((ref) => Stream.value([])),
            remindersProvider('PT9876').overrideWith((ref) => Stream.value([])),
            actionableOccurrencesProvider('PT9876')
                .overrideWith((ref) => Stream.value([])),
            patientContactsProvider('PT9876')
                .overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: AppTheme.patientTheme,
            home: const PatientHomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final idBadge = find.text('ID: PT9876');
      expect(idBadge, findsOneWidget);
      await tester.tap(idBadge);
      await tester.pumpAndSettle();

      // Settings sheet should be open
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Your Patient ID'), findsOneWidget);
      expect(find.text('Safe Locations (Where Am I?)'), findsOneWidget);
    });

    testWidgets(
        'renders 4 homescreen cards: My medicine, Hydration, SOS, and Text caregiver',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider
                .overrideWith((ref) => Stream.value(mockPatientUser)),
            patientLinksProvider.overrideWith((ref) => Stream.value([])),
            remindersProvider('PT9876').overrideWith((ref) => Stream.value([])),
            actionableOccurrencesProvider('PT9876')
                .overrideWith((ref) => Stream.value([])),
            patientContactsProvider('PT9876')
                .overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: AppTheme.patientTheme,
            home: const PatientHomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check all 4 cards exist
      expect(find.text('My medicine'), findsOneWidget);
      expect(find.text('Reminders'), findsOneWidget);
      expect(find.text('SOS'), findsOneWidget);
      expect(find.text('Text caregiver'), findsOneWidget);

      // Tap Reminders card
      await tester.ensureVisible(find.text('Reminders'));
      await tester.tap(find.text('Reminders'));
      await tester.pumpAndSettle();
      expect(find.text('Prescriptions & Refills'), findsOneWidget);
      final backBtn = find.byIcon(Icons.arrow_back_ios_new_rounded);
      if (backBtn.evaluate().isNotEmpty) {
        await tester.tap(backBtn.first);
        await tester.pumpAndSettle();
      }

      // Tap SOS card
      await tester.ensureVisible(find.text('SOS'));
      await tester.tap(find.text('SOS'));
      await tester.pumpAndSettle();
      expect(find.text('Emergency SOS'), findsOneWidget);
      expect(find.text('Call 911 (Emergency Services)'), findsOneWidget);
      await tester.tap(find.text('Cancel / I am Safe'));
      await tester.pumpAndSettle();

      // Tap Text caregiver card
      await tester.ensureVisible(find.text('Text caregiver'));
      await tester.tap(find.text('Text caregiver'));
      await tester.pumpAndSettle();
      expect(find.text('Text Caregiver'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });
}
