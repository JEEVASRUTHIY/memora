import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:memora/core/app_config.dart';
import 'package:memora/core/theme/app_theme.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/data/models/emergency_contact_model.dart';
import 'package:memora/data/services/tts_service.dart';
import 'package:memora/data/services/location_service.dart';
import 'package:memora/features/emergency_contacts/data/contact_providers.dart';
import 'package:memora/features/voice_assistant/data/voice_command_service.dart';

/// Distinct visual states for the Voice Assistant.
enum VoiceAssistantState {
  /// Purple microphone, no animation, "Tap to speak".
  idle,

  /// Red microphone, gentle pulsing ring, "Listening... Speak now", countdown & Stop button.
  listening,

  /// Neutral / purple indicator, "Understanding you...", prevents duplicate submissions.
  processing,

  /// "Memora is speaking...", Stop Speaking button.
  speaking,

  /// Clear explanation of error / permission, prominent Retry button.
  error,
}

/// Modal bottom sheet for the Voice Assistant with one-tap recording,
/// clear visual states, natural speech recognition time, Text-to-Speech playback,
/// and dementia-accessible controls.
class VoiceAssistantModal extends ConsumerStatefulWidget {
  final VoidCallback onOpenContacts;
  final bool autoStart;
  final stt.SpeechToText? speechToText;

  const VoiceAssistantModal({
    super.key,
    required this.onOpenContacts,
    this.autoStart = true,
    this.speechToText,
  });

  static Future<void> show({
    required BuildContext context,
    required VoidCallback onOpenContacts,
    bool autoStart = true,
    stt.SpeechToText? speechToText,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceAssistantModal(
        onOpenContacts: onOpenContacts,
        autoStart: autoStart,
        speechToText: speechToText,
      ),
    );
  }

  @override
  ConsumerState<VoiceAssistantModal> createState() =>
      _VoiceAssistantModalState();
}

