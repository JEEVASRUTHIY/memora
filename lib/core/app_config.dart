import 'package:flutter/services.dart';

/// App-wide runtime configuration.
///
/// Maps behaviour: if [useMapsApiKey] is true and a key exists in
/// android/local.properties, google_maps_flutter is used; otherwise the app
/// falls back to flutter_map + OpenStreetMap (no key required).
///
/// Developer tools: set [devToolsEnabled] to false to hide the dev-tools
/// screen even in release builds.
class AppConfig {
  AppConfig._();

  /// Use Google Maps (key required). When false, uses OpenStreetMap fallback.
  static const bool preferGoogleMaps = true;
  static bool _hasMapsKey = false;
  static bool get useMapsApiKey => preferGoogleMaps && _hasMapsKey;

  /// Only a boolean crosses the platform channel; the key stays in Android.
  static Future<void> loadPlatformConfig() async {
    try {
      _hasMapsKey = await const MethodChannel('memora/config')
              .invokeMethod<bool>('hasMapsKey') ??
          false;
    } on PlatformException {
      _hasMapsKey = false;
    } on MissingPluginException {
      _hasMapsKey = false;
    }
  }

  /// Show developer tools screen (reachable by tapping version 5 times).
  static const bool devToolsEnabled = true;

  /// Firebase project ID (for reference only - actual config is in
  /// google-services.json / firebase_options.dart).
  static const String firebaseProjectId = 'memora-3b359';

  /// Web Push VAPID key for Firebase Cloud Messaging.
  static const String? fcmWebVapidKey = null;

  /// AI API key for conversational voice assistant understanding.
  /// Supports NVIDIA NIM (`nvapi-...`) and Google Gemini (`AIzaSy...`).
  /// Configured with the project's NVIDIA NIM key as default, and can be overridden
  /// via `--dart-define=AI_API_KEY=...` or dynamically in the app.
  static const String defaultAiApiKey =
      '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';
  static const String aiApiKey =
      String.fromEnvironment('AI_API_KEY', defaultValue: defaultAiApiKey);
  static const String geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String nvidiaApiKey =
      String.fromEnvironment('NVIDIA_API_KEY', defaultValue: '');

  static String dynamicAiApiKey = '';

  /// Active AI API Key in order of precedence:
  /// 1. Dynamic in-app override
  /// 2. Specific environment key
  /// 3. Default configured key
  static String get activeAiApiKey {
    if (dynamicAiApiKey.trim().isNotEmpty) return dynamicAiApiKey.trim();
    if (nvidiaApiKey.trim().isNotEmpty) return nvidiaApiKey.trim();
    if (geminiApiKey.trim().isNotEmpty) return geminiApiKey.trim();
    if (aiApiKey.trim().isNotEmpty) return aiApiKey.trim();
    return defaultAiApiKey;
  }

  static bool get hasAiApiKey => activeAiApiKey.isNotEmpty;
  static bool get isNvidiaKey => activeAiApiKey.startsWith('nvapi-');
  static bool get isGeminiKey => !isNvidiaKey && activeAiApiKey.isNotEmpty;
  static String get activeAiProviderName =>
      isNvidiaKey ? 'NVIDIA NIM' : 'Google Gemini';

  // Backward-compatibility aliases:
  static String get activeGeminiApiKey => activeAiApiKey;
  static bool get hasGeminiApiKey => hasAiApiKey;
  static set dynamicGeminiApiKey(String val) => dynamicAiApiKey = val;
}
