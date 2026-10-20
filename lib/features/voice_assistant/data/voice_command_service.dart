import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:memora/data/models/emergency_contact_model.dart';
import 'package:memora/data/services/gemini_voice_service.dart';
import 'package:memora/data/services/location_service.dart';

/// The result or current state of parsing and resolving a voice command.
sealed class VoiceCommandResult {
  const VoiceCommandResult();
}

/// The command answered a location query ("where am I").
class VoiceCommandLocationResult extends VoiceCommandResult {
  final bool isAtHome;
  final String title;
  final String speechText;
  final String displayText;
  final EmergencyContactModel? emergencyContact;
  final String? callPrompt;

  const VoiceCommandLocationResult({
    required this.isAtHome,
    required this.title,
    required this.speechText,
    required this.displayText,
    this.emergencyContact,
    this.callPrompt,
  });
}

/// The command answered a query directly (e.g. date, time, or Gemini AI answer).
class VoiceCommandAnswer extends VoiceCommandResult {
  final String title;
  final String speechText;
  final String displayText;
  final IconData icon;

  const VoiceCommandAnswer({
    required this.title,
    required this.speechText,
    required this.displayText,
    this.icon = Icons.info_outline_rounded,
  });
}

/// The command requests navigating to the Emergency Contacts tab/screen.
class VoiceCommandShowContacts extends VoiceCommandResult {
  final String message;
  const VoiceCommandShowContacts({
    this.message = 'Opening your emergency contacts.',
  });
}

/// Exactly one contact was matched; waiting for user confirmation before dialing.
class VoiceCommandConfirmCall extends VoiceCommandResult {
  final EmergencyContactModel contact;
  final String prompt;

  const VoiceCommandConfirmCall({
    required this.contact,
    required this.prompt,
  });
}

/// Multiple contacts matched the search query; user needs to disambiguate.
class VoiceCommandDisambiguate extends VoiceCommandResult {
  final String query;
  final List<EmergencyContactModel> matches;
  final String prompt;

  const VoiceCommandDisambiguate({
    required this.query,
    required this.matches,
    required this.prompt,
  });
}

/// No contacts matched the requested name.
class VoiceCommandNotFound extends VoiceCommandResult {
  final String query;
  final String message;

  const VoiceCommandNotFound({
    required this.query,
    required this.message,
  });
}

/// No emergency contacts exist at all.
class VoiceCommandEmptyContacts extends VoiceCommandResult {
  final String message;
  const VoiceCommandEmptyContacts({
    this.message = 'You have not added any emergency contacts yet.',
  });
}

/// The command was not recognized as a contact, time, date, or call action.
class VoiceCommandUnrecognized extends VoiceCommandResult {
  final String rawText;
  final String message;

  const VoiceCommandUnrecognized({
    required this.rawText,
    this.message =
        'Sorry, I did not recognize that command. Try "What time is it?", "What is today\'s date?", or "Call Ravi".',
  });
}

/// Helper service for parsing and executing voice commands against Emergency Contacts,
/// time/date inquiries, and Gemini LLM conversations.
class VoiceCommandService {
  /// Parses raw transcribed voice text locally with smart intent matching.
  static VoiceCommandResult processCommand({
    required String rawInput,
    required List<EmergencyContactModel> contacts,
    DateTime Function()? nowProvider,
    PatientLocationInfo Function()? locationProvider,
  }) {
    final cleaned = rawInput
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ''); // remove punctuation

    if (cleaned.isEmpty) {
      return const VoiceCommandUnrecognized(
        rawText: '',
        message:
            'Please say a command such as "What time is it?", "Today\'s date", or "Call Ravi".',
      );
    }

    final now = nowProvider != null ? nowProvider() : DateTime.now();

    // ── 1. Date Queries ("what's today's date", "whats todays data", etc.) ───
    final datePatterns = [
      'whats todays date',
      'what is todays date',
      'what is today date',
      'whats today date',
      'what date is it',
      'what date is today',
      'todays date',
      'today date',
      'tell me the date',
      'tell me todays date',
      'current date',
      'whats the date',
      'what is the date',
      // Phonetic speech-to-text common variations:
      'whats todays data',
      'what is todays data',
      'today data',
    ];

    if (datePatterns.any((p) => cleaned == p || cleaned.contains(p))) {
      final formattedDate = DateFormat('EEEE, MMMM d, y').format(now);
      return VoiceCommandAnswer(
        title: "Today's Date",
        speechText: 'Today is $formattedDate.',
        displayText: 'Today is $formattedDate.',
        icon: Icons.calendar_today_rounded,
      );
    }