class _VoiceAssistantModalState extends ConsumerState<VoiceAssistantModal>
    with SingleTickerProviderStateMixin {
  late final stt.SpeechToText _speech;
  late final AnimationController _pulseCtrl;

  VoiceAssistantState _state = VoiceAssistantState.idle;
  bool _speechEnabled = false;
  String _currentWords = '';
  VoiceCommandResult? _result;
  String? _errorMessage;
  int _remainingSeconds = 15;
  Timer? _countdownTimer;
  bool _hasProcessed = false;
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _speech = widget.speechToText ?? stt.SpeechToText();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    TtsService().init();
    TtsService().isSpeakingNotifier.addListener(_onTtsSpeakingChanged);

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startListening();
      });
    }
  }

  @override
  void dispose() {
    TtsService().isSpeakingNotifier.removeListener(_onTtsSpeakingChanged);
    TtsService().stop();
    _countdownTimer?.cancel();
    _speech.cancel();
    _pulseCtrl.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onTtsSpeakingChanged() {
    if (!mounted) return;
    if (!TtsService().isSpeaking && _state == VoiceAssistantState.speaking) {
      setState(() {
        _state = VoiceAssistantState.idle;
      });
    }
  }

  /// Check mic permission and initialize speech engine.
  Future<bool> _ensureSpeechReady() async {
    // 1. Mobile runtime permission check
    if (!kIsWeb) {
      try {
        final status = await Permission.microphone.status;
        if (!status.isGranted) {
          final req = await Permission.microphone.request();
          if (!req.isGranted) {
            if (mounted) {
              setState(() {
                _state = VoiceAssistantState.error;
                _errorMessage =
                    'Microphone access is needed for Memora to listen. Please allow microphone permission in your device settings.';
              });
            }
            return false;
          }
        }
      } catch (e) {
        debugPrint('[VoiceAssistant] Permission check error: $e');
      }
    }

    // 2. Initialize speech-to-text if not already enabled
    if (!_speechEnabled) {
      try {
        final available = await _speech.initialize(
          onStatus: _onSpeechStatus,
          onError: _onSpeechError,
        );
        _speechEnabled = available;
        if (!available) {
          if (mounted) {
            setState(() {
              _state = VoiceAssistantState.error;
              _errorMessage = kIsWeb
                  ? 'Speech recognition is not available in this browser. Please use Google Chrome or use the options below.'
                  : 'Speech recognition is not available on this device. You can type or tap an option below.';
            });
          }
          return false;
        }
      } catch (e) {
        debugPrint('[VoiceAssistant] Speech init exception: $e');
        if (mounted) {
          setState(() {
            _speechEnabled = false;
            _state = VoiceAssistantState.error;
            _errorMessage =
                'Could not initialize speech recognition. Tap Retry to try again.';
          });
        }
        return false;
      }
    }

    return true;
  }

  /// Start speech recognition with one tap.
  Future<void> _startListening() async {
    if (_state == VoiceAssistantState.listening) return;

    await TtsService().stop();
    _stopListeningTimer();
    _hasProcessed = false;

    final ready = await _ensureSpeechReady();
    if (!ready || !mounted) return;

    setState(() {
      _state = VoiceAssistantState.listening;
      _currentWords = '';
      _result = null;
      _errorMessage = null;
      _remainingSeconds = 15;
    });

    _pulseCtrl.repeat(reverse: true);
    _startCountdownTimer();

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _currentWords = result.recognizedWords;
          });
          // If the engine emits a final result with non-empty words, process once
          if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
            _handleRecognizedWords(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 15),
        // 5s silence pause gives dementia patients ample time to pause and think
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (e) {
      debugPrint('[VoiceAssistant] Listen error: $e');
      _stopListeningTimer();
      if (mounted) {
        setState(() {
          _state = VoiceAssistantState.error;
          _errorMessage =
              'Could not start listening. Please tap Retry to try again.';
        });
      }
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _remainingSeconds = 15;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds > 1) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        _stopListeningAndProcess();
      }
    });
  }

  void _stopListeningTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _pulseCtrl.stop();
    _pulseCtrl.reset();
  }

  void _onSpeechStatus(String status) {
    debugPrint('[VoiceAssistant] Speech status: $status');
    if (status == 'done' || status == 'notListening') {
      if (_state == VoiceAssistantState.listening) {
        _stopListeningTimer();
        if (_currentWords.trim().isNotEmpty && !_hasProcessed) {
          _handleRecognizedWords(_currentWords);
        } else if (!_hasProcessed) {
          if (mounted) {
            setState(() {
              _state = VoiceAssistantState.error;
              _errorMessage = "I didn't hear anything. Tap to speak again.";
            });
          }
        }
      }
    } else if (status == 'listening') {
      if (mounted && _state != VoiceAssistantState.listening) {
        setState(() => _state = VoiceAssistantState.listening);
        _pulseCtrl.repeat(reverse: true);
      }
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    debugPrint('[VoiceAssistant] Speech error: ${error.errorMsg}');
    _stopListeningTimer();
    if (!mounted) return;

    if (_hasProcessed) return;

    // If words were captured before error/timeout, process them
    if (_currentWords.trim().isNotEmpty) {
      _handleRecognizedWords(_currentWords);
      return;
    }

    String message;
    if (error.errorMsg == 'error_speech_timeout' ||
        error.errorMsg == 'error_no_match') {
      message = "I didn't hear anything. Tap to speak again.";
    } else if (error.errorMsg == 'error_permission') {
      message =
          'Microphone permission was denied. Please allow microphone access in your browser or device settings.';
    } else if (error.errorMsg == 'error_busy') {
      message =
          'The microphone is currently busy. Please wait a moment and tap Retry.';
    } else if (error.errorMsg == 'error_network') {
      message =
          'Network connection issue for speech recognition. Tap Retry to try again.';
    } else {
      message = 'Could not hear clearly. Tap Retry to try again.';
    }

    setState(() {
      _state = VoiceAssistantState.error;
      _errorMessage = message;
    });
  }

  /// Stop listening manually and process recognized speech immediately.
  Future<void> _stopListeningAndProcess() async {
    _stopListeningTimer();
    try {
      await _speech.stop();
    } catch (_) {}

    if (!mounted) return;

    if (_currentWords.trim().isNotEmpty && !_hasProcessed) {
      _handleRecognizedWords(_currentWords);
    } else if (!_hasProcessed) {
      setState(() {
        _state = VoiceAssistantState.idle;
      });
    }
  }

  /// Stop ongoing text-to-speech response.
  Future<void> _stopSpeaking() async {
    await TtsService().stop();
    if (mounted) {
      setState(() {
        _state = VoiceAssistantState.idle;
      });
    }
  }

  /// Process recognized voice command with strict single-execution guarantee.
  Future<void> _handleRecognizedWords(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    if (_hasProcessed && _state == VoiceAssistantState.processing) return;

    _hasProcessed = true;
    _stopListeningTimer();
    try {
      await _speech.stop();
    } catch (_) {}

    await TtsService().stop();

    if (!mounted) return;
    setState(() {
      _currentWords = clean;
      _state = VoiceAssistantState.processing;
      _result = null;
      _errorMessage = null;
    });

    List<EmergencyContactModel> contacts =
        ref.read(currentEmergencyContactsProvider).valueOrNull ?? [];
    if (contacts.isEmpty) {
      try {
        contacts = await ref
            .read(currentEmergencyContactsProvider.future)
            .timeout(const Duration(milliseconds: 300));
      } catch (_) {}
    }
    final res = await VoiceCommandService.processCommandAsync(
      rawInput: clean,
      contacts: contacts,
      locationProvider: () =>
          ref.read(locationServiceProvider).getCurrentLocation(),
    );

    if (!mounted) return;
    setState(() {
      _result = res;
      _state = VoiceAssistantState.speaking;
    });

    // Speak response out loud using TTS for accessibility
    _speakResult(res);
  }

  void _speakResult(VoiceCommandResult result) {
    switch (result) {
      case VoiceCommandLocationResult r:
        TtsService().speak(r.speechText);
        break;
      case VoiceCommandAnswer r:
        TtsService().speak(r.speechText);
        break;
      case VoiceCommandConfirmCall r:
        TtsService().speak(r.prompt);
        break;
      case VoiceCommandDisambiguate r:
        TtsService().speak(r.prompt);
        break;
      case VoiceCommandShowContacts r:
        TtsService().speak(r.message);
        break;
      case VoiceCommandNotFound r:
        TtsService().speak(r.message);
        break;
      case VoiceCommandEmptyContacts r:
        TtsService().speak(r.message);
        break;
      case VoiceCommandUnrecognized r:
        TtsService().speak(r.message);
        break;
    }
  }

  Future<void> _executeCall(EmergencyContactModel contact) async {
    await TtsService().stop();
    await VoiceCommandService.launchPhoneDialer(contact.phoneNumber);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Opening dialer for ${contact.name} (${contact.phoneNumber})',
          ),
          backgroundColor: AppTheme.surface,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  void _openGeminiConfigDialog() {
    final ctrl = TextEditingController(text: AppConfig.activeAiApiKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded,
                color: AppTheme.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'AI Assistant Configuration',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Provide your NVIDIA NIM API key (nvapi-...) or Google Gemini key (AIzaSy...) to enable conversational speech understanding, patient reassurance, and context-aware answers.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Active Provider: ${AppConfig.activeAiProviderName}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'API Key (NVIDIA or Gemini)',
                hintText: 'nvapi-... or AIzaSy...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                AppConfig.dynamicAiApiKey = ctrl.text.trim();
              });
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppConfig.hasAiApiKey
                        ? '${AppConfig.activeAiProviderName} activated!'
                        : 'AI API key cleared.',
                  ),
                  backgroundColor: AppTheme.surface,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Save Key',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currentEmergencyContactsProvider);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),

            // Header & AI Status Badge + Close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mic_rounded,
                        color: AppTheme.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Memora Voice',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: _openGeminiConfigDialog,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppConfig.hasAiApiKey
                              ? const Color(0xFF10B981).withOpacity(0.14)
                              : AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppConfig.hasAiApiKey
                                ? const Color(0xFF10B981).withOpacity(0.4)
                                : AppTheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 14,
                              color: AppConfig.hasAiApiKey
                                  ? const Color(0xFF10B981)
                                  : AppTheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              AppConfig.hasAiApiKey
                                  ? '${AppConfig.activeAiProviderName} Active'
                                  : 'Set AI Key',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppConfig.hasAiApiKey
                                    ? const Color(0xFF10B981)
                                    : AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      tooltip: 'Close',
                      color: AppTheme.textSecondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // State visual representation: Mic Button / Pulsing Ring / Spinners
            _buildStateVisual(),

            const SizedBox(height: 16),

            // Dynamic State Labels & Action Controls
            _buildStateControls(),

            const SizedBox(height: 16),

            // Transcript text display (shows words spoken live)
            if (_currentWords.isNotEmpty) _buildTranscriptBox(),

            // Result Content
            if (_result != null) _buildResultView(context, _result!),

            // Quick command chips (ensures full testability and instant answers)
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Try asking:',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CommandChip(
                  icon: Icons.access_time_rounded,
                  label: "What's the time now?",
                  onTap: _state == VoiceAssistantState.processing
                      ? () {}
                      : () =>
                          _handleRecognizedWords("what's the time now"),
                ),
                _CommandChip(
                  icon: Icons.calendar_today_rounded,
                  label: "What's today's date?",
                  onTap: _state == VoiceAssistantState.processing
                      ? () {}
                      : () =>
                          _handleRecognizedWords("what's today's date"),
                ),
                _CommandChip(
                  icon: Icons.call_rounded,
                  label: 'Call my emergency contact',
                  onTap: _state == VoiceAssistantState.processing
                      ? () {}
                      : () =>
                          _handleRecognizedWords('Call my emergency contact'),
                ),
                _CommandChip(
                  icon: Icons.contact_phone_rounded,
                  label: 'Show emergency contacts',
                  onTap: _state == VoiceAssistantState.processing
                      ? () {}
                      : () =>
                          _handleRecognizedWords('Show my emergency contacts'),
                ),
                _CommandChip(
                  icon: Icons.place_rounded,
                  label: 'Where am I?',
                  onTap: _state == VoiceAssistantState.processing
                      ? () {}
                      : () => _handleRecognizedWords('Where am I?'),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Text input fallback for accessibility or typing
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: GoogleFonts.outfit(fontSize: 13.5),
                    enabled: _state != VoiceAssistantState.processing,
                    decoration: InputDecoration(
                      hintText: 'Type: "What time is it?" or "Call Ravi"…',
                      hintStyle: GoogleFonts.outfit(fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (text) {
                      if (text.trim().isNotEmpty) {
                        _handleRecognizedWords(text);
                        _textController.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const ValueKey('voice_assistant_send_text_btn'),
                  onPressed: _state == VoiceAssistantState.processing
                      ? null
                      : () {
                          if (_textController.text.trim().isNotEmpty) {
                            _handleRecognizedWords(_textController.text);
                            _textController.clear();
                          }
                        },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppColors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the central visual widget depending on state.
  Widget _buildStateVisual() {
    switch (_state) {
      case VoiceAssistantState.listening:
        return GestureDetector(
          onTap: _stopListeningAndProcess,
          child: AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              final pulse = _pulseCtrl.value;
              return SizedBox(
                width: 124,
                height: 124,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer gentle pulsing ring (no strobe or harsh flash)
                    Container(
                      width: 92 + (pulse * 28),
                      height: 92 + (pulse * 28),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFDC2626)
                              .withOpacity((1.0 - pulse) * 0.45),
                          width: 3.5,
                        ),
                      ),
                    ),
                    // Inner clear red microphone button
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFDC2626),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC2626).withOpacity(0.45),
                            blurRadius: 20,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.mic_rounded,
                        color: Colors.white,
                        size: 46,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );

      case VoiceAssistantState.processing:
        return Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primary.withOpacity(0.12),
            border: Border.all(
              color: AppTheme.primary.withOpacity(0.35),
              width: 2.5,
            ),
          ),
          child: const Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: AppTheme.primary,
              ),
            ),
          ),
        );

      case VoiceAssistantState.speaking:
        return GestureDetector(
          onTap: _stopSpeaking,
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF10B981).withOpacity(0.15),
              border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.45),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.volume_up_rounded,
              color: Color(0xFF10B981),
              size: 46,
            ),
          ),
        );

      case VoiceAssistantState.error:
        return GestureDetector(
          onTap: _startListening,
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.error.withOpacity(0.12),
              border: Border.all(
                color: AppTheme.error.withOpacity(0.35),
                width: 2.5,
              ),
            ),
            child: const Icon(
              Icons.mic_off_rounded,
              color: AppTheme.error,
              size: 44,
            ),
          ),
        );

      case VoiceAssistantState.idle:
        return GestureDetector(
          onTap: _startListening,
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.35),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.mic_rounded,
              color: AppColors.white,
              size: 46,
            ),
          ),
        );
    }
  }

  /// Builds state labels and action buttons (Stop, Stop Speaking, Retry).
  Widget _buildStateControls() {
    switch (_state) {
      case VoiceAssistantState.listening:
        return Column(
          children: [
            Text(
              'Listening... Speak now',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Time remaining: ${_remainingSeconds}s',
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _remainingSeconds / 15.0,
                  backgroundColor: const Color(0xFFFEE2E2),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFFDC2626)),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              key: const ValueKey('voice_assistant_stop_btn'),
              onPressed: _stopListeningAndProcess,
              icon: const Icon(Icons.stop_rounded, size: 22),
              label: Text(
                'Stop',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
            ),
          ],
        );

      case VoiceAssistantState.processing:
        return Column(
          children: [
            Text(
              'Understanding you...',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Finding the best answer for you',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        );

      case VoiceAssistantState.speaking:
        return Column(
          children: [
            Text(
              'Memora is speaking...',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Listen to the answer aloud',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              key: const ValueKey('voice_assistant_stop_speaking_btn'),
              onPressed: _stopSpeaking,
              icon: const Icon(Icons.volume_off_rounded, size: 20),
              label: Text(
                'Stop Speaking',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.surfaceVar,
                foregroundColor: AppTheme.textPrimary,
                side: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        );

      case VoiceAssistantState.error:
        return Column(
          children: [
            Text(
              'Could Not Hear You',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage ??
                    "I didn't hear anything. Tap Retry to speak again.",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              key: const ValueKey('voice_assistant_retry_btn'),
              onPressed: _startListening,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(
                'Retry',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
            ),
          ],
        );

      case VoiceAssistantState.idle:
        return Column(
          children: [
            Text(
              'Tap to speak',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap the microphone when you want to speak',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildTranscriptBox() {
    final isListening = _state == VoiceAssistantState.listening;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVar.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isListening
              ? const Color(0xFFDC2626).withOpacity(0.3)
              : AppTheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isListening
                    ? Icons.record_voice_over_rounded
                    : Icons.check_circle_outline_rounded,
                size: 16,
                color:
                    isListening ? const Color(0xFFDC2626) : AppTheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                isListening ? 'Hearing you say:' : 'You said:',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '"$_currentWords"',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(BuildContext context, VoiceCommandResult result) {
    if (result is VoiceCommandLocationResult) {
      final isHome = result.isAtHome;
      final accentColor =
          isHome ? const Color(0xFF16A34A) : const Color(0xFFEA580C);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isHome
              ? const Color(0xFFDCFCE7).withOpacity(0.7)
              : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHome ? const Color(0xFF86EFAC) : const Color(0xFFFDBA74),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isHome
                        ? const Color(0xFFBBF7D0)
                        : const Color(0xFFFFEDD5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isHome ? Icons.home_rounded : Icons.location_on_rounded,
                    color: accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.title,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isHome
                              ? const Color(0xFF14532D)
                              : const Color(0xFF9A3412),
                        ),
                      ),
                      Text(
                        isHome ? 'Safe & Sound' : 'Away from Home',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          color: isHome
                              ? const Color(0xFF15803D)
                              : const Color(0xFFC2410C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Read aloud again',
                  icon: Icon(Icons.volume_up_rounded, color: accentColor),
                  onPressed: () => TtsService().speak(result.speechText),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              result.displayText,
              style: GoogleFonts.outfit(
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
            if (!isHome && result.emergencyContact != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEA580C).withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      result.callPrompt ??
                          'Would you like to call your emergency contact?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF7C2D12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () => _executeCall(result.emergencyContact!),
                      icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
                      label: Text(
                        'Yes, Call ${result.emergencyContact!.name}',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (result is VoiceCommandAnswer) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primary.withOpacity(0.35),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(result.icon, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Read aloud again',
                  icon: const Icon(Icons.volume_up_rounded,
                      color: AppTheme.primary),
                  onPressed: () => TtsService().speak(result.speechText),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              result.displayText,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    if (result is VoiceCommandConfirmCall) {
      final contact = result.contact;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF10B981).withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.phone_in_talk_rounded,
                    color: Color(0xFF10B981), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Confirm Call',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Repeat audio',
                  icon: const Icon(Icons.volume_up_rounded,
                      color: Color(0xFF10B981)),
                  onPressed: () => TtsService().speak(result.prompt),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              result.prompt,
              style: GoogleFonts.outfit(
                fontSize: 15,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      TtsService().stop();
                      setState(() => _result = null);
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _executeCall(contact),
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: Text(
                      'Call ${contact.name.split(' ').first}',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: AppColors.white,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (result is VoiceCommandDisambiguate) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primary.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    result.prompt,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Repeat audio',
                  icon: const Icon(Icons.volume_up_rounded,
                      color: AppTheme.primary),
                  onPressed: () => TtsService().speak(result.prompt),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...result.matches.map((contact) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  tileColor: AppTheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withOpacity(0.15),
                    child: Text(
                      contact.name.isNotEmpty ? contact.name[0] : '?',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  title: Text(
                    contact.name,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    '${contact.relationship} • ${contact.phoneNumber}',
                    style: GoogleFonts.outfit(fontSize: 13),
                  ),
                  trailing: const Icon(Icons.call_rounded,
                      color: Color(0xFF10B981)),
                  onTap: () {
                    final prompt =
                        'Selected ${contact.name} (${contact.relationship}). Call ${contact.phoneNumber}?';
                    TtsService().speak(prompt);
                    setState(() {
                      _result = VoiceCommandConfirmCall(
                        contact: contact,
                        prompt: prompt,
                      );
                    });
                  },
                ),
              );
            }),
          ],
        ),
      );
    }

    if (result is VoiceCommandShowContacts) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              result.message,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                TtsService().stop();
                Navigator.of(context).pop();
                widget.onOpenContacts();
              },
              icon: const Icon(Icons.contact_phone_rounded, size: 18),
              label: Text(
                'Open Emergency Contacts',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppColors.white,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (result is VoiceCommandNotFound ||
        result is VoiceCommandEmptyContacts ||
        result is VoiceCommandUnrecognized) {
      final message = switch (result) {
        VoiceCommandNotFound r => r.message,
        VoiceCommandEmptyContacts r => r.message,
        VoiceCommandUnrecognized r => r.message,
        _ => '',
      };

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.error.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppTheme.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Repeat audio',
                  icon: const Icon(Icons.volume_up_rounded,
                      color: AppTheme.error),
                  onPressed: () => TtsService().speak(message),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                TtsService().stop();
                Navigator.of(context).pop();
                widget.onOpenContacts();
              },
              icon: const Icon(Icons.contact_phone_outlined, size: 18),
              label: Text(
                'Go to Emergency Contacts',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.surface,
                foregroundColor: AppTheme.primary,
                minimumSize: const Size(0, 44),
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox();
  }
}

class _CommandChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  const _CommandChip({
    required this.label,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon ?? Icons.play_arrow_rounded,
          size: 16, color: AppTheme.primary),
      label: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 12.5,
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: AppTheme.surfaceVar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.white.withOpacity(0.08)),
      ),
    );
  }
}
