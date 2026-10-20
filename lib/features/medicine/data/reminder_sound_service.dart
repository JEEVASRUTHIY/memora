import 'dart:async';
import 'package:flutter/services.dart';
import 'package:memora/data/services/tts_service.dart';

/// Sound notification service for incoming medicine reminders.
/// Plays sound and spoken announcements inside the app for 30 seconds
/// until user acts or timeout elapses.
class ReminderSoundService {
  static final ReminderSoundService _instance = ReminderSoundService._internal();
  factory ReminderSoundService() => _instance;
  ReminderSoundService._internal();

  Timer? _overallTimeoutTimer;
  Timer? _periodicSoundTimer;
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  /// Starts sound notification for 30 seconds
  void start30SecondsAlarm({
    required String announcementText,
    VoidCallback? onFinished,
  }) {
    stop();
    _isPlaying = true;

    // Play first sound and speak announcement
    _playChimeAndSpeak(announcementText);

    // Repeat every 7 seconds until 30 seconds elapse
    _periodicSoundTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }
      _playChimeAndSpeak(announcementText);
    });

    // 30-second overall timeout
    _overallTimeoutTimer = Timer(const Duration(seconds: 30), () {
      stop();
      if (onFinished != null) onFinished();
    });
  }

  void _playChimeAndSpeak(String text) {
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    } catch (_) {}
    TtsService().speak(text);
  }

  /// Stop sound notification immediately
  void stop() {
    _isPlaying = false;
    _periodicSoundTimer?.cancel();
    _periodicSoundTimer = null;
    _overallTimeoutTimer?.cancel();
    _overallTimeoutTimer = null;
    TtsService().stop();
  }
}
