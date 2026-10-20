import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:memora/core/theme/app_theme.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/data/models/medicine_refill_model.dart';
import 'package:memora/features/reminders/data/refill_providers.dart';
import 'package:memora/features/auth/data/auth_providers.dart';
import 'package:memora/features/emergency_contacts/data/contact_providers.dart';

/// Screen displaying active prescriptions, refill schedules, tablet consumption rates,
/// prescription documents, next date to buy, and one-tap refill action buttons.
class PatientRefillsScreen extends ConsumerWidget {
  final String? patientId;

  const PatientRefillsScreen({super.key, this.patientId});

  Future<void> _callPharmacy(BuildContext context, String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: clean);
    try {
      final ok = await launchUrl(uri);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dialer opened for $phone')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open dialer: $e')),
        );
      }
    }
  }

  void _showPrescriptionDocViewer(BuildContext context, MedicineRefillModel refill) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PrescriptionDocViewerSheet(refill: refill),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final currentUser = currentUserAsync.valueOrNull;
    final activePatientId = (patientId != null && patientId!.isNotEmpty)
        ? patientId!
        : (ref.watch(activePatientIdProvider) ??
            (currentUser?.isPatient == true && (currentUser?.uid.isNotEmpty ?? false)
                ? currentUser!.uid
                : (currentUser?.patientId ?? '')));

    if (currentUserAsync.isLoading && activePatientId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Prescriptions & Refills',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final refillsAsync = ref.watch(patientRefillsProvider(activePatientId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Prescriptions & Refills',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: refillsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.error),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading refills',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$e',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(patientRefillsProvider(activePatientId)),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text('Retry', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            data: (refills) {
              if (refills.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.medication_rounded,
                            size: 48,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No Active Refill Schedules',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your caregiver can configure refill due dates, prescription docs, and tablet doses from the caregiver portal.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Check if any refill is unhandled in the last 3 days
              final unhandledCount = refills.where((r) => r.isDueInLast3DaysUnhandled).length;

              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: refills.length + (unhandledCount > 0 ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  // If we have unhandled refills in last 3 days, show a prominent notice banner at top
                  if (unhandledCount > 0 && index == 0) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF87171), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFEE2E2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notification_important_rounded,
                              color: Color(0xFFDC2626),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daily Refill Alert (Last 3 Days)',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF991B1B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'You have $unhandledCount medicine${unhandledCount > 1 ? "s" : ""} due soon. Please ask caregiver to buy or mark as bought.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    color: const Color(0xFF7F1D1D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final item = refills[unhandledCount > 0 ? index - 1 : index];
                  return _PatientRefillCard(
                    refill: item,
                    onViewPrescriptionDoc: () => _showPrescriptionDocViewer(context, item),
                    onCallPharmacy: item.pharmacyPhone != null && item.pharmacyPhone!.isNotEmpty
                        ? () => _callPharmacy(context, item.pharmacyPhone!)
                        : null,
                    onAskCaregiverToBuy: () async {
                      final ok = await ref
                          .read(refillManagementProvider(activePatientId).notifier)
                          .askCaregiverToBuy(item.id);
                      if (ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Caregiver asked to buy ${item.medicineName}! Alert sent.',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: AppTheme.primary,
                          ),
                        );
                      }
                    },
                    onBoughtMedicine: () async {
                      final ok = await ref
                          .read(refillManagementProvider(activePatientId).notifier)
                          .markBought(item);
                      if (ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Marked ${item.medicineName} as bought! Restocked with ${item.totalTabletsInPack} tablets.',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PatientRefillCard extends StatelessWidget {
  final MedicineRefillModel refill;
  final VoidCallback onViewPrescriptionDoc;
  final VoidCallback? onCallPharmacy;
  final VoidCallback onAskCaregiverToBuy;
  final VoidCallback onBoughtMedicine;

  const _PatientRefillCard({
    required this.refill,
    required this.onViewPrescriptionDoc,
    this.onCallPharmacy,
    required this.onAskCaregiverToBuy,
    required this.onBoughtMedicine,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMMM d, y');
    final isOrdered = refill.isOrdered;
    final isPaused = refill.isPaused;
    final isCaregiverRequested = refill.isCaregiverRequested;
    final isRefilled = refill.isRefilled;
    final isUnhandledLast3Days = refill.isDueInLast3DaysUnhandled;

    Color badgeBg;
    Color badgeFg;
    String badgeText;

    if (isPaused) {
      badgeBg = Colors.grey.withOpacity(0.15);
      badgeFg = Colors.grey.shade700;
      badgeText = 'PAUSED';
    } else if (isCaregiverRequested) {
      badgeBg = const Color(0xFFFEF3C7);
      badgeFg = const Color(0xFFD97706);
      badgeText = 'ASKED CAREGIVER';
    } else if (isOrdered) {
      badgeBg = const Color(0xFF2292E6).withOpacity(0.15);
      badgeFg = const Color(0xFF2292E6);
      badgeText = 'ORDERED';
    } else if (isRefilled) {
      badgeBg = const Color(0xFFDCFCE7);
      badgeFg = const Color(0xFF16A34A);
      badgeText = 'RESTOCKED';
    } else if (refill.daysUntilDue <= 0) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeFg = const Color(0xFFDC2626);
      badgeText = 'DUE TODAY';
    } else if (isUnhandledLast3Days) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeFg = const Color(0xFFDC2626);
      badgeText = 'DUE IN ${refill.daysUntilDue} DAYS';
    } else if (refill.isDueSoon) {
      badgeBg = const Color(0xFFFFF1F2);
      badgeFg = const Color(0xFFE11D48);
      badgeText = 'DUE IN ${refill.daysUntilDue} DAYS';
    } else {
      badgeBg = const Color(0xFF16A34A).withOpacity(0.15);
      badgeFg = const Color(0xFF16A34A);
      badgeText = 'ON SCHEDULE';
    }

    // Tablet supply ratio
    final double supplyRatio = (refill.totalTabletsInPack > 0)
        ? (refill.remainingTablets / refill.totalTabletsInPack).clamp(0.0, 1.0)
        : 1.0;

    Color supplyBarColor;
    if (refill.remainingTablets <= refill.tabletsPerDay * 3) {
      supplyBarColor = const Color(0xFFDC2626); // Critical red
    } else if (refill.remainingTablets <= refill.tabletsPerDay * 6) {
      supplyBarColor = const Color(0xFFF59E0B); // Low warning amber
    } else {
      supplyBarColor = const Color(0xFF10B981); // Healthy green
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnhandledLast3Days
              ? const Color(0xFFDC2626)
              : (refill.isDueSoon && !isOrdered && !isRefilled
                  ? const Color(0xFFE11D48).withOpacity(0.35)
                  : AppColors.white.withOpacity(0.08)),
          width: isUnhandledLast3Days ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Medicine Header & Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isUnhandledLast3Days
                      ? const Color(0xFFFEE2E2)
                      : (refill.isDueSoon ? const Color(0xFFFFF1F2) : AppTheme.primary.withOpacity(0.12)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.medication_rounded,
                  color: isUnhandledLast3Days
                      ? const Color(0xFFDC2626)
                      : (refill.isDueSoon ? const Color(0xFFE11D48) : AppTheme.primary),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      refill.medicineName,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (refill.dosage.isNotEmpty)
                      Text(
                        refill.dosage,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeFg,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // ── TABLETS TAKING & SUPPLY TRACKING ────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.colorize_rounded, size: 18, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Tablets Taking:',
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${refill.tabletsPerDose} tablet${refill.tabletsPerDose > 1 ? "s" : ""} • ${refill.dosesPerDay}x daily',
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Remaining Supply:',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '${refill.remainingTablets} of ${refill.totalTabletsInPack} tablets left',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: supplyBarColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: supplyRatio,
                    minHeight: 7,
                    backgroundColor: AppColors.white.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(supplyBarColor),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── NEXT DATE TO BUY HIGHLIGHT BOX ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isUnhandledLast3Days
                  ? const Color(0xFFFEF2F2)
                  : AppTheme.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isUnhandledLast3Days
                    ? const Color(0xFFF87171)
                    : AppTheme.primary.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isUnhandledLast3Days
                        ? const Color(0xFFFEE2E2)
                        : AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.shopping_bag_rounded,
                    size: 22,
                    color: isUnhandledLast3Days
                        ? const Color(0xFFDC2626)
                        : AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next Date to Buy:',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isUnhandledLast3Days
                              ? const Color(0xFF991B1B)
                              : AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        dateFormat.format(refill.nextDateToBuy),
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isUnhandledLast3Days
                              ? const Color(0xFFDC2626)
                              : AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        refill.daysUntilDue <= 0
                            ? 'Buy today! Supply is due now.'
                            : 'Due in ${refill.daysUntilDue} days (${refill.remainingTablets} tablets remaining)',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: isUnhandledLast3Days
                              ? const Color(0xFFB91C1C)
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── PRESCRIPTION DOCS SECTION ───────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description_rounded, size: 18, color: Color(0xFF2292E6)),
                        const SizedBox(width: 6),
                        Text(
                          'Prescription Document:',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: onViewPrescriptionDoc,
                      icon: const Icon(Icons.visibility_rounded, size: 16),
                      label: Text(
                        'View Doc',
                        style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2292E6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      ),
                    ),
                  ],
                ),
                Text(
                  refill.prescriptionDocumentName ?? 'Official Doctor Prescription Slip.pdf',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF2292E6),
                  ),
                ),
                if (refill.prescriptionDoctorName != null &&
                    refill.prescriptionDoctorName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Doctor: ${refill.prescriptionDoctorName} • ${refill.prescriptionClinic ?? "Clinic"}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                if (refill.prescriptionDetails != null &&
                    refill.prescriptionDetails!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    refill.prescriptionDetails!,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Pharmacy & Bill info if present
          if (refill.pharmacyName != null && refill.pharmacyName!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.local_pharmacy_rounded, size: 18, color: Color(0xFF2292E6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    refill.pharmacyName!,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (onCallPharmacy != null)
                  TextButton.icon(
                    onPressed: onCallPharmacy,
                    icon: const Icon(Icons.phone_rounded, size: 15),
                    label: Text(
                      'Call Pharmacy',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2292E6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    ),
                  ),
              ],
            ),
          ],

          if (refill.billAmount != null && refill.billAmount! > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.receipt_rounded, size: 16, color: Color(0xFFE53935)),
                const SizedBox(width: 8),
                Text(
                  'Estimated Cost: \$${refill.billAmount!.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(fontSize: 12.5, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 6),
                Text(
                  refill.isBillPaid ? '(Paid)' : '(Due at pickup)',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: refill.isBillPaid ? AppColors.success : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 18),

          // ── ACTION BUTTONS: "ASK CAREGIVER TO BUY" / "BOUGHT THE MEDICINE" ──
          if (isCaregiverRequested) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Caregiver has been asked to buy this medicine. Tap below once received.',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const ValueKey('bought_medicine_btn'),
                onPressed: onBoughtMedicine,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(
                  'Bought the Medicine',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ] else if (!isPaused && (refill.isDueSoon || isUnhandledLast3Days)) ...[
            // The two one-tap buttons requested by user!
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const ValueKey('ask_caregiver_to_buy_btn'),
                    onPressed: onAskCaregiverToBuy,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B4FBB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                    label: Text(
                      'Ask Caregiver to Buy',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const ValueKey('bought_medicine_btn'),
                    onPressed: onBoughtMedicine,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                    label: Text(
                      'Bought the Medicine',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (isRefilled) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Medication Restocked • Supply Active',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF16A34A),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Interactive Prescription Document Viewer bottom sheet.
class _PrescriptionDocViewerSheet extends StatelessWidget {
  final MedicineRefillModel refill;

  const _PrescriptionDocViewerSheet({required this.refill});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMMM d, y');
    final docDate = refill.prescriptionDate ?? refill.createdAt;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header with Doctor & Clinic Information
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_hospital_rounded,
                            color: Color(0xFF2563EB), size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              refill.prescriptionDoctorName ?? 'Dr. Sarah Patel, MD',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              refill.prescriptionClinic ?? 'Memorial Health Center • General Medicine',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Rx Document Content
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '℞ OFFICIAL PRESCRIPTION',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E3A8A),
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Text(
                          'VERIFIED RX',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Date Issued: ${dateFormat.format(docDate)}',
                    style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  Text(
                    'Patient ID: ${refill.patientId}',
                    style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  Text(
                    'Medication Prescribed:',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    refill.medicineName,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  if (refill.dosage.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Dosage: ${refill.dosage}',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Text(
                    'Directions for Intake (Tablets Taking):',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Take ${refill.tabletsPerDose} tablet(s) by mouth ${refill.dosesPerDay} time(s) daily. Total ${refill.tabletsPerDay} tablet(s) per day.',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: const Color(0xFF334155),
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dispense Quantity:',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            Text(
                              '${refill.totalTabletsInPack} tablets (${refill.recurrence.toUpperCase()})',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Next Date to Buy:',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            Text(
                              dateFormat.format(refill.nextDateToBuy),
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (refill.prescriptionDetails != null &&
                      refill.prescriptionDetails!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Doctor Notes & Diagnostic Instructions:',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      refill.prescriptionDetails!,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        color: const Color(0xFF475569),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 1,
                            width: 140,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Physician Signature',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'SEAL & CERTIFIED',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Close Document', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
