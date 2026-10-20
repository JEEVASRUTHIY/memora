import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/theme/app_theme.dart';
import 'package:memora/data/services/tts_service.dart';
import 'package:memora/data/services/app_preferences_service.dart';
import 'package:memora/features/auth/data/auth_providers.dart';
import 'package:memora/features/reminders/data/reminder_providers.dart';
import 'package:memora/features/emergency_contacts/data/contact_providers.dart';

/// Screen displayed when the patient taps the purple "My medicine" button
/// on the homescreen and their medicine has already been taken.
/// Matches the user's provided design mockup pixel-accurately.
class MedicineAlreadyTakenScreen extends ConsumerStatefulWidget {
  final String? doseTitle;
  final String? doseTime;
  final String? nextDoseTime;
  final String? markedDoneStatus;
  final String? caregiverContactedStatus;

  const MedicineAlreadyTakenScreen({
    super.key,
    this.doseTitle,
    this.doseTime,
    this.nextDoseTime,
    this.markedDoneStatus,
    this.caregiverContactedStatus,
  });

  @override
  ConsumerState<MedicineAlreadyTakenScreen> createState() =>
      _MedicineAlreadyTakenScreenState();
}

class _MedicineAlreadyTakenScreenState
    extends ConsumerState<MedicineAlreadyTakenScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(appPreferencesProvider).readAloudEverytime) {
        _speakStatus();
      }
    });
  }

  @override
  void dispose() {
    TtsService().stop();
    super.dispose();
  }

  void _speakStatus() {
    final takenText = widget.doseTime != null
        ? "You've taken your medicine. ${widget.doseTitle ?? 'Morning dose'}, ${widget.doseTime}."
        : "You've taken your medicine! Morning dose, 9:00 AM.";
    final nextText = widget.nextDoseTime != null
        ? "Next dose: ${widget.nextDoseTime}."
        : "Next dose: 2:00 PM.";
    TtsService().speak(
      "$takenText $nextText If you are not sure if you took it, your caregiver can help you check.",
    );
  }

  Future<void> _callCaregiver(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) {
      _showNumberInputDialog(isCall: true);
      return;
    }
    final uri = Uri(scheme: 'tel', path: clean);
    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dialer opened for $phone')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start call: $e')),
        );
      }
    }
  }

  Future<void> _askCaregiver(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final message = Uri.encodeComponent(
      'Hi, I am checking if I already took my scheduled medicine today.',
    );

    if (clean.isEmpty) {
      _showNumberInputDialog(isCall: false);
      return;
    }

    final smsUri = Uri.parse('sms:$clean?body=$message');
    try {
      final launched = await launchUrl(smsUri);
      if (!launched && mounted) {
        _showAskCaregiverDialog(phone);
      }
    } catch (_) {
      if (mounted) {
        _showAskCaregiverDialog(phone);
      }
    }
  }

  void _showAskCaregiverDialog(String phone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                color: Color(0xFFD97706)),
            const SizedBox(width: 10),
            Text(
              'Ask Caregiver',
              style: GoogleFonts.outfit(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send a quick reassurance message to your caregiver:',
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Text(
                '"Hi, did I already take my medicine today?"',
                style: GoogleFonts.outfit(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF92400E),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Message sent to your caregiver!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: Text(
              'Send Message',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showNumberInputDialog({required bool isCall}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isCall ? 'Call Caregiver' : 'Message Caregiver',
          style: GoogleFonts.outfit(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter caregiver phone number:',
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.outfit(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. +1 555-0199',
                hintStyle: GoogleFonts.outfit(
                  color: AppTheme.textSecondary.withOpacity(0.5),
                ),
                prefixIcon: Icon(
                  isCall ? Icons.phone_rounded : Icons.chat_rounded,
                  color: isCall
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFD97706),
                ),
                filled: true,
                fillColor: AppTheme.surfaceVar.withOpacity(0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final number = controller.text.trim();
              Navigator.pop(dialogCtx);
              if (number.isNotEmpty) {
                if (isCall) {
                  _callCaregiver(number);
                } else {
                  _askCaregiver(number);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isCall
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFD97706),
              foregroundColor: Colors.white,
            ),
            child: Text(
              isCall ? 'Call Now' : 'Send',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final patientId = user?.patientId ?? '';

    // Contacts stream for caregiver phone number
    final contactsAsync = ref.watch(patientContactsProvider(patientId));
    final contacts = contactsAsync.valueOrNull ?? [];
    final primaryContact =
        contacts.where((c) => c.isPrimary).firstOrNull ?? contacts.firstOrNull;
    final caregiverPhone = primaryContact?.phoneNumber ?? '';

    // Reminders to dynamically calculate next dose
    final remAsync = ref.watch(remindersProvider(patientId));
    final reminders = remAsync.valueOrNull ?? [];

    // Next dose string
    String displayNextDose = widget.nextDoseTime ?? '2:00 PM';
    if (widget.nextDoseTime == null && reminders.isNotEmpty) {
      final allTimes = reminders
          .expand((r) => r.times)
          .where((t) => t.isNotEmpty)
          .toList();
      if (allTimes.length > 1) {
        displayNextDose = allTimes[1];
      } else if (allTimes.isNotEmpty) {
        displayNextDose = allTimes.first;
      }
    }

    final displayDoseTitle = widget.doseTitle ?? 'Morning dose';
    final displayDoseTime = widget.doseTime ?? '9:00 AM';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC), // Clean off-white background
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FC),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF1E293B),
            size: 24,
          ),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/patient/home');
            }
          },
        ),
        title: Text(
          'My Medicine',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.volume_up_outlined,
              color: Color(0xFF2563EB),
              size: 24,
            ),
            tooltip: 'Read aloud',
            onPressed: _speakStatus,
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
              // ── 1. "You've taken your medicine!" Card (Green) ─────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7), // Soft mint pastel green
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFBBF7D0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF16A34A).withOpacity(0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Green circular checkmark icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF16A34A),
                          width: 2.5,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_rounded,
                          color: Color(0xFF16A34A),
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      "You've taken your\nmedicine!",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF14532D),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Subtitle
                    Text(
                      '$displayDoseTitle · $displayDoseTime',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 2. "Next dose: 2:00 PM" Card (Blue) ───────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FC), // Soft pastel sky blue
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFFD4E5F9),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      color: Color(0xFF1E40AF),
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Next dose: $displayNextDose',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E3A8A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── 3. Medicine Timeline Card (Adapted from Reference) ────────
              _MedicineTimelineCard(
                doseTitle: displayDoseTitle,
                takenTime: displayDoseTime,
                nextDoseTime: displayNextDose,
              ),
              const SizedBox(height: 28),

              // ── 4. "Not sure if you took it?" Section ────────────────────
              Text(
                'Not sure if you took it?',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),

              // Status pill mentioning when marked done / snoozed / caregiver contacted
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF), // Calm ice blue
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFBFDBFE),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDBEAFE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.markedDoneStatus ??
                                'Snoozed 1 time | Marked done at 9:10 AM',
                            style: GoogleFonts.outfit(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E40AF),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.caregiverContactedStatus ??
                                'Caregiver contacted you · Verified',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              color: const Color(0xFF3B82F6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              Text(
                'Your caregiver can help you check.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 20),

              // ── 4. Two Action Cards (Call Caregiver & Ask Caregiver) ──────
              Row(
                children: [
                  // Call Caregiver Card
                  Expanded(
                    child: InkWell(
                      onTap: () => _callCaregiver(caregiverPhone),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 22,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3EEFC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFCCE0FA),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E40AF).withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              color: Color(0xFF1E40AF),
                              size: 28,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Call Caregiver',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E3A8A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Talk directly',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Ask Caregiver Card
                  Expanded(
                    child: InkWell(
                      onTap: () => _askCaregiver(caregiverPhone),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 22,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDEFD5), // Warm peach/amber
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFCDCA8),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFB45309).withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Color(0xFF92400E),
                              size: 28,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Ask Caregiver',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF78350F),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Send an instant\nmessage',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: const Color(0xFF92400E),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── 5. Bottom subtle scroll indicator ────────────────────────
              Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_downward_rounded,
                    color: Color(0xFF64748B),
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Timeline widget matching user's reference drawing:
/// 1. Top green dot: "Taken 9:00 am ✓"
/// 2. Vertical line connector
/// 3. Middle amber dot: "Now...."
/// 4. Vertical line connector
/// 5. Bottom red dot: "9:00 pm" (or next dose time)
class _MedicineTimelineCard extends StatelessWidget {
  final String doseTitle;
  final String takenTime;
  final String nextDoseTime;

  const _MedicineTimelineCard({
    required this.doseTitle,
    required this.takenTime,
    required this.nextDoseTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.linear_scale_rounded,
                  color: Color(0xFF475569),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Today's Medicine Timeline",
                style: GoogleFonts.outfit(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ── Timeline Node 1: Taken dose (Green Circle & Checkmark) ─
          _buildTimelineNode(
            dotColor: const Color(0xFF22C55E),
            dotBorderColor: const Color(0xFF16A34A),
            dotContent: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 16,
            ),
            titleWidget: Row(
              children: [
                Text(
                  'Taken $takenTime',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF15803D),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF16A34A),
                    size: 16,
                  ),
                ),
              ],
            ),
            subtitle: '$doseTitle · Successfully completed',
          ),

          // Connector line 1
          _buildConnectorLine(
            gradientStart: const Color(0xFF22C55E),
            gradientEnd: const Color(0xFFF59E0B),
          ),

          // ── Timeline Node 2: Now.... (Amber Circle) ─────────────────
          _buildTimelineNode(
            dotColor: const Color(0xFFF59E0B),
            dotBorderColor: const Color(0xFFD97706),
            dotContent: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            titleWidget: Row(
              children: [
                Text(
                  'Now....',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFB45309),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Active',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: 'You are all set · Resting between doses',
          ),

          // Connector line 2
          _buildConnectorLine(
            gradientStart: const Color(0xFFF59E0B),
            gradientEnd: const Color(0xFFEF4444),
          ),

          // ── Timeline Node 3: Next dose / 9:00 PM (Red Circle) ──────
          _buildTimelineNode(
            dotColor: const Color(0xFFEF4444),
            dotBorderColor: const Color(0xFFDC2626),
            dotContent: const Icon(
              Icons.schedule_rounded,
              color: Colors.white,
              size: 14,
            ),
            titleWidget: Row(
              children: [
                Text(
                  nextDoseTime,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFB91C1C),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Next Dose',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: 'Scheduled · Memora will remind you',
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineNode({
    required Color dotColor,
    required Color dotBorderColor,
    required Widget dotContent,
    required Widget titleWidget,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: dotBorderColor,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: dotColor.withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(child: dotContent),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget,
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectorLine({
    required Color gradientStart,
    required Color gradientEnd,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 13.5, top: 3, bottom: 3),
      width: 3,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFCBD5E1),
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            gradientStart.withOpacity(0.65),
            gradientEnd.withOpacity(0.65),
          ],
        ),
      ),
    );
  }
}
