import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_theme.dart';
import 'package:memora/data/models/medicine_refill_model.dart';
import 'package:memora/data/models/reminder_models.dart';
import 'package:memora/data/models/user_model.dart';
import 'package:memora/features/auth/data/auth_providers.dart';
import 'package:memora/features/emergency_contacts/data/contact_providers.dart';
import 'package:memora/features/patient_home/presentation/patient_home_screen.dart';
import 'package:memora/features/patient_home/presentation/widgets/dashboard_notification_carousel.dart';
import 'package:memora/features/reminders/data/refill_providers.dart';
import 'package:memora/features/reminders/data/reminder_providers.dart';
import 'package:memora/features/reminders/presentation/patient_refills_screen.dart';
import 'package:memora/data/repositories/refill_repository.dart';

class MockRefillRepository implements RefillRepository {
  final List<String> askedCaregiverIds = [];
  final List<String> boughtRefillIds = [];

  @override
  String newRefillId(String patientId) => 'refill_new_123';

  @override
  Stream<List<MedicineRefillModel>> watchRefills(String patientId) =>
      Stream.value([]);

  @override
  Future<void> createRefill(String patientId, MedicineRefillModel refill) async {}

  @override
  Future<void> updateRefill(String patientId, MedicineRefillModel refill) async {}

  @override
  Future<void> deleteRefill(String patientId, String refillId) async {}

  @override
  Future<void> markOrdered(String patientId, String refillId) async {}

  @override
  Future<void> askCaregiverToBuy(String patientId, String refillId) async {
    askedCaregiverIds.add(refillId);
  }

  @override
  Future<void> markBought(String patientId, MedicineRefillModel refill,
      {int? replenishedTablets}) async {
    boughtRefillIds.add(refill.id);
  }

  @override
  Future<void> markRefilled(String patientId, MedicineRefillModel refill,
      {int? replenishedTablets}) async {
    boughtRefillIds.add(refill.id);
  }

  @override
  Future<void> togglePause(
      String patientId, String refillId, bool isCurrentlyPaused) async {}
}

