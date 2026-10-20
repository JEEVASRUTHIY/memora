import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:memora/core/app_config.dart';
import 'package:memora/data/services/gemini_voice_service.dart';
import 'package:memora/data/models/emergency_contact_model.dart';
import 'package:memora/data/models/user_model.dart';
import 'package:memora/data/models/link_model.dart';
import 'package:memora/features/auth/data/auth_providers.dart';
import 'package:memora/features/emergency_contacts/data/contact_providers.dart';
import 'package:memora/features/emergency_contacts/presentation/emergency_contacts_screen.dart';
import 'package:memora/data/repositories/contact_repository.dart';
import 'package:memora/features/voice_assistant/data/voice_command_service.dart';
import 'package:memora/data/services/location_service.dart';
import 'package:memora/core/theme/app_theme.dart';

void main() {
  group('VoiceCommandService Tests', () {
    final contact1 = EmergencyContactModel(
      id: 'c1',
      patientId: 'patient_123',
      name: 'Ravi Kumar',
      phoneNumber: '+15551234567',
      relationship: 'Doctor',
      isPrimary: true,
      createdAt: DateTime(2026, 1, 1),
    );

    final contact2 = EmergencyContactModel(
      id: 'c2',
      patientId: 'patient_123',
      name: 'Ravi Sharma',
      phoneNumber: '+15559876543',
      relationship: 'Son',
      isPrimary: false,
      createdAt: DateTime(2026, 1, 2),
    );

    final contact3 = EmergencyContactModel(
      id: 'c3',
      patientId: 'patient_123',
      name: 'Ananya Patel',
      phoneNumber: '+15554567890',
      relationship: 'Daughter',
      isPrimary: false,
      createdAt: DateTime(2026, 1, 3),
    );

    test('Show emergency contacts matches multiple phrase variations', () {
      final phrases = [
        'Show my emergency contacts',
        'show emergency contacts',
        'open contacts',
        'show contacts',
        'emergency contacts',
      ];

      for (final p in phrases) {
        final result = VoiceCommandService.processCommand(
          rawInput: p,
          contacts: [contact1, contact3],
        );
        expect(result, isA<VoiceCommandShowContacts>());
      }
    });

    test('Call Ravi with single match requests confirmation before dialing', () {
      final result = VoiceCommandService.processCommand(
        rawInput: 'Call Ravi',
        contacts: [contact1, contact3], // Only Ravi Kumar
      );

      expect(result, isA<VoiceCommandConfirmCall>());
      final confirm = result as VoiceCommandConfirmCall;
      expect(confirm.contact.name, 'Ravi Kumar');
      expect(confirm.contact.phoneNumber, '+15551234567');
      expect(confirm.prompt, contains('Ravi Kumar'));
    });

    test('Call Ravi with multiple matches requests disambiguation', () {
      final result = VoiceCommandService.processCommand(
        rawInput: 'Call Ravi',
        contacts: [contact1, contact2, contact3], // Ravi Kumar & Ravi Sharma
      );

      expect(result, isA<VoiceCommandDisambiguate>());
      final disambiguate = result as VoiceCommandDisambiguate;
      expect(disambiguate.matches.length, 2);
      expect(disambiguate.prompt, contains('multiple contacts'));
    });

    test('Call non-existent contact returns not found', () {
      final result = VoiceCommandService.processCommand(
        rawInput: 'Call Samantha',
        contacts: [contact1, contact3],
      );

      expect(result, isA<VoiceCommandNotFound>());
      final notFound = result as VoiceCommandNotFound;
      expect(notFound.query, 'samantha');
      expect(notFound.message, contains('could not find'));
    });

    test('Call my emergency contact prioritizes primary contact', () {
      final result = VoiceCommandService.processCommand(
        rawInput: 'Call my emergency contact',
        contacts: [contact3, contact1], // contact1 is marked isPrimary: true
      );

      expect(result, isA<VoiceCommandConfirmCall>());
      final confirm = result as VoiceCommandConfirmCall;
      expect(confirm.contact.isPrimary, isTrue);
      expect(confirm.contact.name, 'Ravi Kumar');
    });

    test('Call emergency contact with empty list returns empty state', () {
      final result = VoiceCommandService.processCommand(
        rawInput: 'Call my emergency contact',
        contacts: [],
      );

      expect(result, isA<VoiceCommandEmptyContacts>());
    });

    test('Unrecognized input returns VoiceCommandUnrecognized', () {
      final result = VoiceCommandService.processCommand(
        rawInput: 'Random gibberish words 12345',
        contacts: [contact1],
      );

      expect(result, isA<VoiceCommandUnrecognized>());
    });

    test('Date query returns VoiceCommandAnswer with formatted date', () {
      final fixedDate = DateTime(2026, 10, 18, 23, 30);
      final phrases = [
        "what's today's date",
        "what is today's date",
        "whats todays data",
        "tell me the date",
        "current date",
      ];

      for (final p in phrases) {
        final result = VoiceCommandService.processCommand(
          rawInput: p,
          contacts: [contact1],
          nowProvider: () => fixedDate,
        );

        expect(result, isA<VoiceCommandAnswer>());
        final ans = result as VoiceCommandAnswer;
        expect(ans.title, "Today's Date");
        expect(ans.displayText, 'Today is Sunday, October 18, 2026.');
        expect(ans.speechText, 'Today is Sunday, October 18, 2026.');
      }
    });

    test('Time query returns VoiceCommandAnswer with formatted time', () {
      final fixedDate = DateTime(2026, 10, 18, 23, 30);
      final phrases = [
        "what's the time now",
        "ehats the time now",
        "what time is it",
        "tell me the time",
        "current time",
      ];

      for (final p in phrases) {
        final result = VoiceCommandService.processCommand(
          rawInput: p,
          contacts: [contact1],
          nowProvider: () => fixedDate,
        );

        expect(result, isA<VoiceCommandAnswer>());
        final ans = result as VoiceCommandAnswer;
        expect(ans.title, 'Current Time');
        expect(ans.displayText, 'It is 11:30 PM right now.');
        expect(ans.speechText, 'The time is 11:30 PM.');
      }
    });

    test('Day of week query returns VoiceCommandAnswer with formatted day', () {
      final fixedDate = DateTime(2026, 10, 18, 23, 30);
      final result = VoiceCommandService.processCommand(
        rawInput: 'what day is it today',
        contacts: [contact1],
        nowProvider: () => fixedDate,
      );

      expect(result, isA<VoiceCommandAnswer>());
      final ans = result as VoiceCommandAnswer;
      expect(ans.title, 'Day of the Week');
      expect(ans.displayText, 'Today is Sunday.');
      expect(ans.speechText, 'Today is Sunday.');
    });

    test('Where am I query returns VoiceCommandLocationResult when at home', () {
      final locationInfo = PatientLocationInfo(
        isAtHome: true,
        locationTitle: 'Safe at Home',
        displayExplanation:
            'You are safely at home in your cozy living room at 123 Maple Avenue.',
        speechExplanation:
            'You are safely at home in your cozy living room at 123 Maple Avenue. Everything is familiar and safe.',
      );

      final phrases = [
        'where am i',
        'where am i now',
        'what is my location',
        'am i at home',
        'where am i right now',
      ];

      for (final p in phrases) {
        final result = VoiceCommandService.processCommand(
          rawInput: p,
          contacts: [contact1],
          locationProvider: () => locationInfo,
        );

        expect(result, isA<VoiceCommandLocationResult>());
        final locResult = result as VoiceCommandLocationResult;
        expect(locResult.isAtHome, isTrue);
        expect(locResult.emergencyContact, isNull);
        expect(locResult.displayText, contains('safely at home'));
      }
    });

    test('Where am I query when away from home prompts to call emergency contact', () {
      final awayLocation = PatientLocationInfo(
        isAtHome: false,
        locationTitle: 'Away on Oak Street',
        displayExplanation:
            'You are currently on Oak Street near the corner bakery, away from home.',
        speechExplanation:
            'You are currently on Oak Street near the corner bakery, away from home. Would you like to call your emergency contact?',
      );

      final result = VoiceCommandService.processCommand(
        rawInput: 'where am i',
        contacts: [contact1, contact2], // contact1 is primary
        locationProvider: () => awayLocation,
      );

      expect(result, isA<VoiceCommandLocationResult>());
      final locResult = result as VoiceCommandLocationResult;
      expect(locResult.isAtHome, isFalse);
      expect(locResult.emergencyContact?.name, 'Ravi Kumar');
      expect(
        locResult.callPrompt,
        contains('Ravi Kumar'),
      );
      expect(
        locResult.speechText,
        contains('Would you like to call your emergency contact?'),
      );
    });

    test('Flexible calling phrases match contacts correctly', () {
      final variations = [
        'can you please call Ravi',
        'can you call Ravi',
        'i want to speak to Ravi',
        'please phone Ravi',
        'connect me to Ravi',
      ];

      for (final phrase in variations) {
        final result = VoiceCommandService.processCommand(
          rawInput: phrase,
          contacts: [contact1, contact3],
        );
        expect(result, isA<VoiceCommandConfirmCall>());
        final confirm = result as VoiceCommandConfirmCall;
        expect(confirm.contact.name, 'Ravi Kumar');
      }
    });
  });

  group('EmergencyContactModel Serialization', () {
    test('toMap and fromMap preserves all fields correctly', () {
      final model = EmergencyContactModel(
        id: 'contact_abc',
        patientId: 'patient_xyz',
        name: 'Dr. John Doe',
        phoneNumber: '+1-800-555-0199',
        relationship: 'Doctor',
        isPrimary: true,
        createdAt: DateTime(2026, 5, 10, 14, 30),
      );

      final map = model.toMap();
      expect(map['name'], 'Dr. John Doe');
      expect(map['phoneNumber'], '+1-800-555-0199');
      expect(map['relationship'], 'Doctor');
      expect(map['isPrimary'], true);
      expect(map['patientId'], 'patient_xyz');

      final deserialized = EmergencyContactModel.fromMap(map, 'contact_abc');
      expect(deserialized.id, 'contact_abc');
      expect(deserialized.name, 'Dr. John Doe');
      expect(deserialized.phoneNumber, '+1-800-555-0199');
      expect(deserialized.relationship, 'Doctor');
      expect(deserialized.isPrimary, true);
    });
  });

  group('activePatientIdProvider Tests', () {
    test('resolves patientId for authenticated patient', () async {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(
                UserModel(
                  uid: 'patient_uid_1',
                  role: 'patient',
                  name: 'Alice Patient',
                  email: 'alice@test.com',
                  patientId: 'PT1234',
                  createdAt: DateTime(2026, 1, 1),
                ),
              )),
        ],
      );
      addTearDown(container.dispose);

      await container.read(currentUserProvider.future);
      final patientId = container.read(activePatientIdProvider);
      expect(patientId, 'PT1234');
    });

    test('resolves linked patientId for authenticated caregiver', () async {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(
                UserModel(
                  uid: 'caregiver_uid_1',
                  role: 'caregiver',
                  name: 'Bob Caregiver',
                  email: 'bob@test.com',
                  createdAt: DateTime(2026, 1, 1),
                ),
              )),
          caregiverLinksProvider.overrideWith((ref) => Stream.value([
                LinkModel(
                  linkId: 'link_1',
                  caregiverUid: 'caregiver_uid_1',
                  patientId: 'PT5678',
                  caregiverName: 'Bob Caregiver',
                  role: 'primary',
                  status: 'active',
                  requestedBy: 'caregiver',
                  createdAt: DateTime(2026, 1, 1),
                ),
              ])),
        ],
      );
      addTearDown(container.dispose);

      await container.read(currentUserProvider.future);
      await container.read(caregiverLinksProvider.future);
      final patientId = container.read(activePatientIdProvider);
      expect(patientId, 'PT5678');
    });

    test('returns null when caregiver has no active link', () {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(
                UserModel(
                  uid: 'caregiver_uid_2',
                  role: 'caregiver',
                  name: 'Charlie Caregiver',
                  email: 'charlie@test.com',
                  createdAt: DateTime(2026, 1, 1),
                ),
              )),
          caregiverLinksProvider.overrideWith((ref) => Stream.value([
                LinkModel(
                  linkId: 'link_2',
                  caregiverUid: 'caregiver_uid_2',
                  patientId: 'PT9999',
                  caregiverName: 'Charlie Caregiver',
                  role: 'secondary',
                  status: 'pending',
                  requestedBy: 'caregiver',
                  createdAt: DateTime(2026, 1, 1),
                ),
              ])),
        ],
      );
      addTearDown(container.dispose);

      final patientId = container.read(activePatientIdProvider);
      expect(patientId, isNull);
    });

    test('returns null when user is signed out', () {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);

      final patientId = container.read(activePatientIdProvider);
      expect(patientId, isNull);
    });
  });

  group('EmergencyContactsScreen Widget Tests', () {
    testWidgets('displays diagnostic dev error on permission-denied', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => Stream.value(
                  UserModel(
                    uid: 'p1',
                    role: 'patient',
                    name: 'Alice',
                    email: 'alice@test.com',
                    patientId: 'PT1234',
                    createdAt: DateTime(2026, 1, 1),
                  ),
                )),
            patientContactsProvider('PT1234').overrideWith((ref) =>
                Stream.error(FirebaseException(
                  plugin: 'cloud_firestore',
                  code: 'permission-denied',
                  message: 'Missing or insufficient permissions.',
                ))),
          ],
          child: const MaterialApp(
            home: EmergencyContactsScreen(explicitPatientId: 'PT1234'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Could not load emergency contacts'), findsOneWidget);
      expect(find.textContaining('[Dev Debug: permission-denied'), findsOneWidget);
    });

    testWidgets('displays contact cards when data is available', (tester) async {
      final contact = EmergencyContactModel(
        id: 'c1',
        patientId: 'PT1234',
        name: 'Dr. John Doe',
        phoneNumber: '+15551234567',
        relationship: 'Doctor',
        isPrimary: true,
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => Stream.value(
                  UserModel(
                    uid: 'p1',
                    role: 'patient',
                    name: 'Alice',
                    email: 'alice@test.com',
                    patientId: 'PT1234',
                    createdAt: DateTime(2026, 1, 1),
                  ),
                )),
            patientContactsProvider('PT1234').overrideWith((ref) =>
                Stream.value([contact])),
          ],
          child: const MaterialApp(
            home: EmergencyContactsScreen(explicitPatientId: 'PT1234'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Dr. John Doe'), findsOneWidget);
      expect(find.text('+15551234567'), findsOneWidget);
      expect(find.text('Doctor'), findsOneWidget);
      expect(find.text('PRIMARY'), findsOneWidget);
    });

    testWidgets('tapping Add Emergency Contact button opens dialog', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => Stream.value(
                  UserModel(
                    uid: 'p1',
                    role: 'patient',
                    name: 'Alice',
                    email: 'alice@test.com',
                    patientId: 'PT1234',
                    createdAt: DateTime(2026, 1, 1),
                  ),
                )),
            patientContactsProvider('PT1234').overrideWith((ref) =>
                Stream.value([])),
          ],
          child: const MaterialApp(
            home: EmergencyContactsScreen(explicitPatientId: 'PT1234'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final addBtn = find.byKey(const ValueKey('add_emergency_contact_button'));
      expect(addBtn, findsOneWidget);

      await tester.tap(addBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Full Name *'), findsOneWidget);
      expect(find.text('Phone Number *'), findsOneWidget);
    });

    testWidgets('submitting form with valid data calls createContact and dismisses dialog', (tester) async {
      final fakeRepo = _FakeContactRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contactRepositoryProvider.overrideWithValue(fakeRepo),
            currentUserProvider.overrideWith((ref) => Stream.value(
                  UserModel(
                    uid: 'p1',
                    role: 'patient',
                    name: 'Alice',
                    email: 'alice@test.com',
                    patientId: 'PT1234',
                    createdAt: DateTime(2026, 1, 1),
                  ),
                )),
            patientContactsProvider('PT1234').overrideWith((ref) =>
                Stream.value([])),
          ],
          child: const MaterialApp(
            home: EmergencyContactsScreen(explicitPatientId: 'PT1234'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open dialog
      await tester.tap(find.byKey(const ValueKey('add_emergency_contact_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter name
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full Name *'),
        'Dr. Maya Angelou',
      );
      // Enter phone
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone Number *'),
        '+15551234567',
      );
      await tester.pump();

      // Tap Add Contact in dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Contact'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(fakeRepo.created, isTrue);
      // Dialog should be dismissed
      expect(find.text('Full Name *'), findsNothing);
    });

    testWidgets('Add Emergency Contact dialog renders and submits under patientTheme on desktop without infinite width error', (tester) async {
      final fakeRepo = _FakeContactRepository();
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contactRepositoryProvider.overrideWithValue(fakeRepo),
            currentUserProvider.overrideWith((ref) => Stream.value(
                  UserModel(
                    uid: 'p1',
                    role: 'patient',
                    name: 'Alice',
                    email: 'alice@test.com',
                    patientId: 'PT1234',
                    createdAt: DateTime(2026, 1, 1),
                  ),
                )),
            patientContactsProvider('PT1234').overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: AppTheme.patientTheme,
            home: const EmergencyContactsScreen(explicitPatientId: 'PT1234'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final addBtn = find.byKey(const ValueKey('add_emergency_contact_button'));
      await tester.tap(addBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Full Name *'), findsOneWidget);
      final saveBtn = find.byKey(const ValueKey('save_emergency_contact_action_btn'));
      expect(saveBtn, findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name *'), 'Dr. Maya Angelou');
      await tester.enterText(find.widgetWithText(TextFormField, 'Phone Number *'), '+15551234567');
      await tester.pump();

      await tester.tap(saveBtn);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(fakeRepo.created, isTrue);
      expect(find.text('Full Name *'), findsNothing);
    });

    testWidgets('Add Emergency Contact dialog renders and functions on narrow mobile screen (320px width)', (tester) async {
      final fakeRepo = _FakeContactRepository();
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contactRepositoryProvider.overrideWithValue(fakeRepo),
            currentUserProvider.overrideWith((ref) => Stream.value(
                  UserModel(
                    uid: 'p1',
                    role: 'patient',
                    name: 'Alice',
                    email: 'alice@test.com',
                    patientId: 'PT1234',
                    createdAt: DateTime(2026, 1, 1),
                  ),
                )),
            patientContactsProvider('PT1234').overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: AppTheme.patientTheme,
            home: const EmergencyContactsScreen(explicitPatientId: 'PT1234'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final addBtn = find.byKey(const ValueKey('add_emergency_contact_button'));
      await tester.tap(addBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('save_emergency_contact_action_btn')), findsOneWidget);
    });
  });

  group('AI Voice & AppConfig Tests', () {
    test('AppConfig correctly identifies NVIDIA and Gemini keys', () {
      AppConfig.dynamicAiApiKey = 'nvapi-test-key-12345';
      expect(AppConfig.isNvidiaKey, isTrue);
      expect(AppConfig.isGeminiKey, isFalse);
      expect(AppConfig.activeAiProviderName, 'NVIDIA NIM');

      AppConfig.dynamicAiApiKey = 'AIzaSyTestGeminiKey';
      expect(AppConfig.isNvidiaKey, isFalse);
      expect(AppConfig.isGeminiKey, isTrue);
      expect(AppConfig.activeAiProviderName, 'Google Gemini');

      AppConfig.dynamicAiApiKey = '';
    });

    test('GeminiVoiceService.askAi uses NVIDIA NIM completions with mock client', () async {
      AppConfig.dynamicAiApiKey = 'nvapi-mock-token';

      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://integrate.api.nvidia.com/v1/chat/completions');
        expect(request.headers['Authorization'], 'Bearer nvapi-mock-token');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'meta/llama-3.2-11b-vision-instruct');

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': 'You can call Dr. John Doe at +15551234567.',
                }
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final result = await GeminiVoiceService.askAi(
        userPrompt: 'Who can I call?',
        contacts: [
          EmergencyContactModel(
            id: 'c1',
            patientId: 'p1',
            name: 'Dr. John Doe',
            phoneNumber: '+15551234567',
            relationship: 'Doctor',
            isPrimary: true,
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
        httpClient: mockClient,
      );

      expect(result, isA<VoiceCommandAnswer>());
      final answer = result as VoiceCommandAnswer;
      expect(answer.speechText, 'You can call Dr. John Doe at +15551234567.');
      expect(answer.displayText, 'You can call Dr. John Doe at +15551234567.');

      AppConfig.dynamicAiApiKey = '';
    });

    test('GeminiVoiceService.askAi handles HTTP error gracefully', () async {
      AppConfig.dynamicAiApiKey = 'nvapi-mock-token';

      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final result = await GeminiVoiceService.askAi(
        userPrompt: 'Hello',
        contacts: [],
        httpClient: mockClient,
      );

      expect(result, isNull);

      AppConfig.dynamicAiApiKey = '';
    });
  });
}

class _FakeContactRepository implements ContactRepository {
  bool created = false;
  @override
  Future<String> createContact(EmergencyContactModel contact) async {
    created = true;
    return 'fake_id';
  }

  @override
  Stream<List<EmergencyContactModel>> watchContacts(String patientId) =>
      Stream.value(const <EmergencyContactModel>[]);

  @override
  Future<List<EmergencyContactModel>> getContacts(String patientId) async =>
      const <EmergencyContactModel>[];

  @override
  Future<void> updateContact(EmergencyContactModel contact) async {}

  @override
  Future<void> deleteContact(String patientId, String contactId) async {}
}

