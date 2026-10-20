import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:memora/core/router/app_routes.dart';
import 'package:memora/data/services/tts_service.dart';
import 'package:memora/data/services/app_preferences_service.dart';

/// Screen displayed after the patient taps "I have taken it".
/// Reassures the patient, reminds them to return their medicine to its usual place,
/// shows the photo of where the medicine should be kept, and speaks instructions aloud.
class MedicineTakenConfirmationScreen extends ConsumerStatefulWidget {
  final String medicineName;
  final String nextReminderTime;

  const MedicineTakenConfirmationScreen({
    super.key,
    this.medicineName = 'Daily Medicine',
    this.nextReminderTime = '2:00 PM',
  });

  @override
  ConsumerState<MedicineTakenConfirmationScreen> createState() =>
      _MedicineTakenConfirmationScreenState();
}

class _MedicineTakenConfirmationScreenState
    extends ConsumerState<MedicineTakenConfirmationScreen> {
  @override
  void initState() {
    super.initState();
    // Speak a gentle reassurance out loud if readAloudEverytime is enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(appPreferencesProvider).readAloudEverytime) {
        _speakHeader();
      }
    });
  }

  @override
  void dispose() {
    TtsService().stop();
    super.dispose();
  }

  void _speakHeader() {
    TtsService().speak(
      "Well done! You have marked your medicine as taken. Keep your medicine in its usual place.",
    );
  }

  void _speakUsualPlace() {
    TtsService().speak(
      "Keep your medicine in its usual place. This will help you find it easily next time.",
    );
  }

  @override
  Widget build(BuildContext context) {
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
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up_outlined, color: Color(0xFF334155)),
            tooltip: 'Read aloud',
            onPressed: _speakHeader,
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
              // ── 1. "Well done!" Green Banner ──────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2F7E4),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFF86EFAC).withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_circle_outline_rounded,
                          color: Color(0xFF1E824C),
                          size: 44,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Well done!',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF135A33),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "You've marked your medicine as taken.",
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: const Color(0xFF2E384D),
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── 2. "Keep your medicine in its usual place" Card ─────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
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
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Blue Storage Box Icon
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.inventory_2_outlined,
                          color: Color(0xFF2563EB),
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Keep your medicine in its usual place.',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                        height: 1.25,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'This will help you find it easily next time.',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        color: const Color(0xFF64748B),
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),

                    // Tap to hear aloud button
                    InkWell(
                      onTap: _speakUsualPlace,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.volume_up_rounded,
                              color: Color(0xFF2563EB),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tap to hear aloud',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ── Photo of Where the Medicine Should Be ─────────────────
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Image.asset(
                            'assets/images/medicine_location.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.network(
                                '/assets/images/medicine_location.jpg',
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Container(
                                  color: const Color(0xFFF1F5F9),
                                  child: const Center(
                                    child: Icon(
                                      Icons.medical_services_outlined,
                                      size: 48,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Location caption badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 15,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Usual place: Top shelf in medicine cabinet',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── 3. Done Action Button ─────────────────────────────────────
              ElevatedButton(
                onPressed: () {
                  TtsService().stop();
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.patientHome);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  'Done',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Down arrow indicator
              Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_downward_rounded,
                      size: 20,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Next reminder footer
              Text(
                'Next medicine reminder: ${widget.nextReminderTime}',
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
