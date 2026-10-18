import 'package:memora/features/dev_tools/presentation/developer_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memora/core/theme/app_theme.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/data/models/link_model.dart';
import 'package:memora/data/models/reminder_models.dart';
import 'package:memora/features/auth/data/auth_providers.dart';
import 'package:memora/features/reminders/data/reminder_providers.dart';

/// Home screen for patients.
/// Shows linked caregivers (read-only) and actionable reminders.
class PatientHomeScreen extends ConsumerWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final linksAsync = ref.watch(patientLinksProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
      data: (user) {
        if (user == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final patientId = user.patientId ?? '';
        final occAsync = ref.watch(actionableOccurrencesProvider(patientId));
        final remAsync = ref.watch(remindersProvider(patientId));

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, ${user.name.split(' ').first}!',
                                style: GoogleFonts.outfit(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Patient Account',
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _logout(context, ref),
                          icon: const Icon(Icons.logout_rounded,
                              color: AppTheme.textSecondary),
                          tooltip: 'Logout',
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Patient ID card
                    _PatientIdCard(patientId: patientId),
                    const SizedBox(height: 24),

                    // Reminder section
                    occAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const SizedBox(),
                      data: (occs) {
                        final reminders =
                            remAsync.valueOrNull?.fold<Map<String, ReminderModel>>(
                                  {},
                                  (map, r) => map..[r.reminderId] = r,
                                ) ??
                                {};
                        return _RemindersSection(
                          patientId: patientId,
                          occurrences: occs,
                          remindersById: reminders,
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Linked caregivers section
                    linksAsync.when(
                      loading: () => const Center(
                          child: CircularProgressIndicator()),
                      error: (_, __) => const SizedBox(),
                      data: (links) => _LinkedCaregiversCard(links: links),
                    ),
                    const DeveloperEntry(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Logout',
            style: GoogleFonts.outfit(color: AppTheme.textPrimary)),
        content: Text('Are you sure you want to logout?',
            style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Logout',
                style: GoogleFonts.outfit(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authNotifierProvider.notifier).logout();
    }
  }
}

// ── Reminder Section ───────────────────────────────────────────────────────

class _RemindersSection extends ConsumerStatefulWidget {
  final String patientId;
  final List<ReminderOccurrenceModel> occurrences;
  final Map<String, ReminderModel> remindersById;

  const _RemindersSection({
    required this.patientId,
    required this.occurrences,
    required this.remindersById,
  });

  @override
  ConsumerState<_RemindersSection> createState() => _RemindersSectionState();
}

class _RemindersSectionState extends ConsumerState<_RemindersSection> {
  // Track which occ was shown (so we have a shownTime)
  final Map<String, DateTime> _shownTimes = {};

  @override
  void didUpdateWidget(_RemindersSection old) {
    super.didUpdateWidget(old);
    final now = DateTime.now();
    for (final occ in widget.occurrences) {
      _shownTimes.putIfAbsent(occ.occurrenceId, () => now);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    for (final occ in widget.occurrences) {
      _shownTimes.putIfAbsent(occ.occurrenceId, () => now);
    }

    if (widget.occurrences.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.white.withOpacity(0.07), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: AppColors.success, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'All caught up! No reminders right now.',
                style: GoogleFonts.outfit(
                    color: AppTheme.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.alarm_rounded,
                color: AppTheme.primary, size: 18),
            const SizedBox(width: 8),
            Text('Reminders',
                style: GoogleFonts.outfit(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        ...widget.occurrences.map((occ) {
          final reminder = widget.remindersById[occ.reminderId];
          return _ReminderCard(
            patientId: widget.patientId,
            occ: occ,
            reminder: reminder,
            shownTime: _shownTimes[occ.occurrenceId] ?? DateTime.now(),
          );
        }),
      ],
    );
  }
}

class _ReminderCard extends ConsumerWidget {
  final String patientId;
  final ReminderOccurrenceModel occ;
  final ReminderModel? reminder;
  final DateTime shownTime;

  const _ReminderCard({
    required this.patientId,
    required this.occ,
    required this.reminder,
    required this.shownTime,
  });

  Color _importanceColor(String? importance) {
    switch (importance) {
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
    final actionNotifier = ref.read(reminderActionProvider(patientId).notifier);
    final isLoading = ref.watch(reminderActionProvider(patientId)).isLoading;
    final imp = reminder?.importance ?? 'medium';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _importanceColor(imp).withOpacity(0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _importanceColor(imp).withOpacity(0.08),
            blurRadius: 12,
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
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _importanceColor(imp),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  reminder?.title ?? 'Reminder',
                  style: GoogleFonts.outfit(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _importanceColor(imp).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  imp.toUpperCase(),
                  style: GoogleFonts.outfit(
                    color: _importanceColor(imp),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (reminder?.note != null) ...[
            const SizedBox(height: 8),
            Text(
              reminder!.note!,
              style: GoogleFonts.outfit(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
          if (occ.status == 'snoozed') ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.snooze_rounded,
                  size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text('Snoozed — snooze count: ${occ.snoozeCount}',
                  style: GoogleFonts.outfit(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ]),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => actionNotifier.snooze(
                          occ.copyWith(shownTime: shownTime)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side:
                        const BorderSide(color: AppTheme.textSecondary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.snooze_rounded, size: 16),
                  label: Text('Snooze 10m', style: GoogleFonts.outfit()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => actionNotifier.confirm(
                          occ.copyWith(shownTime: shownTime)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: Text('Got it!', style: GoogleFonts.outfit()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Linked Caregivers (read-only) ──────────────────────────────────────────

class _LinkedCaregiversCard extends ConsumerWidget {
  final List<LinkModel> links;
  const _LinkedCaregiversCard({required this.links});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeLinks = links.where((l) => l.isActive).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (activeLinks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.white.withOpacity(0.07), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_off_outlined,
                color: AppTheme.textSecondary, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'No caregiver linked yet. Share your Patient ID with a caregiver.',
                style: GoogleFonts.outfit(
                    color: AppTheme.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.white.withOpacity(0.08), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_rounded,
                  color: AppTheme.textSecondary, size: 18),
              const SizedBox(width: 8),
              Text('Your Caregivers',
                  style: GoogleFonts.outfit(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          ...activeLinks.map((link) => _CaregiverRow(link: link)),
        ],
      ),
    );
  }
}

class _CaregiverRow extends ConsumerWidget {
  final LinkModel link;
  const _CaregiverRow({required this.link});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future:
          ref.read(linkRepositoryProvider).getCaregiverUser(link.caregiverUid),
      builder: (context, snapshot) {
        final name = snapshot.data?.name ?? '…';
        final isPrimary = link.isPrimary;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isPrimary
                    ? AppTheme.primary.withOpacity(0.2)
                    : AppTheme.secondary.withOpacity(0.2),
                child: Icon(
                  Icons.person_rounded,
                  color: isPrimary ? AppTheme.primary : AppTheme.secondary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name,
                    style: GoogleFonts.outfit(
                        color: AppTheme.textPrimary, fontSize: 14)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPrimary
                      ? AppTheme.primary.withOpacity(0.15)
                      : AppTheme.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isPrimary ? 'Primary' : 'Secondary',
                  style: GoogleFonts.outfit(
                      color: isPrimary ? AppTheme.primary : AppTheme.secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PatientIdCard extends StatelessWidget {
  final String patientId;
  const _PatientIdCard({required this.patientId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.badge_rounded, color: AppColors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                'Your Patient ID',
                style: GoogleFonts.outfit(color: AppColors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            patientId,
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Share this ID with your caregiver so they can link to your account.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: AppColors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.white,
              side: const BorderSide(color: AppColors.white54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: patientId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Patient ID copied to clipboard!')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: Text('Copy ID', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
  }
}