    // ── 2. Time Queries ("what's the time now", "ehats the time now", etc.) ──
    final timePatterns = [
      'whats the time now',
      'what is the time now',
      'what is the time',
      'whats the time',
      'what time is it now',
      'what time is it',
      'what time it is',
      'tell me the time',
      'current time',
      'the time right now',
      'time right now',
      'time now',
      // Phonetic speech-to-text variations:
      'ehats the time now',
      'whats time now',
    ];

    if (timePatterns.any((p) => cleaned == p || cleaned.contains(p))) {
      final formattedTime = DateFormat('h:mm a').format(now);
      return VoiceCommandAnswer(
        title: 'Current Time',
        speechText: 'The time is $formattedTime.',
        displayText: 'It is $formattedTime right now.',
        icon: Icons.access_time_rounded,
      );
    }

    // ── 3. Day of Week Queries ("what day is it today", etc.) ────────────────
    final dayPatterns = [
      'what day is it today',
      'what day is it',
      'what day is today',
      'which day is today',
      'which day is it',
      'day of the week',
    ];

    if (dayPatterns.any((p) => cleaned == p || cleaned.contains(p))) {
      final formattedDay = DateFormat('EEEE').format(now);
      return VoiceCommandAnswer(
        title: 'Day of the Week',
        speechText: 'Today is $formattedDay.',
        displayText: 'Today is $formattedDay.',
        icon: Icons.today_rounded,
      );
    }

    // ── 4. Location Queries ("where am i", "where am i now", "what is my location", etc.) ───
    final locationPatterns = [
      'where am i',
      'where am i now',
      'where am i right now',
      'where i am',
      'tell me where i am',
      'what is my location',
      'whats my location',
      'what location am i at',
      'am i at home',
      'am i home',
      'where is this',
      'where are we',
    ];

    if (locationPatterns.any((p) => cleaned == p || cleaned.contains(p))) {
      final loc = locationProvider != null
          ? locationProvider()
          : const PatientLocationInfo(
              isAtHome: true,
              locationTitle: 'Safe at Home',
              speechExplanation: 'You are safely at home in your living room.',
              displayExplanation: 'You are safe at home. Everything is okay.',
            );

      final primaryContact = contacts.where((c) => c.isPrimary).firstOrNull ??
          contacts.firstOrNull;

      return VoiceCommandLocationResult(
        isAtHome: loc.isAtHome,
        title: loc.locationTitle,
        speechText: loc.speechExplanation,
        displayText: loc.displayExplanation,
        emergencyContact: !loc.isAtHome ? primaryContact : null,
        callPrompt: !loc.isAtHome
            ? (primaryContact != null
                ? 'Would you like to call ${primaryContact.name}?'
                : 'Would you like to call your emergency contact?')
            : null,
      );
    }

    // ── 5. "Show emergency contacts" / "Who can I call" ─────────────────────
    final showPatterns = [
      'show emergency contacts',
      'show my emergency contacts',
      'show emergency contact',
      'open emergency contacts',
      'open my emergency contacts',
      'show contacts',
      'open contacts',
      'view contacts',
      'emergency contacts',
      'who can i call in an emergency',
      'who can i call',
      'who are my emergency contacts',
      'who are my contacts',
      'list my contacts',
    ];

    if (showPatterns.any((p) => cleaned == p || cleaned.contains(p))) {
      return const VoiceCommandShowContacts();
    }

    // ── 5. "Call my emergency contact" / "Call emergency contact" ────────────
    final genericCallPatterns = [
      'call my emergency contact',
      'call emergency contact',
      'call the emergency contact',
      'call primary contact',
      'call my primary contact',
      'call emergency',
      'call doctor',
      'phone my emergency contact',
      'dial emergency contact',
      'dial my emergency contact',
    ];

    if (genericCallPatterns.any((p) => cleaned == p || cleaned.startsWith(p))) {
      if (contacts.isEmpty) {
        return const VoiceCommandEmptyContacts();
      }

      // Prioritize contact marked as primary, else take first
      final target = contacts.firstWhere(
        (c) => c.isPrimary,
        orElse: () => contacts.first,
      );

      return VoiceCommandConfirmCall(
        contact: target,
        prompt:
            'I found your emergency contact, ${target.name} (${target.relationship}). Do you want to call ${target.phoneNumber}?',
      );
    }

    // ── 6. Flexible Calling: "Call [Name]", "Can you call [Name]", etc. ─────
    final callPrefixes = [
      'can you please call',
      'can you call',
      'could you call',
      'please call',
      'please phone',
      'please dial',
      'i want to call',
      'i need to call',
      'i want to talk to',
      'i need to talk to',
      'i want to speak to',
      'i need to speak to',
      'connect me with',
      'connect me to',
      'get in touch with',
      'reach out to',
      'call',
      'phone',
      'dial',
      'reach',
    ];

    for (final prefix in callPrefixes) {
      if (cleaned.startsWith('$prefix ')) {
        final nameQuery = cleaned.substring(prefix.length).trim();
        if (nameQuery.isNotEmpty) {
          return _lookupByName(nameQuery: nameQuery, contacts: contacts);
        }
      }
    }

