import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memora/core/theme/app_theme.dart';
import 'package:memora/data/models/emergency_contact_model.dart';
import 'package:memora/data/services/tts_service.dart';
import 'package:memora/features/emergency_contacts/data/contact_providers.dart';
import 'package:memora/features/voice_assistant/presentation/voice_assistant_modal.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockContact = EmergencyContactModel(
    id: 'c1',
    patientId: 'PT1234',
    name: 'Ravi Kumar',
    phoneNumber: '+15551234567',
    relationship: 'Doctor',
    isPrimary: true,
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'),
            (MethodCall methodCall) async {
      return 1;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugin.csdcorp.com/speech_to_text'),
            (MethodCall methodCall) async {
      if (methodCall.method == 'initialize') return true;
      if (methodCall.method == 'has_permission') return true;
      if (methodCall.method == 'listen') return true;
      if (methodCall.method == 'stop') return true;
      if (methodCall.method == 'cancel') return true;
      return true;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter.baseflow.com/permissions/methods'),
            (MethodCall methodCall) async {
      return 1; // granted
    });
  });

  tearDown(() {
    TtsService().stop();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugin.csdcorp.com/speech_to_text'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter.baseflow.com/permissions/methods'), null);
  });

  Widget buildModalTestWidget({
    bool autoStart = false,
    VoidCallback? onOpenContacts,
    stt.SpeechToText? speechToText,
  }) {
    return ProviderScope(
      overrides: [
        currentEmergencyContactsProvider
            .overrideWith((ref) => Stream.value([mockContact])),
      ],
      child: MaterialApp(
        theme: AppTheme.patientTheme,
        home: Scaffold(
          body: VoiceAssistantModal(
            onOpenContacts: onOpenContacts ?? () {},
            autoStart: autoStart,
            speechToText: speechToText,
          ),
        ),
      ),
    );
  }

  group('VoiceAssistantModal Tests', () {
    testWidgets(
        'Idle state renders purple button, no animation, and Tap to speak label',
        (tester) async {
      await tester.pumpWidget(buildModalTestWidget(autoStart: false));
      await tester.pumpAndSettle();

      // Verify header
      expect(find.text('Memora Voice'), findsOneWidget);

      // Verify Idle state label
      expect(find.text('Tap to speak'), findsOneWidget);
      expect(find.text('Tap the microphone when you want to speak'),
          findsOneWidget);

      // Verify microphone icon is present
      expect(find.byIcon(Icons.mic_rounded), findsWidgets);

      // Verify quick chips
      expect(find.text("What's the time now?"), findsOneWidget);
      expect(find.text("What's today's date?"), findsOneWidget);
      expect(find.text('Call my emergency contact'), findsOneWidget);

      // Verify fallback text field
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byKey(const ValueKey('voice_assistant_send_text_btn')),
          findsOneWidget);
    });

    testWidgets(
        'Tapping quick command "What\'s the time now?" answers with TTS and displays Stop Speaking button',
        (tester) async {
      await tester.pumpWidget(buildModalTestWidget(autoStart: false));
      await tester.pumpAndSettle();

      final timeChip = find.text("What's the time now?");
      expect(timeChip, findsOneWidget);
      await tester.tap(timeChip);
      await tester.pumpAndSettle();

      // Check for speaking state or answer display
      expect(find.text('Memora is speaking...'), findsOneWidget);
      expect(find.text('Current Time'), findsOneWidget);
      expect(find.text('Stop Speaking'), findsOneWidget);

      // Tap Stop Speaking button
      final stopSpeakingBtn =
          find.byKey(const ValueKey('voice_assistant_stop_speaking_btn'));
      expect(stopSpeakingBtn, findsOneWidget);
      await tester.tap(stopSpeakingBtn);
      await tester.pumpAndSettle();

      // UI returns to idle state
      expect(find.text('Tap to speak'), findsOneWidget);
      expect(find.text('Memora is speaking...'), findsNothing);
    });

    testWidgets(
        'Call command requires explicit confirmation before dialing (Dementia safety)',
        (tester) async {
      await tester.pumpWidget(buildModalTestWidget(autoStart: false));
      await tester.pumpAndSettle();

      final callChip = find.text('Call my emergency contact');
      expect(callChip, findsOneWidget);
      await tester.tap(callChip);
      await tester.pumpAndSettle();

      // Check for confirmation card
      expect(find.text('Confirm Call'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Call Ravi'), findsOneWidget);

      // Tapping Cancel dismisses the confirmation without calling
      await tester.ensureVisible(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Call'), findsNothing);
    });

    testWidgets(
        'Typing into fallback text input processes command and clears text field',
        (tester) async {
      await tester.pumpWidget(buildModalTestWidget(autoStart: false));
      await tester.pumpAndSettle();

      final input = find.byType(TextField);
      await tester.enterText(input, "what's today's date");
      await tester.tap(
          find.byKey(const ValueKey('voice_assistant_send_text_btn')));
      await tester.pumpAndSettle();

      expect(find.text("Today's Date"), findsOneWidget);
      expect(find.text('Memora is speaking...'), findsOneWidget);
    });

    testWidgets('Tapping open contacts button calls onOpenContacts callback',
        (tester) async {
      bool contactsOpened = false;
      await tester.pumpWidget(buildModalTestWidget(
        autoStart: false,
        onOpenContacts: () => contactsOpened = true,
      ));
      await tester.pumpAndSettle();

      final contactsChip = find.text('Show emergency contacts');
      await tester.tap(contactsChip);
      await tester.pumpAndSettle();

      expect(find.text('Open Emergency Contacts'), findsOneWidget);
      await tester.tap(find.text('Open Emergency Contacts'));
      await tester.pumpAndSettle();

      expect(contactsOpened, isTrue);
    });

    testWidgets('One tap with autoStart: true starts listening immediately without a second tap',
        (tester) async {
      await tester.pumpWidget(buildModalTestWidget(autoStart: true));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Listening state should be active immediately
      expect(find.text('Listening... Speak now'), findsOneWidget);
      expect(find.textContaining('Time remaining:'), findsOneWidget);
      expect(find.byKey(const ValueKey('voice_assistant_stop_btn')),
          findsOneWidget);
      expect(find.text('Tap to speak'), findsNothing);

      // Tap stop to stop listening and animation
      final stopBtn = find.byKey(const ValueKey('voice_assistant_stop_btn'));
      await tester.tap(stopBtn);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('Tapping Stop button stops listening and returns to idle if no words were spoken',
        (tester) async {
      await tester.pumpWidget(buildModalTestWidget(autoStart: true));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('Listening... Speak now'), findsOneWidget);

      final stopBtn = find.byKey(const ValueKey('voice_assistant_stop_btn'));
      expect(stopBtn, findsOneWidget);
      await tester.tap(stopBtn);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // UI returns to idle state
      expect(find.text('Tap to speak'), findsOneWidget);
      expect(find.text('Listening... Speak now'), findsNothing);
    });

    testWidgets('When speech recognition is unavailable, displays gentle error and Retry button',
        (tester) async {
      // Mock speech initialization failure
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugin.csdcorp.com/speech_to_text'),
              (MethodCall methodCall) async {
        if (methodCall.method == 'initialize') return false;
        if (methodCall.method == 'has_permission') return false;
        return false;
      });

      final freshSpeech = SpeechToText.withMethodChannel();
      await tester.pumpWidget(buildModalTestWidget(
        autoStart: true,
        speechToText: freshSpeech,
      ));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('Could Not Hear You'), findsOneWidget);
      expect(find.byKey(const ValueKey('voice_assistant_retry_btn')),
          findsOneWidget);
      expect(find.text('Listening... Speak now'), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });
  });
}
