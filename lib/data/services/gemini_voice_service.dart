import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:memora/core/app_config.dart';
import 'package:memora/data/models/emergency_contact_model.dart';
import 'package:memora/features/voice_assistant/data/voice_command_service.dart';

/// AI Voice Service supporting both NVIDIA NIM (`nvapi-...`) and Google Gemini (`AIzaSy...`)
/// for intelligent natural language understanding, dementia-friendly conversational
/// responses, time/date queries, and flexible emergency contact assistance.
class GeminiVoiceService {
  /// Primary dispatch method: automatically selects NVIDIA NIM or Google Gemini
  /// depending on the API key format in [AppConfig].
  static Future<VoiceCommandResult?> askGemini({
    required String userPrompt,
    required List<EmergencyContactModel> contacts,
    http.Client? httpClient,
  }) async {
    return askAi(
      userPrompt: userPrompt,
      contacts: contacts,
      httpClient: httpClient,
    );
  }

  /// Query the active LLM (NVIDIA NIM or Gemini) with the user's spoken words.
  static Future<VoiceCommandResult?> askAi({
    required String userPrompt,
    required List<EmergencyContactModel> contacts,
    http.Client? httpClient,
  }) async {
    final apiKey = AppConfig.activeAiApiKey.trim();
    if (apiKey.isEmpty) {
      return null;
    }

    if (AppConfig.isNvidiaKey) {
      return _askNvidiaNim(
        apiKey: apiKey,
        userPrompt: userPrompt,
        contacts: contacts,
        client: httpClient,
      );
    } else {
      return _askGemini(
        apiKey: apiKey,
        userPrompt: userPrompt,
        contacts: contacts,
      );
    }
  }

  /// NVIDIA NIM (Llama 3.2 11B Vision Instruct) chat completion.
  static Future<VoiceCommandResult?> _askNvidiaNim({
    required String apiKey,
    required String userPrompt,
    required List<EmergencyContactModel> contacts,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final shouldClose = client == null;

    try {
      final formattedNow =
          DateFormat('EEEE, MMMM d, y, h:mm a').format(DateTime.now());
      final systemPrompt = _buildSystemPrompt(
        nowString: formattedNow,
        contacts: contacts,
      );

      final uri =
          Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions');
      final payload = jsonEncode({
        'model': 'meta/llama-3.2-11b-vision-instruct',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': 0.3,
        'max_tokens': 120,
      });

      final response = await httpClient.post(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: payload,
      );

      if (response.statusCode != 200) {
        debugPrint(
            '[GeminiVoiceService/NVIDIA] HTTP ${response.statusCode}: ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        return null;
      }

      final message = choices.first['message'] as Map<String, dynamic>?;
      final text = (message?['content'] as String?)?.trim();
      if (text == null || text.isEmpty) {
        return null;
      }

      return VoiceCommandAnswer(
        title: 'Memora Voice Assistant',
        speechText: text,
        displayText: text,
        icon: Icons.auto_awesome_rounded,
      );
    } catch (e) {
      debugPrint('[GeminiVoiceService] Error querying NVIDIA NIM: $e');
      return null;
    } finally {
      if (shouldClose) {
        httpClient.close();
      }
    }
  }

  /// Google Gemini (gemini-1.5-flash) generation.
  static Future<VoiceCommandResult?> _askGemini({
    required String apiKey,
    required String userPrompt,
    required List<EmergencyContactModel> contacts,
  }) async {
    try {
      final formattedNow =
          DateFormat('EEEE, MMMM d, y, h:mm a').format(DateTime.now());
      final systemPrompt = _buildSystemPrompt(
        nowString: formattedNow,
        contacts: contacts,
      );

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(systemPrompt),
      );

      final response =
          await model.generateContent([Content.text(userPrompt)]);
      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        return null;
      }

      return VoiceCommandAnswer(
        title: 'Memora Voice Assistant',
        speechText: text,
        displayText: text,
        icon: Icons.auto_awesome_rounded,
      );
    } catch (e) {
      debugPrint('[GeminiVoiceService] Error querying Gemini: $e');
      return null;
    }
  }

  static String _buildSystemPrompt({
    required String nowString,
    required List<EmergencyContactModel> contacts,
  }) {
    final contactsContext = contacts.isEmpty
        ? 'No emergency contacts registered.'
        : contacts
            .map((c) =>
                '- ${c.name} (${c.relationship}): ${c.phoneNumber}${c.isPrimary ? ' [PRIMARY]' : ''}')
            .join('\n');

    return '''
You are Memora's gentle, reassuring voice assistant for patients with memory challenges (such as dementia) and their caregivers.
Current Date & Time: $nowString

Saved Emergency Contacts:
$contactsContext

Guidelines:
1. Keep responses short (1-2 sentences maximum), calm, clear, and reassuring.
2. If the user asks about the time, date, or day of the week, answer directly with the current date/time.
3. If the user asks who to call or about someone you know from their contacts, mention their name and relationship gently.
4. If the user is anxious or lost, reassure them calmly that they are safe.
5. Do NOT use markdown symbols, asterisks, bullet points, or complex sentences. Speak naturally aloud.
''';
  }
}
