import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:memora/core/router/app_routes.dart';
import 'package:memora/data/models/reminder_models.dart';
import 'package:memora/data/services/tts_service.dart';
import 'package:memora/features/auth/data/auth_providers.dart';
import 'package:memora/features/reminders/data/reminder_providers.dart';
import 'package:memora/features/medicine/data/medicine_photo_service.dart';
import 'package:memora/features/medicine/data/reminder_sound_service.dart';
import 'package:memora/features/medicine/presentation/medicine_taken_confirmation_screen.dart';

/// Single incoming medicine reminder screen.
/// Shown when a reminder triggers, with:
/// - Sound notification inside app for 30 seconds
/// - Read aloud spoken announcement
/// - Photo showing where the medicine is kept (caregiver editable)
/// - "I've Done It" button leading to confirmation
/// - "Remind Me Again" button with 5-minute snooze and snooze count tracking
class MedicineIncomingReminderScreen extends ConsumerStatefulWidget {
  final ReminderOccurrenceModel? occurrence;
  final ReminderModel? reminder;
  final bool autoStartSound;

  const MedicineIncomingReminderScreen({
    super.key,
    this.occurrence,
    this.reminder,
    this.autoStartSound = true,
  });

  @override
  ConsumerState<MedicineIncomingReminderScreen> createState() =>
      _MedicineIncomingReminderScreenState();
}

