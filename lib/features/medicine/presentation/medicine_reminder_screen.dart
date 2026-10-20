import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:memora/core/router/app_routes.dart';
import 'package:memora/data/services/tts_service.dart';
import 'package:memora/features/auth/data/auth_providers.dart';
import 'package:memora/features/reminders/data/reminder_providers.dart';
import 'package:memora/features/medicine/presentation/medicine_taken_confirmation_screen.dart';

/// The Medicine Page for patients.
/// Displays their current scheduled medicine, instructions,
/// and the prominent "I have taken it" button which navigates to the confirmation screen.
class MedicineReminderScreen extends ConsumerStatefulWidget {
  const MedicineReminderScreen({super.key});

  @override
  ConsumerState<MedicineReminderScreen> createState() =>
      _MedicineReminderScreenState();
}

class _MedicineReminderScreenState
    extends ConsumerState<MedicineReminderScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TtsService().speak(
        "Time for your medicine reminder. Donepezil five milligrams. When you have taken it, tap I have taken it.",
      );
    });
  }

  void _onTakenPressed({
    required BuildContext context,
    required String medicineName,
    required String nextTime,
  }) {
    // Navigate to the confirmation screen requested by the user
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicineTakenConfirmationScreen(
          medicineName: medicineName,
          nextReminderTime: nextTime,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final patientId = user?.patientId ?? '';
    final occAsync = ref.watch(actionableOccurrencesProvider(patientId));
    final remAsync = ref.watch(remindersProvider(patientId));

    final activeOcc = occAsync.valueOrNull?.firstOrNull;
    final remindersMap = remAsync.valueOrNull?.fold<Map<String, dynamic>>(
          {},
          (m, r) => m..[r.reminderId] = r,
        ) ??
        {};
    final activeReminder =
        activeOcc != null ? remindersMap[activeOcc.reminderId] : null;

    final medicineName = activeReminder?.title ?? 'Donepezil (Aricept) 5mg';
    final medicineNote = activeReminder?.note ??
        'Take 1 tablet with a full glass of water after breakfast.';
    final scheduledTime = activeOcc != null
        ? DateFormat('h:mm a').format(activeOcc.scheduledTime.toLocal())
        : '8:00 AM';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF334155)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.patientHome);
            }
          },
        ),
        title: Text(
          'Medicine Reminder',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF334155),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up_outlined, color: Color(0xFF334155)),
            tooltip: 'Read aloud',
            onPressed: () {
              TtsService().speak(
                'Medicine reminder for $medicineName. $medicineNote',
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Medicine Pill Card ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Pill / Medication Badge
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B4FBB).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.medication_rounded,
                          size: 38,
                          color: Color(0xFF6B4FBB),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      medicineName,
                      style: GoogleFonts.outfit(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        'Scheduled for $scheduledTime • Morning Dose',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            medicineNote,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              color: const Color(0xFF334155),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── "I have taken it" Primary Action Button ──────────────────
              ElevatedButton(
                onPressed: () {
                  // If there is an active occurrence in Firestore, confirm it
                  if (activeOcc != null && patientId.isNotEmpty) {
                    ref.read(reminderActionProvider(patientId).notifier).confirm(
                          activeOcc.copyWith(shownTime: DateTime.now()),
                        );
                  }
                  _onTakenPressed(
                    context: context,
                    medicineName: medicineName,
                    nextTime: '2:00 PM',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E824C),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: const Color(0xFF1E824C).withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'I have taken it',
                      style: GoogleFonts.outfit(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Snooze Secondary Action ───────────────────────────────────
              OutlinedButton.icon(
                onPressed: () {
                  if (activeOcc != null && patientId.isNotEmpty) {
                    ref.read(reminderActionProvider(patientId).notifier).snooze(
                          activeOcc.copyWith(shownTime: DateTime.now()),
                        );
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Snoozed for 10 minutes.'),
                      backgroundColor: Color(0xFF334155),
                    ),
                  );
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.snooze_rounded, size: 18),
                label: Text(
                  'Snooze 10 minutes',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
