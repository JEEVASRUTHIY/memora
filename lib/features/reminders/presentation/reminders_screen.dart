import 'package:go_router/go_router.dart';
import 'package:memora/core/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:memora/core/theme/app_theme.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/data/models/reminder_models.dart';
import 'package:memora/data/models/medicine_refill_model.dart';
import 'package:memora/features/reminders/data/reminder_providers.dart';
import 'package:memora/features/reminders/data/refill_providers.dart';

/// Primary caregiver screen to create/edit/delete daily reminders, prescription schedules, and refill/bill reminders.
/// Secondary caregivers see read-only view.
class RemindersScreen extends ConsumerStatefulWidget {
  final String patientId;
  final bool isPrimary;

  const RemindersScreen({
    super.key,
    required this.patientId,
    required this.isPrimary,
  });

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  int _selectedTab = 0; // 0: Daily Reminders, 1: Refills & Bills

  @override
  Widget build(BuildContext context) {
    final remAsync = ref.watch(remindersProvider(widget.patientId));
    final refillsAsync = ref.watch(patientRefillsProvider(widget.patientId));

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go(AppRoutes.caregiverHome),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Medication & Reminders',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (widget.isPrimary)
                      IconButton(
                        onPressed: () {
                          if (_selectedTab == 0) {
                            _showReminderDialog(context, ref, null);
                          } else {
                            _showRefillDialog(context, ref, null);
                          }
                        },
                        icon: const Icon(Icons.add_circle_rounded,
                            color: AppTheme.primary, size: 28),
                        tooltip: _selectedTab == 0 ? 'Add reminder' : 'Add refill schedule',
                      ),
                  ],
                ),
              ),

              // Segmented Tab Selector (Daily Reminders vs Refills & Bills)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TabButton(
                          title: 'Daily Reminders',
                          icon: Icons.alarm_rounded,
                          isSelected: _selectedTab == 0,
                          onTap: () => setState(() => _selectedTab = 0),
                        ),
                      ),
                      Expanded(
                        child: _TabButton(
                          title: 'Refills & Bills',
                          icon: Icons.receipt_long_rounded,
                          isSelected: _selectedTab == 1,
                          badgeCount: refillsAsync.valueOrNull
                              ?.where((r) => r.isDueSoon)
                              .length,
                          onTap: () => setState(() => _selectedTab = 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Body content based on selected tab
              Expanded(
                child: _selectedTab == 0
                    ? _buildDailyRemindersSection(remAsync)
                    : _buildRefillsSection(refillsAsync),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyRemindersSection(AsyncValue<List<ReminderModel>> remAsync) {
    return remAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Error: $e',
          style: GoogleFonts.outfit(color: AppTheme.error),
        ),
      ),
      data: (reminders) {
        if (reminders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.alarm_off_rounded,
                    color: AppTheme.textSecondary, size: 48),
                const SizedBox(height: 16),
                Text('No active reminders',
                    style: GoogleFonts.outfit(
                        color: AppTheme.textSecondary, fontSize: 16)),
                if (widget.isPrimary) ...[
                  const SizedBox(height: 8),
                  Text('Tap + to create one',
                      style: GoogleFonts.outfit(
                          color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: reminders.length,
          itemBuilder: (_, i) => _ReminderTile(
            reminder: reminders[i],
            isPrimary: widget.isPrimary,
            patientId: widget.patientId,
            onEdit: () => _showReminderDialog(context, ref, reminders[i]),
          ),
        );
      },
    );
  }

  Widget _buildRefillsSection(AsyncValue<List<MedicineRefillModel>> refillsAsync) {
    return refillsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Error: $e',
          style: GoogleFonts.outfit(color: AppTheme.error),
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
                  const Icon(Icons.medication_liquid_rounded,
                      color: AppTheme.textSecondary, size: 48),
                  const SizedBox(height: 16),
                  Text('No Refill Schedules Configured',
                      style: GoogleFonts.outfit(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Configure recurring monthly refill dates, prescription notes, and pharmacy bill amounts for your patient.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  if (widget.isPrimary) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showRefillDialog(context, ref, null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text('Add Refill Schedule', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          itemCount: refills.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (_, i) => _CaregiverRefillTile(
            refill: refills[i],
            isPrimary: widget.isPrimary,
            patientId: widget.patientId,
            onEdit: () => _showRefillDialog(context, ref, refills[i]),
          ),
        );
      },
    );
  }

  Future<void> _showReminderDialog(
      BuildContext context, WidgetRef ref, ReminderModel? existing) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => _ReminderFormSheet(
        patientId: widget.patientId,
        existing: existing,
        ref: ref,
      ),
    );
  }

  Future<void> _showRefillDialog(
      BuildContext context, WidgetRef ref, MedicineRefillModel? existing) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => _RefillFormSheet(
        patientId: widget.patientId,
        existing: existing,
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final int? badgeCount;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
            if (badgeCount != null && badgeCount! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Reminder Tile ──────────────────────────────────────────────────────────

class _ReminderTile extends ConsumerWidget {
  final ReminderModel reminder;
  final bool isPrimary;
  final String patientId;
  final VoidCallback onEdit;

  const _ReminderTile({
    required this.reminder,
    required this.isPrimary,
    required this.patientId,
    required this.onEdit,
  });

  Color _impColor(String imp) {
    switch (imp) {
      case 'high':
        return AppColors.emergency;
      case 'low':
        return AppColors.success;
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: _impColor(reminder.importance).withOpacity(0.25),
            width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _impColor(reminder.importance).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.alarm_rounded,
                color: _impColor(reminder.importance), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reminder.title,
                    style: GoogleFonts.outfit(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${reminder.recurrence}'
                  '${reminder.times.isNotEmpty ? ' · ${reminder.times.join(", ")}' : ''}'
                  ' · ${reminder.importance}',
                  style: GoogleFonts.outfit(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isPrimary) ...[
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined,
                  color: AppTheme.textSecondary, size: 20),
            ),
            IconButton(
              onPressed: () => _confirmDelete(context, ref),
              icon:
                  const Icon(Icons.delete_outline, color: AppColors.emergency, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Delete Reminder',
            style: GoogleFonts.outfit(color: AppTheme.textPrimary)),
        content: Text('Delete "${reminder.title}"? This cannot be undone.',
            style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.outfit(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(reminderManagementProvider(patientId).notifier)
          .delete(reminder.reminderId);
    }
  }
}

// ── Caregiver Refill Tile ──────────────────────────────────────────────────

class _CaregiverRefillTile extends ConsumerWidget {
  final MedicineRefillModel refill;
  final bool isPrimary;
  final String patientId;
  final VoidCallback onEdit;

  const _CaregiverRefillTile({
    required this.refill,
    required this.isPrimary,
    required this.patientId,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('MMMM d, y');
    final isDueSoon = refill.isDueSoon;
    final isPaused = refill.isPaused;
    final isOrdered = refill.status == 'ordered';
    final isCaregiverRequested = refill.isCaregiverRequested;

    Color statusColor;
    String statusLabel;
    if (isPaused) {
      statusColor = Colors.grey;
      statusLabel = 'PAUSED';
    } else if (isCaregiverRequested) {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'PATIENT REQUESTED REFILL';
    } else if (isOrdered) {
      statusColor = const Color(0xFF2292E6);
      statusLabel = 'ORDERED';
    } else if (refill.daysUntilDue <= 0) {
      statusColor = const Color(0xFFE53935);
      statusLabel = 'DUE TODAY';
    } else if (isDueSoon) {
      statusColor = const Color(0xFFE11D48);
      statusLabel = 'DUE IN ${refill.daysUntilDue} DAYS';
    } else {
      statusColor = const Color(0xFF16A34A);
      statusLabel = 'ACTIVE (${refill.daysUntilDue}d)';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCaregiverRequested
              ? const Color(0xFFF59E0B)
              : (isDueSoon && !isOrdered
                  ? const Color(0xFFE11D48).withOpacity(0.35)
                  : AppColors.white.withOpacity(0.08)),
          width: isCaregiverRequested ? 2.0 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.medication_rounded, color: statusColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      refill.medicineName,
                      style: GoogleFonts.outfit(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (refill.dosage.isNotEmpty)
                      Text(
                        refill.dosage,
                        style: GoogleFonts.outfit(
                          color: AppTheme.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.outfit(
                    color: statusColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          if (isCaregiverRequested) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFB45309)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Patient tapped "Ask Caregiver to Buy" for this medicine!',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Tablets Taking & Supply
          Text(
            'Tablets: ${refill.tabletsPerDose} tab • ${refill.dosesPerDay}x daily (${refill.tabletsPerDay} tabs/day) | Supply: ${refill.remainingTablets}/${refill.totalTabletsInPack} tablets remaining',
            style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          // Next Date to Buy
          Text(
            'Next Date to Buy: ${dateFormat.format(refill.nextDateToBuy)} · ${refill.recurrence.toUpperCase()} (${refill.daysUntilDue <= 0 ? "Due today" : "due in ${refill.daysUntilDue}d"})',
            style: GoogleFonts.outfit(
              color: refill.daysUntilDue <= 3 ? const Color(0xFFE53935) : AppTheme.textSecondary,
              fontSize: 12.5,
              fontWeight: refill.daysUntilDue <= 3 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (refill.prescriptionDoctorName != null || refill.prescriptionDocumentName != null) ...[
            const SizedBox(height: 4),
            Text(
              'Rx Doc: ${refill.prescriptionDocumentName ?? "Prescription Slip"} (${refill.prescriptionDoctorName ?? "Physician"} • ${refill.prescriptionClinic ?? "Clinic"})',
              style: GoogleFonts.outfit(color: const Color(0xFF2292E6), fontSize: 12),
            ),
          ],
          if (refill.prescriptionDetails != null && refill.prescriptionDetails!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Rx Notes: ${refill.prescriptionDetails}',
              style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
          if (refill.billAmount != null && refill.billAmount! > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Estimated Bill: \$${refill.billAmount!.toStringAsFixed(2)} ${refill.isBillPaid ? '(Paid)' : '(Unpaid)'}',
              style: GoogleFonts.outfit(
                color: refill.isBillPaid ? AppColors.success : const Color(0xFFE53935),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (isPrimary) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                // Mark Refilled & Advance
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await ref
                        .read(refillManagementProvider(patientId).notifier)
                        .markRefilled(refill);
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            refill.recurrence == 'none'
                                ? 'Refill marked completed!'
                                : 'Refill completed! Next occurrence scheduled for ${DateFormat('MMMM d, y').format(refill.computeNextDueDate())}',
                          ),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: const BorderSide(color: AppColors.success),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 15),
                  label: Text('Mark Refilled', style: GoogleFonts.outfit(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                // Pause / Resume
                OutlinedButton(
                  onPressed: () => ref
                      .read(refillManagementProvider(patientId).notifier)
                      .togglePause(refill.id, isPaused),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: BorderSide(color: AppColors.white.withOpacity(0.15)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: Text(isPaused ? 'Resume' : 'Pause', style: GoogleFonts.outfit(fontSize: 12)),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 18),
                  tooltip: 'Edit Refill',
                ),
                IconButton(
                  onPressed: () => _confirmDelete(context, ref),
                  icon: const Icon(Icons.delete_outline, color: AppColors.emergency, size: 18),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Delete Refill Schedule', style: GoogleFonts.outfit(color: AppTheme.textPrimary)),
        content: Text('Delete refill schedule for "${refill.medicineName}"?', style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.outfit(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(refillManagementProvider(patientId).notifier).deleteRefill(refill.id);
    }
  }
}

// ── Reminder Form Sheet ────────────────────────────────────────────────────

class _ReminderFormSheet extends ConsumerStatefulWidget {
  final String patientId;
  final ReminderModel? existing;
  final WidgetRef ref;

  const _ReminderFormSheet({
    required this.patientId,
    required this.existing,
    required this.ref,
  });

  @override
  ConsumerState<_ReminderFormSheet> createState() => _ReminderFormSheetState();
}

class _ReminderFormSheetState extends ConsumerState<_ReminderFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _timesCtrl;
  String _recurrence = 'daily';
  String _importance = 'medium';
  int _maxRepeats = 3;
  int _repeatEveryMinutes = 15;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _timesCtrl =
        TextEditingController(text: e?.times.join(', ') ?? '08:00');
    _recurrence = e?.recurrence ?? 'daily';
    _importance = e?.importance ?? 'medium';
    _maxRepeats = e?.maxRepeats ?? 3;
    _repeatEveryMinutes = e?.repeatEveryMinutes ?? 15;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _timesCtrl.dispose();
    super.dispose();
  }

  List<String> get _parsedTimes => _timesCtrl.text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final isEdit = widget.existing != null;
    final reminder = ReminderModel(
      reminderId:
          widget.existing?.reminderId ?? ref.read(reminderRepositoryProvider).newReminderId(widget.patientId),
      patientId: widget.patientId,
      title: _titleCtrl.text.trim(),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      recurrence: _recurrence,
      times: _parsedTimes,
      importance: _importance,
      maxRepeats: _maxRepeats,
      repeatEveryMinutes: _repeatEveryMinutes,
      active: true,
      createdBy: widget.existing?.createdBy ?? '',
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    bool ok;
    if (isEdit) {
      ok = await ref
          .read(reminderManagementProvider(widget.patientId).notifier)
          .update(reminder);
    } else {
      ok = await ref
          .read(reminderManagementProvider(widget.patientId).notifier)
          .create(reminder);
    }

    setState(() => _saving = false);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.text,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(isEdit ? 'Edit Reminder' : 'New Reminder',
                  style: GoogleFonts.outfit(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _field(
                controller: _titleCtrl,
                label: 'Title',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title required' : null,
              ),
              const SizedBox(height: 16),
              _field(
                  controller: _noteCtrl, label: 'Note (optional)', maxLines: 2),
              const SizedBox(height: 16),
              _dropdown<String>(
                label: 'Recurrence',
                value: _recurrence,
                items: const ['once', 'daily', 'weekly'],
                onChanged: (v) => setState(() => _recurrence = v!),
              ),
              const SizedBox(height: 16),
              _field(
                controller: _timesCtrl,
                label: 'Times (HH:mm, comma-separated)',
                hint: '08:00, 13:00, 20:00',
              ),
              const SizedBox(height: 16),
              _dropdown<String>(
                label: 'Importance',
                value: _importance,
                items: const ['low', 'medium', 'high'],
                onChanged: (v) => setState(() => _importance = v!),
              ),
              const SizedBox(height: 16),
              _dropdown<int>(
                label: 'Max repeats before missed',
                value: _maxRepeats,
                items: const [1, 2, 3, 5, 8],
                onChanged: (v) => setState(() => _maxRepeats = v!),
              ),
              const SizedBox(height: 16),
              _dropdown<int>(
                label: 'Repeat every (minutes)',
                value: _repeatEveryMinutes,
                items: const [5, 10, 15, 20, 30],
                onChanged: (v) => setState(() => _repeatEveryMinutes = v!),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: AppColors.white, strokeWidth: 2))
                      : Text(isEdit ? 'Save Changes' : 'Create Reminder',
                          style: GoogleFonts.outfit(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: GoogleFonts.outfit(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.outfit(color: AppTheme.textSecondary),
        hintStyle:
            GoogleFonts.outfit(color: AppTheme.textSecondary.withOpacity(0.5)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppColors.white.withOpacity(0.15), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.white.withOpacity(0.05),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(color: AppTheme.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppColors.white.withOpacity(0.15), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.white.withOpacity(0.05),
      ),
      dropdownColor: AppColors.text,
      style: GoogleFonts.outfit(color: AppTheme.textPrimary),
      items: items
          .map((i) => DropdownMenuItem<T>(
              value: i,
              child: Text(i.toString(),
                  style: GoogleFonts.outfit(color: AppTheme.textPrimary))))
          .toList(),
      onChanged: onChanged,
    );
  }
}

// ── Refill & Bill Reminder Form Sheet ──────────────────────────────────────

class _RefillFormSheet extends ConsumerStatefulWidget {
  final String patientId;
  final MedicineRefillModel? existing;

  const _RefillFormSheet({
    required this.patientId,
    required this.existing,
  });

  @override
  ConsumerState<_RefillFormSheet> createState() => _RefillFormSheetState();
}

class _RefillFormSheetState extends ConsumerState<_RefillFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _dosageCtrl;
  late TextEditingController _prescriptionCtrl;
  late TextEditingController _pharmacyNameCtrl;
  late TextEditingController _pharmacyPhoneCtrl;
  late TextEditingController _billAmountCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _tabletsPerDoseCtrl;
  late TextEditingController _dosesPerDayCtrl;
  late TextEditingController _totalPackCtrl;
  late TextEditingController _remainingTabletsCtrl;
  late TextEditingController _docNameCtrl;
  late TextEditingController _doctorNameCtrl;
  late TextEditingController _clinicCtrl;

  late DateTime _dueDate;
  String _recurrence = 'monthly';
  int _leadDays = 5;
  bool _isBillPaid = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.medicineName ?? '');
    _dosageCtrl = TextEditingController(text: e?.dosage ?? '');
    _prescriptionCtrl = TextEditingController(text: e?.prescriptionDetails ?? '');
    _pharmacyNameCtrl = TextEditingController(text: e?.pharmacyName ?? '');
    _pharmacyPhoneCtrl = TextEditingController(text: e?.pharmacyPhone ?? '');
    _billAmountCtrl = TextEditingController(
      text: e?.billAmount != null ? e!.billAmount!.toStringAsFixed(2) : '',
    );
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _tabletsPerDoseCtrl = TextEditingController(text: '${e?.tabletsPerDose ?? 1}');
    _dosesPerDayCtrl = TextEditingController(text: '${e?.dosesPerDay ?? 1}');
    _totalPackCtrl = TextEditingController(text: '${e?.totalTabletsInPack ?? 30}');
    _remainingTabletsCtrl = TextEditingController(text: '${e?.remainingTablets ?? 30}');
    _docNameCtrl = TextEditingController(text: e?.prescriptionDocumentName ?? 'Official Doctor Prescription Slip.pdf');
    _doctorNameCtrl = TextEditingController(text: e?.prescriptionDoctorName ?? 'Dr. Sarah Patel, MD');
    _clinicCtrl = TextEditingController(text: e?.prescriptionClinic ?? 'Memorial Health Center');

    _dueDate = e?.refillDueDate ?? DateTime.now().add(const Duration(days: 30));
    _recurrence = e?.recurrence ?? 'monthly';
    _leadDays = e?.reminderLeadDays ?? 5;
    _isBillPaid = e?.isBillPaid ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _prescriptionCtrl.dispose();
    _pharmacyNameCtrl.dispose();
    _pharmacyPhoneCtrl.dispose();
    _billAmountCtrl.dispose();
    _notesCtrl.dispose();
    _tabletsPerDoseCtrl.dispose();
    _dosesPerDayCtrl.dispose();
    _totalPackCtrl.dispose();
    _remainingTabletsCtrl.dispose();
    _docNameCtrl.dispose();
    _doctorNameCtrl.dispose();
    _clinicCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.primary,
            surface: AppColors.text,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final isEdit = widget.existing != null;
    final id = widget.existing?.id ??
        ref.read(refillRepositoryProvider).newRefillId(widget.patientId);

    final billParsed = double.tryParse(_billAmountCtrl.text.replaceAll('\$', '').trim());
    final tabletsPerDose = int.tryParse(_tabletsPerDoseCtrl.text.trim()) ?? 1;
    final dosesPerDay = int.tryParse(_dosesPerDayCtrl.text.trim()) ?? 1;
    final totalPack = int.tryParse(_totalPackCtrl.text.trim()) ?? 30;
    final remainingTablets = int.tryParse(_remainingTabletsCtrl.text.trim()) ?? totalPack;

    final refill = MedicineRefillModel(
      id: id,
      patientId: widget.patientId,
      medicineName: _nameCtrl.text.trim(),
      dosage: _dosageCtrl.text.trim(),
      refillDueDate: _dueDate,
      recurrence: _recurrence,
      reminderLeadDays: _leadDays,
      status: widget.existing?.status ?? 'active',
      prescriptionDetails: _prescriptionCtrl.text.trim().isEmpty ? null : _prescriptionCtrl.text.trim(),
      prescriptionDocumentName: _docNameCtrl.text.trim().isEmpty ? null : _docNameCtrl.text.trim(),
      prescriptionDoctorName: _doctorNameCtrl.text.trim().isEmpty ? null : _doctorNameCtrl.text.trim(),
      prescriptionClinic: _clinicCtrl.text.trim().isEmpty ? null : _clinicCtrl.text.trim(),
      tabletsPerDose: tabletsPerDose,
      dosesPerDay: dosesPerDay,
      totalTabletsInPack: totalPack,
      remainingTablets: remainingTablets,
      pharmacyName: _pharmacyNameCtrl.text.trim().isEmpty ? null : _pharmacyNameCtrl.text.trim(),
      pharmacyPhone: _pharmacyPhoneCtrl.text.trim().isEmpty ? null : _pharmacyPhoneCtrl.text.trim(),
      billAmount: billParsed,
      isBillPaid: _isBillPaid,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      lastRefilledAt: widget.existing?.lastRefilledAt,
      caregiverRequestedAt: widget.existing?.caregiverRequestedAt,
    );

    final ok = await ref
        .read(refillManagementProvider(widget.patientId).notifier)
        .saveRefill(refill, isNew: !isEdit);

    setState(() => _saving = false);
    if (ok && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit ? 'Refill schedule updated!' : 'New refill schedule created!',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.text,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isEdit ? 'Edit Refill & Prescription' : 'New Refill Schedule',
                style: GoogleFonts.outfit(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Configure recurring monthly refill dates, doctor prescription details, and pharmacy bills.',
                style: GoogleFonts.outfit(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),

              // Medicine Name
              TextFormField(
                controller: _nameCtrl,
                style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Medicine name required' : null,
                decoration: _fieldDec('Medicine / Prescription Name *', 'e.g. Atorvastatin'),
              ),
              const SizedBox(height: 16),

              // Dosage
              TextFormField(
                controller: _dosageCtrl,
                style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                decoration: _fieldDec('Dosage / Instructions', 'e.g. 20mg daily at bedtime'),
              ),
              const SizedBox(height: 16),

              // Due Date Picker Button
              InkWell(
                onTap: _pickDueDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.white.withOpacity(0.15), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: AppTheme.primary, size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Next Refill Due Date *',
                              style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                            Text(
                              DateFormat('EEEE, MMMM d, y').format(_dueDate),
                              style: GoogleFonts.outfit(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_calendar_rounded, color: AppTheme.textSecondary, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Recurrence & Reminder Lead Time
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _recurrence,
                      isExpanded: true,
                      decoration: _fieldDec('Recurrence', null),
                      dropdownColor: AppColors.text,
                      style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                      items: const [
                        DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                        DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                        DropdownMenuItem(value: 'none', child: Text('One-time only')),
                      ],
                      onChanged: (v) => setState(() => _recurrence = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _leadDays,
                      isExpanded: true,
                      decoration: _fieldDec('Reminder Alert', null),
                      dropdownColor: AppColors.text,
                      style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 day prior')),
                        DropdownMenuItem(value: 3, child: Text('3 days prior')),
                        DropdownMenuItem(value: 5, child: Text('5 days prior (Default)')),
                        DropdownMenuItem(value: 7, child: Text('7 days prior')),
                        DropdownMenuItem(value: 10, child: Text('10 days prior')),
                      ],
                      onChanged: (v) => setState(() => _leadDays = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tablets Taking & Dosage Tracking
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tabletsPerDoseCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                      decoration: _fieldDec('Tablets per Dose', 'e.g. 1'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _dosesPerDayCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                      decoration: _fieldDec('Doses per Day', 'e.g. 2'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Total Pack Size & Current Remaining Tablets
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _totalPackCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                      decoration: _fieldDec('Pack Size (Tablets)', 'e.g. 30'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _remainingTabletsCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                      decoration: _fieldDec('Remaining Tablets', 'e.g. 30'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Prescription Doctor & Clinic Details
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _doctorNameCtrl,
                      style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                      decoration: _fieldDec('Doctor Name', 'e.g. Dr. Sarah Patel, MD'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _clinicCtrl,
                      style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                      decoration: _fieldDec('Clinic / Hospital', 'e.g. Memorial Clinic'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _docNameCtrl,
                style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                decoration: _fieldDec('Prescription Document Attachment', 'e.g. Rx_Doctor_Slip.pdf'),
              ),
              const SizedBox(height: 16),

              // Prescription & Doctor Details
              TextFormField(
                controller: _prescriptionCtrl,
                maxLines: 2,
                style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                decoration: _fieldDec('Prescription Details & Doctor Notes', 'Rx# 84920, Dr. Smith'),
              ),
              const SizedBox(height: 16),

              // Pharmacy Name & Phone
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pharmacyNameCtrl,
                      style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                      decoration: _fieldDec('Pharmacy Name', 'e.g. CVS Pharmacy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _pharmacyPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                      decoration: _fieldDec('Pharmacy Phone', 'e.g. (555) 234-5678'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Bill Amount & Bill Paid Switch
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _billAmountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                      decoration: _fieldDec('Estimated Bill (\$)', 'e.g. 15.00'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      Switch(
                        value: _isBillPaid,
                        activeColor: AppColors.success,
                        onChanged: (v) => setState(() => _isBillPaid = v),
                      ),
                      Text(
                        _isBillPaid ? 'Paid' : 'Unpaid',
                        style: GoogleFonts.outfit(
                          color: _isBillPaid ? AppColors.success : AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Optional Notes
              TextFormField(
                controller: _notesCtrl,
                style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                decoration: _fieldDec('Additional Notes (optional)', 'e.g. Pick up after 2 PM'),
              ),
              const SizedBox(height: 30),

              // Save Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                      : Text(isEdit ? 'Save Changes' : 'Create Refill Schedule',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDec(String label, String? hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.outfit(color: AppTheme.textSecondary),
      hintStyle: GoogleFonts.outfit(color: AppTheme.textSecondary.withOpacity(0.5)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.white.withOpacity(0.15), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
      ),
      filled: true,
      fillColor: AppColors.white.withOpacity(0.05),
    );
  }
}