class _MedicineIncomingReminderScreenState
    extends ConsumerState<MedicineIncomingReminderScreen> {
  int _soundSecondsRemaining = 30;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    if (widget.autoStartSound) {
      _startSoundAlert();
    }
  }

  void _startSoundAlert() {
    final title = widget.reminder?.title ?? 'Daily Medicine';
    final announcement =
        'Time for your medicine: $title. Please take your scheduled medicine. Photo showing where the medicine is kept.';

    ReminderSoundService().start30SecondsAlarm(
      announcementText: announcement,
      onFinished: () {
        if (mounted) {
          setState(() => _soundSecondsRemaining = 0);
        }
      },
    );

    _soundSecondsRemaining = 30;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_soundSecondsRemaining <= 1) {
        timer.cancel();
        setState(() => _soundSecondsRemaining = 0);
      } else {
        setState(() => _soundSecondsRemaining--);
      }
    });
  }

  void _stopSound() {
    ReminderSoundService().stop();
    TtsService().stop();
    _countdownTimer?.cancel();
    if (mounted) {
      setState(() => _soundSecondsRemaining = 0);
    }
  }

  void _readAloud() {
    final title = widget.reminder?.title ?? 'Daily Medicine';
    TtsService().speak(
      'Time for your medicine: $title. Please take your scheduled medicine. Photo showing where your medicine is kept.',
    );
  }

  Future<void> _onDonePressed() async {
    _stopSound();
    final user = ref.read(currentUserProvider).valueOrNull;
    final patientId = user?.patientId ?? '';

    final occAsync = ref.read(actionableOccurrencesProvider(patientId));
    final effectiveOcc = widget.occurrence ?? occAsync.valueOrNull?.firstOrNull;

    final remAsync = ref.read(remindersProvider(patientId));
    final effectiveRem = widget.reminder ??
        (effectiveOcc != null
            ? remAsync.valueOrNull
                ?.where((r) => r.reminderId == effectiveOcc.reminderId)
                .firstOrNull
            : null);

    // Mark as confirmed in Firestore if active occurrence exists
    if (effectiveOcc != null && patientId.isNotEmpty) {
      await ref.read(reminderActionProvider(patientId).notifier).confirm(
            effectiveOcc.copyWith(shownTime: DateTime.now()),
          );
    }

    if (!mounted) return;

    // Navigate to "Well done!" screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MedicineTakenConfirmationScreen(
          medicineName: effectiveRem?.title ?? 'Daily Medicine',
          nextReminderTime: '2:00 PM',
        ),
      ),
    );
  }

  Future<void> _onRemindMeAgainPressed() async {
    _stopSound();
    final user = ref.read(currentUserProvider).valueOrNull;
    final patientId = user?.patientId ?? '';

    final occAsync = ref.read(actionableOccurrencesProvider(patientId));
    final effectiveOcc = widget.occurrence ?? occAsync.valueOrNull?.firstOrNull;

    // Snooze for 5 minutes as requested
    if (effectiveOcc != null && patientId.isNotEmpty) {
      await ref.read(reminderActionProvider(patientId).notifier).snooze(
            effectiveOcc.copyWith(shownTime: DateTime.now()),
          );
    }

    if (!mounted) return;

    final count = (effectiveOcc?.snoozeCount ?? 0) + 1;
    final plural = count == 1 ? 'time' : 'times';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Snoozed for 5 minutes (snoozed $count $plural already). We will remind you again.',
        ),
        backgroundColor: const Color(0xFF1E293B),
        duration: const Duration(seconds: 4),
      ),
    );

    // Return to home screen
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.patientHome);
    }
  }

  @override
  void dispose() {
    _stopSound();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final patientId = user?.patientId ?? '';

    final occAsync = ref.watch(actionableOccurrencesProvider(patientId));
    final remAsync = ref.watch(remindersProvider(patientId));

    final occ = widget.occurrence ?? occAsync.valueOrNull?.firstOrNull;
    final rem = widget.reminder ??
        (occ != null
            ? remAsync.valueOrNull
                ?.where((r) => r.reminderId == occ.reminderId)
                .firstOrNull
            : null);
    final snoozeCount = occ?.snoozeCount ?? 0;

    final scheduledTimeStr = occ != null
        ? DateFormat('h:mm a').format(occ.scheduledTime.toLocal())
        : (rem?.times.isNotEmpty == true ? rem!.times.first : '9:00 AM');

    final medicineSubtitle = rem?.note ?? 'Please take your scheduled medicine.';

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7), // Warm light background from mockup
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header & Sound Notification Status Bar ───────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_soundSecondsRemaining > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.volume_up_rounded,
                              size: 14, color: Color(0xFFE11D48)),
                          const SizedBox(width: 4),
                          Text(
                            'Sound active (${_soundSecondsRemaining}s)',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFE11D48),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _readAloud,
                        icon: const Icon(Icons.volume_up_outlined,
                            color: Color(0xFF1E293B)),
                        tooltip: 'Read aloud',
                      ),
                      IconButton(
                        onPressed: () {
                          _stopSound();
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(AppRoutes.patientHome);
                          }
                        },
                        icon: const Icon(Icons.close_rounded,
                            color: Color(0xFF64748B)),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Top Title Row with Pill Icon ──────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Soft peach/pink square with red pill outline icon
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECE8),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFFFD4CC),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.medication_outlined,
                        color: Color(0xFFE11D48),
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Time for your\nmedicine',
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          medicineSubtitle,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            color: const Color(0xFF475569),
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          scheduledTimeStr,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Snooze count alert chip if already snoozed
              if (snoozeCount > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFCD34D),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 16, color: Color(0xFFB45309)),
                      const SizedBox(width: 8),
                      Text(
                        'snoozed $snoozeCount ${snoozeCount == 1 ? 'time' : 'times'} already',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Middle Card: "Photo showing where the medicine is kept" ───
              StreamBuilder<Map<String, String>>(
                stream:
                    MedicinePhotoService().watchLocationPhoto(patientId),
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  final photoUrl = data?['photoUrl'] ??
                      MedicinePhotoService().currentPhotoUrl;
                  final desc = data?['description'] ??
                      MedicinePhotoService().currentDescription;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.image_outlined,
                              size: 22,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Photo showing where the\nmedicine is kept',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E293B),
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // The Photo Display
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: AspectRatio(
                            aspectRatio: 16 / 11,
                            child: photoUrl.startsWith('http')
                                ? Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _fallbackImage(),
                                  )
                                : Image.asset(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Image.network(
                                      '/assets/images/medicine_location.jpg',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _fallbackImage(),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Storage location label
                        Text(
                          '📍 $desc',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── Button 1: "I've Done It" ──────────────────────────────────
              ElevatedButton(
                onPressed: _onDonePressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E824C), // Green from mockup
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  "I've Done It",
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Button 2: "Remind Me Again" ───────────────────────────────
              OutlinedButton(
                onPressed: _onRemindMeAgainPressed,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Remind Me Again',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackImage() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(
          Icons.medical_services_outlined,
          size: 44,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }
}