void main() {
  group('MedicineRefillModel Unit Tests', () {
    test('computes daysUntilDue and isDueSoon correctly', () {
      final now = DateTime.now();
      final dueIn3Days = now.add(const Duration(days: 3));

      final refill = MedicineRefillModel(
        id: 'refill_1',
        patientId: 'PT123',
        medicineName: 'Atorvastatin 20mg',
        refillDueDate: dueIn3Days,
        recurrence: 'monthly',
        reminderLeadDays: 5,
        notes: 'Take after dinner',
        pharmacyName: 'City Pharmacy',
        pharmacyPhone: '+1234567890',
        billAmount: 18.50,
        createdAt: now.subtract(const Duration(days: 10)),
      );

      expect(refill.daysUntilDue, inInclusiveRange(2, 4));
      expect(refill.isDueSoon, isTrue);
      expect(refill.isOverdue, isFalse);
    });

    test('isDueSoon is false if due date is beyond reminderLeadDays', () {
      final now = DateTime.now();
      final dueIn10Days = now.add(const Duration(days: 10));

      final refill = MedicineRefillModel(
        id: 'refill_2',
        patientId: 'PT123',
        medicineName: 'Metformin 500mg',
        refillDueDate: dueIn10Days,
        recurrence: 'monthly',
        reminderLeadDays: 5,
        createdAt: now,
      );

      expect(refill.daysUntilDue, inInclusiveRange(9, 11));
      expect(refill.isDueSoon, isFalse);
    });

    test('isDueSoon is false if schedule is paused', () {
      final now = DateTime.now();
      final dueIn2Days = now.add(const Duration(days: 2));

      final refill = MedicineRefillModel(
        id: 'refill_3',
        patientId: 'PT123',
        medicineName: 'Lisinopril 10mg',
        refillDueDate: dueIn2Days,
        recurrence: 'monthly',
        reminderLeadDays: 5,
        status: 'paused',
        createdAt: now,
      );

      expect(refill.isPaused, isTrue);
      expect(refill.isDueSoon, isFalse);
    });

    test('computes next monthly due date with variable month lengths correctly', () {
      // 1. Regular 31-day month to 30-day month (March 31 -> April 30)
      final march31 = DateTime(2026, 3, 31, 10, 0);
      final nextAfterMarch = MedicineRefillModel.calculateNextDueDate(march31, 'monthly');
      expect(nextAfterMarch, isNotNull);
      expect(nextAfterMarch!.year, 2026);
      expect(nextAfterMarch.month, 4);
      expect(nextAfterMarch.day, 30);

      // 2. January 31 to February (non-leap year 2026 -> Feb 28)
      final jan31_2026 = DateTime(2026, 1, 31, 9, 30);
      final feb2026 = MedicineRefillModel.calculateNextDueDate(jan31_2026, 'monthly');
      expect(feb2026, isNotNull);
      expect(feb2026!.year, 2026);
      expect(feb2026.month, 2);
      expect(feb2026.day, 28);

      // 3. January 31 to February (leap year 2024 -> Feb 29)
      final jan31_2024 = DateTime(2024, 1, 31, 9, 30);
      final feb2024 = MedicineRefillModel.calculateNextDueDate(jan31_2024, 'monthly');
      expect(feb2024, isNotNull);
      expect(feb2024!.year, 2024);
      expect(feb2024.month, 2);
      expect(feb2024.day, 29);

      // 4. December to January next year (Dec 15 -> Jan 15)
      final dec15 = DateTime(2026, 12, 15, 8, 0);
      final janNextYear = MedicineRefillModel.calculateNextDueDate(dec15, 'monthly');
      expect(janNextYear, isNotNull);
      expect(janNextYear!.year, 2027);
      expect(janNextYear.month, 1);
      expect(janNextYear.day, 15);

      // 5. Weekly recurrence
      final monday = DateTime(2026, 10, 5);
      final nextWeek = MedicineRefillModel.calculateNextDueDate(monday, 'weekly');
      expect(nextWeek, isNotNull);
      expect(nextWeek!.difference(monday).inDays, 7);

      // 6. None recurrence returns null
      final none = MedicineRefillModel.calculateNextDueDate(monday, 'none');
      expect(none, isNull);
    });

    test('serializes and deserializes to/from Firestore map', () {
      final now = DateTime(2026, 10, 15, 12, 0);
      final refill = MedicineRefillModel(
        id: 'refill_99',
        patientId: 'PT555',
        medicineName: 'Amlodipine 5mg',
        refillDueDate: now.add(const Duration(days: 5)),
        recurrence: 'monthly',
        reminderLeadDays: 5,
        notes: 'Refill at CVS pharmacy',
        prescriptionDetails: 'Take 1 tablet daily every morning',
        pharmacyName: 'CVS Caremark',
        pharmacyPhone: '555-0199',
        billAmount: 25.00,
        isBillPaid: true,
        createdAt: now,
      );

      final map = refill.toMap();
      final fromMap = MedicineRefillModel.fromMap(map, 'refill_99');

      expect(fromMap.id, 'refill_99');
      expect(fromMap.patientId, 'PT555');
      expect(fromMap.medicineName, 'Amlodipine 5mg');
      expect(fromMap.notes, 'Refill at CVS pharmacy');
      expect(fromMap.prescriptionDetails, 'Take 1 tablet daily every morning');
      expect(fromMap.pharmacyName, 'CVS Caremark');
      expect(fromMap.pharmacyPhone, '555-0199');
      expect(fromMap.billAmount, 25.00);
      expect(fromMap.isBillPaid, isTrue);
      expect(fromMap.isPaused, isFalse);
    });
  });

  group('DashboardNotificationCarousel Widget Tests', () {
    final now = DateTime.now();

    final testRefill = MedicineRefillModel(
      id: 'ref_1',
      patientId: 'PT9876',
      medicineName: 'Atorvastatin',
      refillDueDate: now.add(const Duration(days: 5)),
      recurrence: 'monthly',
      reminderLeadDays: 5,
      createdAt: now.subtract(const Duration(days: 2)),
      prescriptionDetails: 'Take 1 tab daily with water',
    );

    final testReminder = ReminderModel(
      reminderId: 'rem_1',
      patientId: 'PT9876',
      title: 'Morning Medicine',
      recurrence: 'daily',
      times: const ['08:00'],
      importance: 'high',
      maxRepeats: 3,
      repeatEveryMinutes: 15,
      active: true,
      createdBy: 'caregiver_1',
      createdAt: now,
    );

    final testOccurrence = ReminderOccurrenceModel(
      occurrenceId: 'occ_1',
      reminderId: 'rem_1',
      scheduledTime: now.subtract(const Duration(minutes: 5)),
      status: 'snoozed',
      repeatCount: 0,
      snoozeCount: 1,
    );

    testWidgets('renders carousel header, bell icon, arrow controls, and cards',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            remindersProvider('PT9876')
                .overrideWith((ref) => Stream.value([testReminder])),
            actionableOccurrencesProvider('PT9876')
                .overrideWith((ref) => Stream.value([testOccurrence])),
            patientRefillsProvider('PT9876')
                .overrideWith((ref) => Stream.value([testRefill])),
          ],
          child: MaterialApp(
            theme: AppTheme.patientTheme,
            home: Scaffold(
              body: DashboardNotificationCarousel(
                patientId: 'PT9876',
                onOpenHydration: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Carousel Header & Typography
      expect(find.text('Notices for you'), findsOneWidget);
      expect(find.text('Swipe to see more'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);

      // Desktop arrow controls
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsOneWidget);

      // First active card is Snoozed Medicine Reminder
      expect(find.text('Medicine reminder'), findsOneWidget);
      expect(find.textContaining('You snoozed your Morning Medicine'), findsOneWidget);
      expect(find.text('Take now'), findsOneWidget);

      // Tap Next Arrow to slide to next card (Refill Soon)
      final nextBtn = find.byIcon(Icons.arrow_forward_ios_rounded);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      expect(find.text('Refill soon'), findsOneWidget);
      expect(find.textContaining('Atorvastatin in 5 days'), findsOneWidget);
      expect(find.text('View details'), findsOneWidget);
    });

    testWidgets('dismissing a card removes it from view without marking dose taken',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            remindersProvider('PT9876')
                .overrideWith((ref) => Stream.value([testReminder])),
            actionableOccurrencesProvider('PT9876')
                .overrideWith((ref) => Stream.value([testOccurrence])),
            patientRefillsProvider('PT9876')
                .overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: AppTheme.patientTheme,
            home: Scaffold(
              body: DashboardNotificationCarousel(
                patientId: 'PT9876',
                onOpenHydration: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Medicine reminder'), findsOneWidget);

      // Find close icon button on the card
      final closeBtn = find.byIcon(Icons.close_rounded).first;
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      // Card dismissed from carousel
      expect(find.text('Medicine reminder'), findsNothing);

      // Occurrence data remains snoozed, not taken
      expect(testOccurrence.status, 'snoozed');
    });
  });

  group('PatientHomeScreen Full Dashboard Integration Tests', () {
    final mockPatientUser = UserModel(
      uid: 'user_123',
      email: 'jane.smith@example.com',
      name: 'Jane Smith',
      role: 'patient',
      patientId: 'PT4455',
      createdAt: DateTime(2026, 1, 1),
    );

    testWidgets(
        'verifies Header -> Live Date/Time -> Notification Box -> 4x4 Grid -> Prescriptions & Refills order',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => Stream.value(mockPatientUser)),
            patientLinksProvider.overrideWith((ref) => Stream.value([])),
            remindersProvider('PT4455').overrideWith((ref) => Stream.value([])),
            actionableOccurrencesProvider('PT4455')
                .overrideWith((ref) => Stream.value([])),
            patientRefillsProvider('PT4455')
                .overrideWith((ref) => Stream.value([])),
            patientContactsProvider('PT4455')
                .overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: AppTheme.patientTheme,
            home: const PatientHomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Header & Patient ID
      expect(find.text('Hello, Jane!'), findsOneWidget);
      expect(find.text('ID: PT4455'), findsOneWidget);

      // 2. Notification Box ("Notices for you")
      expect(find.text('Notices for you'), findsOneWidget);

      // 3. Existing 4 options grid
      expect(find.text('My medicine'), findsOneWidget);
      expect(find.text('Reminders'), findsOneWidget);
      expect(find.text('SOS'), findsOneWidget);
      expect(find.text('Text caregiver'), findsOneWidget);

      // 4. Prescriptions & Refills Button / Card below the 4 options grid
      expect(find.text('Prescriptions & Refills'), findsOneWidget);
      expect(find.text('Active schedules, bills & pharmacy info'), findsOneWidget);
    });
  });

  group('Prescription, Tablets Taking, and Daily Refill Alerts Tests', () {
    final now = DateTime.now();

    final testRefillInLast3Days = MedicineRefillModel(
      id: 'refill_urgent_1',
      patientId: 'PT4455',
      medicineName: 'Donepezil 10mg',
      dosage: '10mg at bedtime',
      refillDueDate: now.add(const Duration(days: 2)),
      recurrence: 'monthly',
      reminderLeadDays: 5,
      status: 'active',
      tabletsPerDose: 1,
      dosesPerDay: 1,
      totalTabletsInPack: 30,
      remainingTablets: 4,
      prescriptionDocumentName: 'Rx_Dr_Sarah_Patel.pdf',
      prescriptionDoctorName: 'Dr. Sarah Patel, MD',
      prescriptionClinic: 'Memorial Health Clinic',
      prescriptionDetails: 'Take 1 tablet every night with water',
      pharmacyName: 'CVS Pharmacy',
      pharmacyPhone: '+15551234567',
      billAmount: 15.00,
      createdAt: now.subtract(const Duration(days: 28)),
    );

    test('verifies tablet intake, supply calculation, and isDueInLast3DaysUnhandled', () {
      expect(testRefillInLast3Days.tabletsPerDay, 1);
      expect(testRefillInLast3Days.daysOfSupplyRemaining, 4);
      expect(testRefillInLast3Days.daysUntilDue, inInclusiveRange(1, 3));
      expect(testRefillInLast3Days.isDueInLast3DaysUnhandled, isTrue);

      // If patient asks caregiver, it is no longer unhandled
      final askedRefill = testRefillInLast3Days.copyWith(status: 'caregiver_requested');
      expect(askedRefill.isDueInLast3DaysUnhandled, isFalse);
      expect(askedRefill.isCaregiverRequested, isTrue);

      // If bought/refilled, it is no longer unhandled
      final boughtRefill = testRefillInLast3Days.copyWith(status: 'refilled');
      expect(boughtRefill.isDueInLast3DaysUnhandled, isFalse);
      expect(boughtRefill.isRefilled, isTrue);
    });

    testWidgets(
        'DashboardNotificationCarousel surfaces Daily Refill Alert in last 3 days with one-tap Ask Caregiver and Bought buttons',
        (WidgetTester tester) async {
      final mockRepo = MockRefillRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            refillRepositoryProvider.overrideWithValue(mockRepo),
            remindersProvider('PT4455').overrideWith((ref) => Stream.value([])),
            actionableOccurrencesProvider('PT4455')
                .overrideWith((ref) => Stream.value([])),
            patientRefillsProvider('PT4455')
                .overrideWith((ref) => Stream.value([testRefillInLast3Days])),
          ],
          child: MaterialApp(
            theme: AppTheme.patientTheme,
            home: Scaffold(
              body: DashboardNotificationCarousel(
                patientId: 'PT4455',
                onOpenHydration: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Daily Refill Alert header and message
      expect(find.textContaining('Daily Refill Alert'), findsOneWidget);
      expect(find.textContaining('4 tablets left for Donepezil 10mg'), findsOneWidget);

      // Verify the two one-tap buttons
      final askBtn = find.text('Ask Caregiver');
      final boughtBtn = find.text('Bought');
      expect(askBtn, findsOneWidget);
      expect(boughtBtn, findsOneWidget);

      // Tap 'Ask Caregiver' button
      await tester.tap(askBtn);
      await tester.pumpAndSettle();
      expect(mockRepo.askedCaregiverIds, contains('refill_urgent_1'));

      // Tap 'Bought' button
      await tester.tap(boughtBtn);
      await tester.pumpAndSettle();
      expect(mockRepo.boughtRefillIds, contains('refill_urgent_1'));
    });

    testWidgets(
        'PatientRefillsScreen displays prescription doc, tablets taking, next date to buy, and one-tap buttons',
        (WidgetTester tester) async {
      final mockRepo = MockRefillRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            refillRepositoryProvider.overrideWithValue(mockRepo),
            patientRefillsProvider('PT4455')
                .overrideWith((ref) => Stream.value([testRefillInLast3Days])),
          ],
          child: MaterialApp(
            theme: AppTheme.patientTheme,
            home: const PatientRefillsScreen(patientId: 'PT4455'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header
      expect(find.text('Prescriptions & Refills'), findsOneWidget);

      // Daily Refill Alert banner at top
      expect(find.text('Daily Refill Alert (Last 3 Days)'), findsOneWidget);

      // Medicine title
      expect(find.text('Donepezil 10mg'), findsOneWidget);

      // Tablets Taking & supply tracking
      expect(find.text('Tablets Taking:'), findsOneWidget);
      expect(find.text('1 tablet • 1x daily'), findsOneWidget);
      expect(find.text('4 of 30 tablets left'), findsOneWidget);

      // Next Date to Buy
      expect(find.text('Next Date to Buy:'), findsOneWidget);

      // Prescription Document section
      expect(find.text('Prescription Document:'), findsOneWidget);
      expect(find.text('Rx_Dr_Sarah_Patel.pdf'), findsOneWidget);
      expect(find.textContaining('Dr. Sarah Patel, MD'), findsOneWidget);

      // Open Prescription Document viewer
      final viewDocBtn = find.text('View Doc');
      expect(viewDocBtn, findsOneWidget);
      await tester.tap(viewDocBtn);
      await tester.pumpAndSettle();

      // In the modal prescription sheet
      expect(find.text('℞ OFFICIAL PRESCRIPTION'), findsOneWidget);
      expect(find.text('VERIFIED RX'), findsOneWidget);

      // Close doc viewer via close icon button
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();

      // Verify the two one-tap action buttons
      final askCaregiverBtn =
          find.byKey(const ValueKey('ask_caregiver_to_buy_btn'));
      final boughtMedicineBtn =
          find.byKey(const ValueKey('bought_medicine_btn'));
      expect(askCaregiverBtn, findsOneWidget);
      expect(boughtMedicineBtn, findsOneWidget);

      // Scroll to and tap "Ask Caregiver to Buy"
      await tester.ensureVisible(askCaregiverBtn);
      await tester.pumpAndSettle();
      await tester.tap(askCaregiverBtn);
      await tester.pumpAndSettle();
      expect(mockRepo.askedCaregiverIds, contains('refill_urgent_1'));

      // Scroll to and tap "Bought the Medicine"
      await tester.ensureVisible(boughtMedicineBtn);
      await tester.pumpAndSettle();
      await tester.tap(boughtMedicineBtn);
      await tester.pumpAndSettle();
      expect(mockRepo.boughtRefillIds, contains('refill_urgent_1'));
    });
  });
}

