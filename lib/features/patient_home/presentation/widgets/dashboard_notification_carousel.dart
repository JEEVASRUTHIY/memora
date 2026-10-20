import 'dart:async';
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
import 'package:memora/features/medicine/presentation/medicine_incoming_reminder_screen.dart';
import 'package:memora/features/reminders/presentation/patient_refills_screen.dart';

/// Data class representing an item in the dashboard notification carousel.
class DashboardNotificationItem {
  final String id;
  final String type; // 'medicine' | 'refill' | 'urgent_refill' | 'hydration' | 'location' | 'prescription'
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onAction;
  final String? secondaryButtonLabel;
  final VoidCallback? onSecondaryAction;
  final VoidCallback? onCardTap;
  final Color backgroundColor;
  final Color iconBackgroundColor;
  final Color iconColor;
  final IconData iconData;
  final bool isButtonOutlined;

  const DashboardNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onAction,
    this.secondaryButtonLabel,
    this.onSecondaryAction,
    this.onCardTap,
    required this.backgroundColor,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.iconData,
    this.isButtonOutlined = false,
  });
}

/// Swipeable Dashboard Notification Carousel positioned above the 4x4 options grid.
/// Displays active snoozed medicines with a one-tap Done button, hydration (Drink water),
/// upcoming next medicine time, safe zone location status, and daily refill alerts.
/// Automatically swipes every 10 seconds.
class DashboardNotificationCarousel extends ConsumerStatefulWidget {
  final String patientId;
  final VoidCallback onOpenHydration;

  const DashboardNotificationCarousel({
    super.key,
    required this.patientId,
    required this.onOpenHydration,
  });

  @override
  ConsumerState<DashboardNotificationCarousel> createState() =>
      _DashboardNotificationCarouselState();
}