    // If the input is just a contact name or relationship directly
    final directMatch = contacts.where(
      (c) =>
          c.name.toLowerCase() == cleaned ||
          c.relationship.toLowerCase() == cleaned,
    ).toList();
    if (directMatch.length == 1) {
      final target = directMatch.first;
      return VoiceCommandConfirmCall(
        contact: target,
        prompt:
            'Found ${target.name} (${target.relationship}). Would you like to call ${target.phoneNumber}?',
      );
    }

    return VoiceCommandUnrecognized(rawText: rawInput);
  }

  /// Hybrid voice processing: attempts local intent resolution first,
  /// falling back to Gemini AI for free-form conversational questions.
  static Future<VoiceCommandResult> processCommandAsync({
    required String rawInput,
    required List<EmergencyContactModel> contacts,
    DateTime Function()? nowProvider,
    PatientLocationInfo Function()? locationProvider,
  }) async {
    // 1. Try instant local match first
    final localResult = processCommand(
      rawInput: rawInput,
      contacts: contacts,
      nowProvider: nowProvider,
      locationProvider: locationProvider,
    );

    // If locally recognized, return immediately (zero latency)
    if (localResult is! VoiceCommandUnrecognized) {
      return localResult;
    }

    // 2. Fall back to Gemini AI if configured
    final geminiResult = await GeminiVoiceService.askGemini(
      userPrompt: rawInput,
      contacts: contacts,
    );

    if (geminiResult != null) {
      return geminiResult;
    }

    return localResult;
  }

  static VoiceCommandResult _lookupByName({
    required String nameQuery,
    required List<EmergencyContactModel> contacts,
  }) {
    if (contacts.isEmpty) {
      return VoiceCommandNotFound(
        query: nameQuery,
        message: 'No emergency contacts found. Would you like to add one?',
      );
    }

    // Strip words like "my" (e.g. "call my daughter", "call my son", "call my doctor")
    final normalizedQuery =
        nameQuery.replaceFirst(RegExp(r'^my\s+'), '').trim();

    // 1. Check exact name match or exact relationship match
    final exactMatches = contacts.where((c) {
      final name = c.name.toLowerCase();
      final rel = c.relationship.toLowerCase();
      return name == normalizedQuery || rel == normalizedQuery;
    }).toList();

    if (exactMatches.length == 1) {
      final contact = exactMatches.first;
      return VoiceCommandConfirmCall(
        contact: contact,
        prompt:
            'Found ${contact.name} (${contact.relationship}). Do you want to call ${contact.phoneNumber}?',
      );
    } else if (exactMatches.length > 1) {
      return VoiceCommandDisambiguate(
        query: nameQuery,
        matches: exactMatches,
        prompt:
            'Multiple contacts match "$nameQuery". Which one would you like to call?',
      );
    }

    // 2. Check substring or word token match
    final queryTokens = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1)
        .toList();

    final partialMatches = contacts.where((c) {
      final name = c.name.toLowerCase();
      final rel = c.relationship.toLowerCase();
      final nameTokens = name.split(RegExp(r'\s+'));

      final directSub = name.contains(normalizedQuery) ||
          normalizedQuery.contains(name) ||
          rel.contains(normalizedQuery);
      if (directSub) return true;

      // Token overlap (e.g., query "ravi" matches "Dr. Ravi Kumar")
      final tokenMatch = queryTokens.any((qt) => nameTokens.any((nt) =>
          nt == qt || nt.startsWith(qt) || qt.startsWith(nt)));
      return tokenMatch;
    }).toList();

    if (partialMatches.length == 1) {
      final contact = partialMatches.first;
      return VoiceCommandConfirmCall(
        contact: contact,
        prompt:
            'Found ${contact.name} (${contact.relationship}). Do you want to call ${contact.phoneNumber}?',
      );
    } else if (partialMatches.length > 1) {
      return VoiceCommandDisambiguate(
        query: nameQuery,
        matches: partialMatches,
        prompt:
            'I found multiple contacts matching "$nameQuery". Which person do you mean?',
      );
    }

    // 3. No match found
    return VoiceCommandNotFound(
      query: nameQuery,
      message:
          'I could not find "$nameQuery" in your saved emergency contacts.',
    );
  }

  /// Launch device phone dialer via standard `tel:` URI.
  static Future<bool> launchPhoneDialer(String phoneNumber) async {
    final cleanDigits = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanDigits.isEmpty) return false;

    final uri = Uri(scheme: 'tel', path: cleanDigits);
    try {
      final launched = await launchUrl(uri);
      return launched;
    } catch (e) {
      debugPrint('[VoiceCommandService] Failed to launch tel URI: $e');
      return false;
    }
  }
}
