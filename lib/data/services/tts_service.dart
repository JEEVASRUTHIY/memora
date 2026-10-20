import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-Speech service designed for dementia patients and caregivers,
/// featuring calm pacing, clear pronunciation, and cross-platform support.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _initialized = false;
  bool _isSpeaking = false;
  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(false);

  bool get isSpeaking => _isSpeaking;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await _flutterTts.setLanguage('en-US');
      // Slower, clearer rate for elderly/dementia accessibility
      await _flutterTts.setSpeechRate(kIsWeb ? 0.9 : 0.48);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        isSpeakingNotifier.value = true;
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        isSpeakingNotifier.value = false;
      });

      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        isSpeakingNotifier.value = false;
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('[TtsService] Error: $msg');
        _isSpeaking = false;
        isSpeakingNotifier.value = false;
      });

      _initialized = true;
    } catch (e) {
      debugPrint('[TtsService] Init error: $e');
    }
  }

  Future<void> speak(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;
    try {
      await init();
      await stop();
      _isSpeaking = true;
      isSpeakingNotifier.value = true;
      await _flutterTts.speak(cleanText);
    } catch (e) {
      debugPrint('[TtsService] Speak error: $e');
      _isSpeaking = false;
      isSpeakingNotifier.value = false;
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      isSpeakingNotifier.value = false;
    } catch (_) {}
  }
}