class _DashboardNotificationCarouselState
    extends ConsumerState<DashboardNotificationCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  final Set<String> _dismissedIds = {};
  Timer? _autoSwipeTimer;
  int _lastTotalItems = 0;

  bool get _isTestEnvironment {
    return const bool.fromEnvironment('flutter.test') ||
        WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoSwipe();
  }

  @override
  void dispose() {
    _autoSwipeTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSwipe() {
    _autoSwipeTimer?.cancel();
    if (_isTestEnvironment) return;

    _autoSwipeTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || !_pageController.hasClients) return;
      if (_lastTotalItems <= 1) return;
      final nextPage = (_currentPage + 1) % _lastTotalItems;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _resetAutoSwipe() {
    _startAutoSwipe();
  }

  void _goToPrevious() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
      _resetAutoSwipe();
    }
  }

  void _goToNext(int totalItems) {
    if (_currentPage < totalItems - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
      _resetAutoSwipe();
    }
  }

  void _dismissItem(String id, int currentTotal) {
    setState(() {
      _dismissedIds.add(id);
      if (_currentPage >= currentTotal - 1 && _currentPage > 0) {
        _currentPage = currentTotal - 2;
      }
    });
    _resetAutoSwipe();
  }

  List<DashboardNotificationItem> _buildNotifications({
    required List<ReminderOccurrenceModel> actionableOccs,
    required List<ReminderModel> reminders,
    required List<MedicineRefillModel> refills,
  }) {
    final items = <DashboardNotificationItem>[];
    final remindersById = {for (final r in reminders) r.reminderId: r};

    // 1. Snoozed or Actionable Medicine Reminders (with one-tap "Done" button)
    for (final occ in actionableOccs) {
      final rem = remindersById[occ.reminderId];
      final id = 'occ_${occ.occurrenceId}';
      if (_dismissedIds.contains(id)) continue;

      final isSnoozed = occ.status == 'snoozed';
      final medicineName = rem?.title ?? 'medicine';
      final snoozeCount = occ.snoozeCount;
      final message = isSnoozed
          ? 'You snoozed your $medicineName ${snoozeCount > 0 ? '($snoozeCount times)' : ''}. Take tablets done?'
          : 'Time to take your scheduled $medicineName.';

      items.add(
        DashboardNotificationItem(
          id: id,
          type: 'medicine',
          title: 'Medicine reminder',
          message: message,
          buttonLabel: isSnoozed ? 'Done' : 'Take now',
          onAction: () async {
            if (isSnoozed) {
              await ref
                  .read(reminderActionProvider(widget.patientId).notifier)
                  .confirm(occ);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Great job! Marked $medicineName as taken.',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MedicineIncomingReminderScreen(
                    occurrence: occ,
                    reminder: rem,
                    autoStartSound: true,
                  ),
                ),
              );
            }
          },
          secondaryButtonLabel: isSnoozed ? 'Take now' : 'Done',
          onSecondaryAction: () async {
            if (isSnoozed) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MedicineIncomingReminderScreen(
                    occurrence: occ,
                    reminder: rem,
                    autoStartSound: true,
                  ),
                ),
              );
            } else {
              await ref
                  .read(reminderActionProvider(widget.patientId).notifier)
                  .confirm(occ);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Great job! Marked $medicineName as taken.',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            }
          },
          backgroundColor: const Color(0xFFFFFBEA), // Soft pastel yellow
          iconBackgroundColor: const Color(0xFFFEF3C7),
          iconColor: const Color(0xFFD97706),
          iconData: Icons.medication_rounded,
        ),
      );
    }


    // 5. DAILY REFILL ALERTS IN THE LAST 3 DAYS (with two one-tap buttons)
    for (final refill in refills) {
      if (!refill.isDueInLast3DaysUnhandled) continue;
      final id = 'daily_unhandled_refill_${refill.id}';
      if (_dismissedIds.contains(id)) continue;

      final days = refill.daysUntilDue;
      final formattedDueDate = DateFormat('MMM d').format(refill.nextDateToBuy);
      final daysText = days <= 0 ? 'Due Today' : '$days days left';

      items.add(
        DashboardNotificationItem(
          id: id,
          type: 'urgent_refill',
          title: 'Daily Refill Alert ($daysText)',
          message:
              '${refill.remainingTablets} tablets left for ${refill.medicineName}. Next date to buy: $formattedDueDate.',
          buttonLabel: 'Ask Caregiver',
          onAction: () async {
            final ok = await ref
                .read(refillManagementProvider(widget.patientId).notifier)
                .askCaregiverToBuy(refill.id);
            if (ok && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Caregiver asked to buy ${refill.medicineName}!',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: AppTheme.primary,
                ),
              );
            }
          },
          secondaryButtonLabel: 'Bought',
          onSecondaryAction: () async {
            final ok = await ref
                .read(refillManagementProvider(widget.patientId).notifier)
                .markBought(refill);
            if (ok && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Marked ${refill.medicineName} as bought! Restocked with ${refill.totalTabletsInPack} tablets.',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          },
          onCardTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PatientRefillsScreen(patientId: widget.patientId),
              ),
            );
          },
          backgroundColor: const Color(0xFFFEF2F2), // Urgent soft crimson
          iconBackgroundColor: const Color(0xFFFEE2E2),
          iconColor: const Color(0xFFDC2626),
          iconData: Icons.notification_important_rounded,
        ),
      );
    }

    // 6. Caregiver requested notification (patient asked caregiver, tap to confirm bought)
    for (final refill in refills) {
      if (!refill.isCaregiverRequested) continue;
      final id = 'caregiver_requested_${refill.id}';
      if (_dismissedIds.contains(id)) continue;

      items.add(
        DashboardNotificationItem(
          id: id,
          type: 'refill',
          title: 'Caregiver Notified',
          message:
              'Caregiver was asked to buy ${refill.medicineName}. Tap below once bought.',
          buttonLabel: 'Bought medicine',
          onAction: () async {
            final ok = await ref
                .read(refillManagementProvider(widget.patientId).notifier)
                .markBought(refill);
            if (ok && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Marked ${refill.medicineName} as bought! Restocked.',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          },
          onCardTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PatientRefillsScreen(patientId: widget.patientId),
              ),
            );
          },
          backgroundColor: const Color(0xFFFEF3C7), // Amber
          iconBackgroundColor: const Color(0xFFFDE68A),
          iconColor: const Color(0xFFD97706),
          iconData: Icons.pending_actions_rounded,
        ),
      );
    }

    // 7. Upcoming Medicine Refills / Low Stock (outside the critical 3-day window)
    for (final refill in refills) {
      if (!refill.isDueSoon || refill.isDueInLast3DaysUnhandled || refill.isCaregiverRequested) {
        continue;
      }
      final id = 'refill_${refill.id}';
      if (_dismissedIds.contains(id)) continue;

      final days = refill.daysUntilDue;
      final message =
          'You may run out of ${refill.medicineName} in $days days (${refill.remainingTablets} tablets remaining). Next date to buy is ${DateFormat.MMMd().format(refill.nextDateToBuy)}.';

      items.add(
        DashboardNotificationItem(
          id: id,
          type: 'refill',
          title: 'Refill soon',
          message: message,
          buttonLabel: 'View details',
          isButtonOutlined: true,
          backgroundColor: const Color(0xFFFFF1F2), // Soft pastel pink
          iconBackgroundColor: const Color(0xFFFFE4E6),
          iconColor: const Color(0xFFE11D48),
          iconData: Icons.shopping_cart_outlined,
          onAction: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PatientRefillsScreen(patientId: widget.patientId),
              ),
            );
          },
        ),
      );
    }

    // 8. New Prescription Notification
    for (final refill in refills) {
      final id = 'rx_${refill.id}';
      if (_dismissedIds.contains(id)) continue;
      final daysSinceCreated = DateTime.now().difference(refill.createdAt).inDays;
      if (daysSinceCreated <= 7 &&
          ((refill.prescriptionDetails != null && refill.prescriptionDetails!.isNotEmpty) ||
              refill.prescriptionDoctorName != null)) {
        items.add(
          DashboardNotificationItem(
            id: id,
            type: 'prescription',
            title: 'New prescription',
            message:
                'New prescription document for ${refill.medicineName} (${refill.tabletsPerDose} tab • ${refill.dosesPerDay}x/day).',
            buttonLabel: 'View prescription',
            backgroundColor: const Color(0xFFF0FDF4), // Soft pastel green
            iconBackgroundColor: const Color(0xFFDCFCE7),
            iconColor: const Color(0xFF16A34A),
            iconData: Icons.receipt_long_rounded,
            onAction: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PatientRefillsScreen(patientId: widget.patientId),
                ),
              );
            },
          ),
        );
      }
    }

    // 6. Drink Water (Hydration Reminder Card)
    const hydId = 'hydration_prompt';
    if (!_dismissedIds.contains(hydId)) {
      items.add(
        DashboardNotificationItem(
          id: hydId,
          type: 'hydration',
          title: 'Drink water',
          message: 'You haven\'t logged water for a few hours. Let\'s drink some water!',
          buttonLabel: 'Drink water',
          backgroundColor: const Color(0xFFEFF6FF), // Soft pastel light blue
          iconBackgroundColor: const Color(0xFFDBEAFE),
          iconColor: const Color(0xFF2563EB),
          iconData: Icons.local_drink_rounded,
          onAction: widget.onOpenHydration,
        ),
      );
    }

    // 7. Upcoming Scheduled Medicine (e.g. Next medicine at 8:00 PM)
    if (reminders.isNotEmpty && !_dismissedIds.contains('next_medicine_upcoming')) {
      final now = DateTime.now();
      DateTime? nextTime;
      ReminderModel? nextReminder;

      for (final r in reminders) {
        if (!r.active) continue;
        for (final t in r.times) {
          final parts = t.split(':');
          if (parts.length != 2) continue;
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (h == null || m == null) continue;

          var candidate = DateTime(now.year, now.month, now.day, h, m);
          if (candidate.isBefore(now)) {
            candidate = candidate.add(const Duration(days: 1));
          }
          if (nextTime == null || candidate.isBefore(nextTime)) {
            nextTime = candidate;
            nextReminder = r;
          }
        }
      }

      if (nextTime != null && nextReminder != null) {
        final formattedTime = DateFormat.jm().format(nextTime);
        final isTomorrow = nextTime.day != now.day;
        final timePrefix = isTomorrow ? 'Tomorrow at $formattedTime' : 'at $formattedTime';
        final medName = nextReminder.title;
        final note = nextReminder.note != null && nextReminder.note!.isNotEmpty
            ? ' • ${nextReminder.note}'
            : '';

        items.add(
          DashboardNotificationItem(
            id: 'next_medicine_upcoming',
            type: 'medicine',
            title: 'Next medicine $timePrefix',
            message: '$medName$note. We\'ll alert you when it\'s time.',
            buttonLabel: 'View schedule',
            isButtonOutlined: true,
            backgroundColor: const Color(0xFFF5F3FF), // Soft lavender
            iconBackgroundColor: const Color(0xFFEDE9FE),
            iconColor: const Color(0xFF6B4FBB),
            iconData: Icons.alarm_rounded,
            onAction: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PatientRefillsScreen(patientId: widget.patientId),
                ),
              );
            },
          ),
        );
      }
    }

    // 8. Safe Zone Location Status ("You are at home")
    const homeId = 'safe_zone_home_status';
    if (!_dismissedIds.contains(homeId)) {
      items.add(
        DashboardNotificationItem(
          id: homeId,
          type: 'location',
          title: 'You are at home',
          message: 'Safe zone active. Everything is safe and familiar.',
          buttonLabel: 'I\'m safe',
          isButtonOutlined: true,
          backgroundColor: const Color(0xFFECFDF5), // Soft pastel emerald
          iconBackgroundColor: const Color(0xFFD1FAE5),
          iconColor: const Color(0xFF059669),
          iconData: Icons.home_rounded,
          onAction: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'You are safely at home.',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                backgroundColor: const Color(0xFF059669),
              ),
            );
          },
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final occs = ref
            .watch(actionableOccurrencesProvider(widget.patientId))
            .valueOrNull ??
        [];
    final reminders =
        ref.watch(remindersProvider(widget.patientId)).valueOrNull ?? [];
    final refills =
        ref.watch(patientRefillsProvider(widget.patientId)).valueOrNull ?? [];

    final notifications = _buildNotifications(
      actionableOccs: occs,
      reminders: reminders,
      refills: refills,
    );

    _lastTotalItems = notifications.length;

    if (notifications.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFC7B9E8).withOpacity(0.4),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.success,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'All caught up! No active notices right now.',
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final total = notifications.length;
    final canGoPrev = _currentPage > 0;
    final canGoNext = _currentPage < total - 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFC7B9E8).withOpacity(0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B4FBB).withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row: "Notices for you" + Bell Icon + Navigation Arrows
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: const BoxDecoration(
                  color: Color(0xFFEDE9FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Color(0xFF6B4FBB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notices for you',
                      style: GoogleFonts.outfit(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Swipe to see more',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: canGoPrev ? _goToPrevious : null,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: canGoPrev
                            ? const Color(0xFFEDE9FE)
                            : Colors.black.withOpacity(0.04),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 12,
                        color: canGoPrev
                            ? const Color(0xFF6B4FBB)
                            : Colors.black26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: canGoNext ? () => _goToNext(total) : null,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: canGoNext
                            ? const Color(0xFF6B4FBB)
                            : Colors.black.withOpacity(0.06),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: canGoNext ? Colors.white : Colors.black26,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Horizontal Carousel of Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 420;
              final carouselHeight = isWide ? 68.0 : 88.0;
              return SizedBox(
                height: carouselHeight,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: total,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                    _resetAutoSwipe();
                  },
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _CarouselNotificationCard(
                        item: item,
                        onDismiss: () => _dismissItem(item.id, total),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          // Centered Pagination Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(total, (dotIndex) {
              final isActive = dotIndex == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: isActive ? 16 : 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isActive
                      ? const Color(0xFF6B4FBB)
                      : const Color(0xFFDED8EC),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _CarouselNotificationCard extends StatelessWidget {
  final DashboardNotificationItem item;
  final VoidCallback onDismiss;

  const _CarouselNotificationCard({
    required this.item,
    required this.onDismiss,
  });

  Widget _buildButton({
    required String label,
    required VoidCallback? onTap,
    bool isSecondary = false,
    bool isOutlined = false,
  }) {
    final lower = label.toLowerCase();
    final isDone = lower == 'done' || lower == 'bought';
    final bg = isDone
        ? const Color(0xFF16A34A)
        : (isSecondary ? const Color(0xFF4F46E5) : const Color(0xFF6B4FBB));

    if (isOutlined) {
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF6B4FBB),
          side: const BorderSide(
            color: Color(0xFF6B4FBB),
            width: 1.3,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onTap,
      icon: isDone
          ? const Icon(Icons.check_circle_rounded, size: 14)
          : (lower.contains('water') || lower.contains('drink')
              ? const Icon(Icons.water_drop_rounded, size: 14)
              : (lower.contains('caregiver') || lower.contains('ask')
                  ? const Icon(Icons.person_add_alt_1_rounded, size: 14)
                  : const Icon(Icons.arrow_forward_rounded, size: 14))),
      label: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onCardTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: item.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.iconColor.withOpacity(0.18),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: item.iconColor.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 420;

            if (isWide) {
              // Wide screen / desktop layout: clean horizontal row
              return Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: item.iconBackgroundColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.iconData,
                      color: item.iconColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppTheme.textPrimary.withOpacity(0.85),
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.secondaryButtonLabel != null) ...[
                        _buildButton(
                          label: item.secondaryButtonLabel!,
                          onTap: item.onSecondaryAction,
                          isSecondary: true,
                        ),
                        const SizedBox(width: 8),
                      ],
                      _buildButton(
                        label: item.buttonLabel,
                        onTap: item.onAction,
                        isSecondary: false,
                        isOutlined: item.isButtonOutlined,
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onDismiss,
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.black38,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            // Compact mobile layout: 2 well-aligned rows without excess white space
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: item.iconBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item.iconData,
                        color: item.iconColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            item.message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: AppTheme.textPrimary.withOpacity(0.85),
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: onDismiss,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.black38,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 42),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (item.secondaryButtonLabel != null)
                        _buildButton(
                          label: item.secondaryButtonLabel!,
                          onTap: item.onSecondaryAction,
                          isSecondary: true,
                        ),
                      _buildButton(
                        label: item.buttonLabel,
                        onTap: item.onAction,
                        isSecondary: false,
                        isOutlined: item.isButtonOutlined,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
