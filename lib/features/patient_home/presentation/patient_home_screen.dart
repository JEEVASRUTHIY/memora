import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memora/core/theme/app_theme.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/data/models/user_model.dart';
import 'package:memora/data/models/reminder_models.dart';
import 'package:go_router/go_router.dart';
import 'package:memora/core/router/app_routes.dart';
import 'package:memora/features/voice_assistant/presentation/voice_assistant_modal.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:memora/data/services/tts_service.dart';
import 'package:memora/data/services/app_preferences_service.dart';
import 'package:memora/data/models/emergency_contact_model.dart';
import 'package:memora/features/emergency_contacts/data/contact_providers.dart';
import 'package:memora/features/auth/data/auth_providers.dart';
import 'package:memora/features/reminders/data/reminder_providers.dart';
import 'package:memora/features/medicine/presentation/medicine_incoming_reminder_screen.dart';
import 'package:memora/features/medicine/presentation/medicine_already_taken_screen.dart';
import 'package:memora/features/patient_home/presentation/widgets/dashboard_notification_carousel.dart';
import 'package:memora/features/reminders/presentation/patient_refills_screen.dart';
import 'package:memora/features/reminders/data/refill_providers.dart';

/// Home screen for patients.
/// Shows linked caregivers (read-only) and actionable reminders.
class PatientHomeScreen extends ConsumerWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

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
        final remAsync = ref.watch(remindersProvider(patientId));

        // Sync local reminders whenever active reminders update
        ref.listen<AsyncValue<List<ReminderModel>>>(
          remindersProvider(patientId),
          (previous, next) {
            final reminders = next.valueOrNull;
            if (reminders != null && reminders.isNotEmpty) {
              ref
                  .read(reminderServiceProvider)
                  .syncScheduledReminders(patientId, reminders);
            }
          },
        );

        // Auto-show incoming reminder screen with sound notification when reminder comes
        ref.listen<AsyncValue<List<ReminderOccurrenceModel>>>(
          actionableOccurrencesProvider(patientId),
          (previous, next) {
            final prevOccs = previous?.valueOrNull ?? [];
            final nextOccs = next.valueOrNull ?? [];
            for (final occ in nextOccs) {
              final alreadyInPrev = prevOccs.any((p) =>
                  p.occurrenceId == occ.occurrenceId &&
                  p.status == occ.status &&
                  p.snoozeCount == occ.snoozeCount);
              if (!alreadyInPrev && context.mounted) {
                final rem = remAsync.valueOrNull
                    ?.where((r) => r.reminderId == occ.reminderId)
                    .firstOrNull;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MedicineIncomingReminderScreen(
                      occurrence: occ,
                      reminder: rem,
                      autoStartSound: true,
                    ),
                  ),
                );
                break;
              }
            }
          },
        );

        // Prompt for notification permission once and sync existing reminders
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(notificationServiceProvider).requestPermissionsOnce();
          final initialReminders = remAsync.valueOrNull;
          if (initialReminders != null && initialReminders.isNotEmpty) {
            ref
                .read(reminderServiceProvider)
                .syncScheduledReminders(patientId, initialReminders);
          }
        });

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
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    'Patient Account',
                                    style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary),
                                  ),
                                  if (patientId.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () => _showSettingsSheet(
                                        context,
                                        ref,
                                        user,
                                        patientId,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppTheme.primary.withOpacity(0.25),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.badge_rounded,
                                              size: 13,
                                              color: AppTheme.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'ID: $patientId',
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primary,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const _PatientLiveDateTimeCard(),
                        const SizedBox(width: 2),
                        IconButton(
                          onPressed: () => _showSettingsSheet(
                            context,
                            ref,
                            user,
                            patientId,
                          ),
                          icon: const Icon(Icons.settings_outlined,
                              size: 26, color: AppTheme.textPrimary),
                          tooltip: 'Settings',
                        ),
                        IconButton(
                          onPressed: () => _logout(context, ref),
                          icon: const Icon(Icons.logout_rounded,
                              size: 24, color: AppTheme.textSecondary),
                          tooltip: 'Logout',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Dashboard Notification Carousel ("Notices for you")
                    DashboardNotificationCarousel(
                      patientId: patientId,
                      onOpenHydration: () =>
                          _HomeScreenOptionsGrid.showHydration(context, ref),
                    ),
                    const SizedBox(height: 16),

                    // Middle Homescreen Quick Options (2x2 Grid)
                    const _HomeScreenOptionsGrid(),
                    const SizedBox(height: 16),

                    // Prescriptions & Refills Action Button / Card
                    _PrescriptionsAndRefillsCard(patientId: patientId),
                    const SizedBox(height: 24),

                    // Emergency Contacts Preview
                    _EmergencyContactsPreviewCard(patientId: patientId),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          floatingActionButton: Container(
            height: 64,
            width: 64,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.4),
                  blurRadius: 14,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton(
              key: const ValueKey('patient_mic_record_fab'),
              elevation: 0,
              backgroundColor: Colors.transparent,
              tooltip: 'Tap to speak',
              onPressed: () => VoiceAssistantModal.show(
                context: context,
                onOpenContacts: () => context.go(AppRoutes.patientContacts),
              ),
              child: const Icon(
                Icons.mic_rounded,
                size: 32,
                color: AppColors.white,
              ),
            ),
          ),
          bottomNavigationBar: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            color: AppTheme.surface,
            elevation: 8,
            child: SizedBox(
              height: 56,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  InkWell(
                    key: const ValueKey('patient_nav_home'),
                    onTap: () {},
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.home_rounded,
                              color: AppTheme.primary, size: 24),
                          const SizedBox(height: 2),
                          Text(
                            'Home',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Spacer for center docked mic
                  InkWell(
                    key: const ValueKey('patient_nav_emergency_contacts'),
                    onTap: () => context.go(AppRoutes.patientContacts),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.contact_phone_rounded,
                              color: AppTheme.textSecondary, size: 24),
                          const SizedBox(height: 2),
                          Text(
                            'Emergency Contacts',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSettingsSheet(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
    String patientId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetCtx).size.height * 0.88,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.settings_rounded,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Settings',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppTheme.textSecondary),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),

              // Scrollable Settings Content
              Flexible(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Patient Info Summary
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor:
                                  AppTheme.primary.withOpacity(0.12),
                              child: Text(
                                user.name.isNotEmpty
                                    ? user.name.substring(0, 1).toUpperCase()
                                    : 'P',
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name,
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    user.email,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Patient ID Card (Moved inside Settings)
                      _PatientIdCard(patientId: patientId),
                      const SizedBox(height: 16),

                      // 1. Read Aloud Mode
                      const _SettingsReadAloudCard(),
                      const SizedBox(height: 16),

                      // 2. View My Caregiver(s) & Add Caregiver / Relatives
                      _SettingsCaregiversSection(patientId: patientId),
                      const SizedBox(height: 16),

                      // 3. Safe Place & Home Address (Where Am I?)
                      const _SettingsLocationSection(),
                      const SizedBox(height: 16),

                      // App Info
                      _buildAppVersionCard(),
                      const SizedBox(height: 20),

                      // Logout Button inside Settings
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: const BorderSide(color: AppTheme.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _logout(context, ref);
                        },
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: Text(
                          'Log Out',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppVersionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE0E7FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF4F46E5),
            size: 20,
          ),
        ),
        title: Text(
          'App Version',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          'Memora Care 1.0.0',
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
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

class _EmergencyContactsPreviewCard extends ConsumerWidget {
  final String patientId;

  const _EmergencyContactsPreviewCard({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(patientContactsProvider(patientId));

    return contactsAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (contacts) {
        final primaryContact = contacts.where((c) => c.isPrimary).firstOrNull ??
            (contacts.isNotEmpty ? contacts.first : null);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.white.withOpacity(0.08),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.contact_phone_rounded,
                      color: AppTheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Emergency Contacts',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          contacts.isEmpty
                              ? 'No emergency contacts saved'
                              : '${contacts.length} contact${contacts.length == 1 ? '' : 's'} ready for quick call',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.patientContacts),
                    child: Text(
                      'View All',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              if (primaryContact != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVar.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFF59E0B), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${primaryContact.name} (${primaryContact.relationship})',
                          style: GoogleFonts.outfit(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => VoiceAssistantModal.show(
                          context: context,
                          onOpenContacts: () =>
                              context.go(AppRoutes.patientContacts),
                        ),
                        icon: const Icon(Icons.mic_rounded,
                            color: AppTheme.primary, size: 20),
                        tooltip: 'Call with voice',
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// 2x2 middle homescreen options grid matching design mockup.
/// Features the purple "My medicine" card with custom pill illustration
/// and 3 placeholder tiles.
class _HomeScreenOptionsGrid extends ConsumerWidget {
  const _HomeScreenOptionsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final patientId = user?.patientId ?? '';
    final actionableAsync = ref.watch(actionableOccurrencesProvider(patientId));
    final hasActionable = (actionableAsync.valueOrNull ?? []).isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.15,
                    child: InkWell(
                      onTap: () {
                        if (hasActionable) {
                          final occ = actionableAsync.valueOrNull?.firstOrNull;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MedicineIncomingReminderScreen(
                                occurrence: occ,
                                autoStartSound: true,
                              ),
                            ),
                          );
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const MedicineAlreadyTakenScreen(),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B4FBB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Expanded(
                              child: Center(
                                child: Icon(
                                  Icons.medication_rounded,
                                  size: 44,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'My medicine',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.15,
                    child: InkWell(
                      key: const ValueKey('patient_option_reminders'),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PatientRefillsScreen(patientId: patientId),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2292E6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Expanded(
                              child: Center(
                                child: Icon(
                                  Icons.alarm_rounded,
                                  size: 44,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Reminders',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.15,
                    child: InkWell(
                      onTap: () => _showSosDialog(context, ref, patientId),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Expanded(
                              child: Center(
                                child: Icon(
                                  Icons.sos_rounded,
                                  size: 48,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'SOS',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.15,
                    child: InkWell(
                      onTap: () =>
                          _showTextCaregiverDialog(context, ref, patientId),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Expanded(
                              child: Center(
                                child: Icon(
                                  Icons.chat_bubble_rounded,
                                  size: 42,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Text caregiver',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _makeCall(BuildContext context, String phone) async {
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

  static Future<void> _sendSms(BuildContext context, String phone,
      {String? body}) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri(
      scheme: 'sms',
      path: clean,
      queryParameters: body != null && body.isNotEmpty ? {'body': body} : null,
    );
    try {
      final ok = await launchUrl(uri);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SMS opened for $phone')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open SMS: $e')),
        );
      }
    }
  }

  static void showHydration(BuildContext context, WidgetRef ref) {
    int glasses = 4;
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: AppTheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2292E6).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.water_drop_rounded,
                        color: Color(0xFF2292E6),
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Hydration Tracker',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Drink water regularly to stay healthy and refreshed.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2292E6).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF2292E6).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.local_drink_rounded,
                            color: Color(0xFF2292E6),
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$glasses of 8 glasses today',
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2292E6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() => glasses++);
                          TtsService().speak(
                            'Great job! You have logged $glasses glasses of water today. Staying hydrated keeps your mind and body healthy.',
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Logged 1 glass of water! Total: $glasses 💧',
                                style: GoogleFonts.outfit(),
                              ),
                              backgroundColor: const Color(0xFF2292E6),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2292E6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: Text(
                          'I Drank a Glass of Water',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        TtsService().stop();
                        Navigator.pop(dialogCtx);
                      },
                      child: Text(
                        'Close',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static void _showSosDialog(
      BuildContext context, WidgetRef ref, String patientId) {
    final contacts =
        ref.read(patientContactsProvider(patientId)).valueOrNull ?? [];
    final primary =
        contacts.where((c) => c.isPrimary).firstOrNull ?? contacts.firstOrNull;

    TtsService().speak(
        'Emergency SOS screen. Tap call caregiver or call 9 1 1 for immediate assistance.');

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: AppTheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sos_rounded,
                  color: Color(0xFFE53935),
                  size: 46,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Emergency SOS',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFE53935),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Do you need immediate assistance?',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              if (primary != null && primary.phoneNumber.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      _makeCall(context, primary.phoneNumber);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
                    label: Text(
                      'Call ${primary.name} (${primary.relationship})',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _makeCall(context, '911');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE53935),
                    side:
                        const BorderSide(color: Color(0xFFE53935), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.local_hospital_rounded, size: 20),
                  label: Text(
                    'Call 911 (Emergency Services)',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (primary != null && primary.phoneNumber.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      _sendSms(
                        context,
                        primary.phoneNumber,
                        body:
                            'EMERGENCY: I pressed the SOS button on Memora and need urgent help. Please contact me immediately.',
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: BorderSide(color: AppColors.white.withOpacity(0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.message_rounded, size: 20),
                    label: Text(
                      'Send Emergency SMS Alert',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextButton(
                onPressed: () {
                  TtsService().stop();
                  Navigator.pop(dialogCtx);
                },
                child: Text(
                  'Cancel / I am Safe',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showTextCaregiverDialog(
      BuildContext context, WidgetRef ref, String patientId) {
    final contacts =
        ref.read(patientContactsProvider(patientId)).valueOrNull ?? [];
    final primary =
        contacts.where((c) => c.isPrimary).firstOrNull ?? contacts.firstOrNull;

    final presets = [
      '👋 Hi, checking in with you!',
      '📞 Please give me a call when you can.',
      '💊 I took my medicine today.',
      '❤️ I am doing well and feeling good.',
      '❓ I need help with something.',
    ];
    String selectedMessage = presets.first;
    final textController = TextEditingController(text: selectedMessage);

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: AppTheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          color: Color(0xFF2E7D32),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Text Caregiver',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (primary != null)
                              Text(
                                'To: ${primary.name} (${primary.relationship})',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (primary == null || primary.phoneNumber.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Text(
                        'No caregiver phone number found. Please add a caregiver or contact in Settings or Emergency Contacts.',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Text(
                      'Quick message options:',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: presets.map((msg) {
                        final isSelected = selectedMessage == msg;
                        return ChoiceChip(
                          label: Text(
                            msg,
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF2E7D32),
                          backgroundColor: AppTheme.surface,
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                selectedMessage = msg;
                                textController.text = msg;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: textController,
                      maxLines: 2,
                      style: GoogleFonts.outfit(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Message to send',
                        labelStyle:
                            GoogleFonts.outfit(color: AppTheme.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogCtx);
                          _sendSms(
                            context,
                            primary.phoneNumber,
                            body: textController.text.trim(),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          'Send SMS to ${primary.name}',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Elegant card positioned directly below the 4 options grid for quick access to Prescriptions & Refills.
class _PrescriptionsAndRefillsCard extends ConsumerWidget {
  final String patientId;

  const _PrescriptionsAndRefillsCard({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAlerts = ref.watch(activeRefillAlertsProvider(patientId));
    final hasAlerts = activeAlerts.isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasAlerts
                  ? const Color(0xFFE11D48).withOpacity(0.35)
                  : const Color(0xFFC7B9E8).withOpacity(0.5),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B4FBB).withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PatientRefillsScreen(patientId: patientId),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: hasAlerts
                            ? const Color(0xFFFFE4E6)
                            : const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        hasAlerts
                            ? Icons.notification_important_rounded
                            : Icons.receipt_long_rounded,
                        color: hasAlerts
                            ? const Color(0xFFE11D48)
                            : const Color(0xFF6B4FBB),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Prescriptions & Refills',
                                style: GoogleFonts.outfit(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              if (hasAlerts)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE11D48),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${activeAlerts.length} Due Soon',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Active schedules, bills & pharmacy info',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8),
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Front Home Screen Live Date & Time Card
// ─────────────────────────────────────────────────────────────────────────────

class _PatientLiveDateTimeCard extends ConsumerStatefulWidget {
  const _PatientLiveDateTimeCard();

  @override
  ConsumerState<_PatientLiveDateTimeCard> createState() =>
      _PatientLiveDateTimeCardState();
}

class _PatientLiveDateTimeCardState
    extends ConsumerState<_PatientLiveDateTimeCard> {
  late DateTime _currentTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _greeting() {
    final hour = _currentTime.hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  IconData _greetingIcon() {
    final hour = _currentTime.hour;
    if (hour >= 6 && hour < 17) return Icons.wb_sunny_rounded;
    if (hour >= 17 && hour < 20) return Icons.wb_twilight_rounded;
    return Icons.nightlight_round;
  }

  Color _greetingColor() {
    final hour = _currentTime.hour;
    if (hour >= 6 && hour < 17) return const Color(0xFFD97706);
    if (hour >= 17 && hour < 20) return const Color(0xFFEA580C);
    return const Color(0xFF4F46E5);
  }

  void _speakDateTime() {
    final dayOfWeek = DateFormat('EEEE').format(_currentTime);
    final dateStr = DateFormat('MMMM d, y').format(_currentTime);
    final timeStr = DateFormat('h:mm a').format(_currentTime);
    TtsService().speak(
      "Today is $dayOfWeek, $dateStr. The time right now is $timeStr in the ${_greeting().toLowerCase()}.",
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayOfWeek = DateFormat('EEE').format(_currentTime);
    final monthDay = DateFormat('MMM d').format(_currentTime);
    final timeStr = DateFormat('h:mm a').format(_currentTime);

    return InkWell(
      onTap: _speakDateTime,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFC7B9E8),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6B4FBB).withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _greetingIcon(),
              size: 20,
              color: _greetingColor(),
            ),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.3,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$dayOfWeek, $monthDay',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    height: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _speakDateTime,
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.volume_up_rounded,
                  color: AppTheme.primary,
                  size: 16,
                ),
              ),
              tooltip: 'Read Date and Time Aloud',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings: 1. Read Aloud Mode Card
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsReadAloudCard extends ConsumerWidget {
  const _SettingsReadAloudCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    final readAloudEverytime = prefs.readAloudEverytime;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.volume_up_rounded,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice & Read Aloud',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Choose how you want Memora to speak to you',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Option 1: Read aloud everytime
          InkWell(
            onTap: () {
              ref
                  .read(appPreferencesProvider.notifier)
                  .setReadAloudEverytime(true);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: readAloudEverytime
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: readAloudEverytime
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFE2E8F0),
                  width: readAloudEverytime ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  Radio<bool>(
                    value: true,
                    groupValue: readAloudEverytime,
                    activeColor: const Color(0xFF16A34A),
                    onChanged: (val) {
                      if (val != null) {
                        ref
                            .read(appPreferencesProvider.notifier)
                            .setReadAloudEverytime(val);
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Read aloud every time',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Automatically speaks reminders, medicine doses, and confirmations out loud.',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Option 2: Read aloud when speaker button is pressed
          InkWell(
            onTap: () {
              ref
                  .read(appPreferencesProvider.notifier)
                  .setReadAloudEverytime(false);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: !readAloudEverytime
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !readAloudEverytime
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFE2E8F0),
                  width: !readAloudEverytime ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  Radio<bool>(
                    value: false,
                    groupValue: readAloudEverytime,
                    activeColor: const Color(0xFF16A34A),
                    onChanged: (val) {
                      if (val != null) {
                        ref
                            .read(appPreferencesProvider.notifier)
                            .setReadAloudEverytime(val);
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Read aloud when speaker button is pressed',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Only speaks out loud when you tap a speaker icon on any screen.',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings: 2. View My Caregiver(s) & Add Caregiver / Relatives
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsCaregiversSection extends ConsumerWidget {
  final String patientId;
  const _SettingsCaregiversSection({required this.patientId});

  Future<void> _makeCall(BuildContext context, String phone) async {
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

  Future<void> _sendSms(BuildContext context, String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri(scheme: 'sms', path: clean);
    try {
      final ok = await launchUrl(uri);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SMS opened for $phone')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open messages: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linksAsync = ref.watch(patientLinksProvider);
    final contactsAsync = ref.watch(patientContactsProvider(patientId));

    final activeLinks =
        (linksAsync.valueOrNull ?? []).where((l) => l.isActive).toList();

    final allContacts = contactsAsync.valueOrNull ?? [];
    final caregiverContacts = allContacts.where((c) {
      final rel = c.relationship.toLowerCase();
      return rel.contains('caregiver') ||
          rel.contains('parent') ||
          rel.contains('mother') ||
          rel.contains('father') ||
          rel.contains('daughter') ||
          rel.contains('son') ||
          rel.contains('relative') ||
          rel.contains('spouse');
    }).toList();

    final totalCount = activeLinks.length + caregiverContacts.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.supervised_user_circle_rounded,
                  color: Color(0xFF7C3AED),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Caregivers & Relatives',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      totalCount == 0
                          ? 'No caregivers assigned'
                          : '$totalCount caregiver${totalCount == 1 ? '' : 's'} assigned to your care',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: totalCount > 0
                      ? const Color(0xFFEDE9FE)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$totalCount Assigned',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: totalCount > 0
                        ? const Color(0xFF7C3AED)
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // List of Active Caregiver Links
          if (activeLinks.isNotEmpty) ...[
            ...activeLinks.map((link) {
              return FutureBuilder<UserModel?>(
                future: ref
                    .read(linkRepositoryProvider)
                    .getCaregiverUser(link.caregiverUid),
                builder: (context, snap) {
                  final caregiver = snap.data;
                  final name = caregiver?.name.isNotEmpty == true
                      ? caregiver!.name
                      : (link.caregiverName.isNotEmpty
                          ? link.caregiverName
                          : 'Caregiver');
                  final phone = caregiver?.email.isNotEmpty == true
                      ? '+1 (555) 019-2834'
                      : '+1 (555) 234-5678';
                  final email = caregiver?.email ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: link.isPrimary
                              ? const Color(0xFFEDE9FE)
                              : const Color(0xFFE0F2FE),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'C',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: link.isPrimary
                                  ? const Color(0xFF7C3AED)
                                  : const Color(0xFF0284C7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: link.isPrimary
                                          ? const Color(0xFFEDE9FE)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      link.isPrimary ? 'Primary' : 'Secondary',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: link.isPrimary
                                            ? const Color(0xFF7C3AED)
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                phone,
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (email.isNotEmpty)
                                Text(
                                  email,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.phone_rounded,
                              color: Color(0xFF16A34A), size: 20),
                          tooltip: 'Call $name',
                          onPressed: () => _makeCall(context, phone),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_rounded,
                              color: Color(0xFF2563EB), size: 20),
                          tooltip: 'Message $name',
                          onPressed: () => _sendSms(context, phone),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ],

          // List of Added Family / Relatives / Emergency Contacts
          if (caregiverContacts.isNotEmpty) ...[
            ...caregiverContacts.map((contact) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFFEF3C7),
                      child: Text(
                        contact.name.isNotEmpty
                            ? contact.name[0].toUpperCase()
                            : 'F',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                contact.name,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  contact.relationship,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            contact.phoneNumber,
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.phone_rounded,
                          color: Color(0xFF16A34A), size: 20),
                      tooltip: 'Call ${contact.name}',
                      onPressed: () => _makeCall(context, contact.phoneNumber),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_rounded,
                          color: Color(0xFF2563EB), size: 20),
                      tooltip: 'Message ${contact.name}',
                      onPressed: () => _sendSms(context, contact.phoneNumber),
                    ),
                  ],
                ),
              );
            }),
          ],

          // Empty state if no caregivers
          if (totalCount == 0) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      color: AppTheme.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No caregivers connected yet. Share your Patient ID ($patientId) or send an invite below.',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Add Caregiver / Relative / Parent Action Button
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () => _showAddCaregiverDialog(context, ref, patientId),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: Text(
                'Add Caregiver / Relative / Parent',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings: 3. Location Recording & Home Address (Where Am I?)
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsLocationSection extends ConsumerWidget {
  const _SettingsLocationSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF0284C7),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Safe Locations (Where Am I?)',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Set your address so Memora can tell you when you are safe at home',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Address Display Box (e.g. 123 Maple Ave -> Home)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.home_rounded,
                              size: 14, color: Color(0xFF16A34A)),
                          const SizedBox(width: 4),
                          Text(
                            prefs.homeFriendlyName,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _showEditHomeAddressDialog(context, ref),
                      icon: const Icon(Icons.edit_rounded, size: 14),
                      label: Text(
                        'Edit Address',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  prefs.homeAddress,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.record_voice_over_rounded,
                          size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'When you ask "Where am I?", Memora reads aloud:\n"You are safely at home in your cozy living room."',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFF1E40AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Simulation / Testing Switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: prefs.isSimulatedAway
                  ? const Color(0xFFFFFBEB)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: prefs.isSimulatedAway
                    ? const Color(0xFFFCD34D)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            prefs.isSimulatedAway
                                ? Icons.directions_walk_rounded
                                : Icons.home_rounded,
                            size: 16,
                            color: prefs.isSimulatedAway
                                ? const Color(0xFFD97706)
                                : const Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            prefs.isSimulatedAway
                                ? 'Status: Away on Oak Street'
                                : 'Status: Safe at Home',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        prefs.isSimulatedAway
                            ? 'Asks: "Would you like to call your emergency contact?" with a quick-call button.'
                            : 'Toggle switch to test away-from-home behavior.',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: prefs.isSimulatedAway,
                  activeColor: const Color(0xFFD97706),
                  onChanged: (val) {
                    ref
                        .read(appPreferencesProvider.notifier)
                        .setSimulatedAway(val);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog: Add Caregiver / Relatives / Parent
// ─────────────────────────────────────────────────────────────────────────────

void _showAddCaregiverDialog(
  BuildContext context,
  WidgetRef ref,
  String patientId,
) {
  final nameCtrl = TextEditingController();
  final contactCtrl = TextEditingController();
  String identifierType = 'phone'; // 'phone', 'email', 'memoraId'
  String relationship = 'Caregiver';

  showDialog(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add_rounded,
                    color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Add Caregiver / Family',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invite a caregiver, parent, or family member to support you:',
                  style: GoogleFonts.outfit(
                      fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 14),
                // Relationship Dropdown
                Text(
                  'Relationship',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVar.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: relationship,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                            value: 'Caregiver', child: Text('Caregiver')),
                        DropdownMenuItem(
                            value: 'Parent',
                            child: Text('Parent / Father / Mother')),
                        DropdownMenuItem(
                            value: 'Daughter', child: Text('Daughter')),
                        DropdownMenuItem(value: 'Son', child: Text('Son')),
                        DropdownMenuItem(
                            value: 'Spouse', child: Text('Spouse / Partner')),
                        DropdownMenuItem(
                            value: 'Relative', child: Text('Family Relative')),
                        DropdownMenuItem(
                            value: 'Guardian',
                            child: Text('Guardian / Trusted Friend')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => relationship = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Full Name
                Text(
                  'Full Name',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Sarah Jenkins',
                    hintStyle: GoogleFonts.outfit(
                        color: AppTheme.textSecondary.withOpacity(0.5)),
                    filled: true,
                    fillColor: AppTheme.surfaceVar.withOpacity(0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),
                // Invite Via Selector
                Text(
                  'Invite Via',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    ChoiceChip(
                      label: Text('Phone',
                          style: GoogleFonts.outfit(fontSize: 12)),
                      selected: identifierType == 'phone',
                      onSelected: (s) =>
                          setDialogState(() => identifierType = 'phone'),
                    ),
                    ChoiceChip(
                      label: Text('Email',
                          style: GoogleFonts.outfit(fontSize: 12)),
                      selected: identifierType == 'email',
                      onSelected: (s) =>
                          setDialogState(() => identifierType = 'email'),
                    ),
                    ChoiceChip(
                      label: Text('Memora ID',
                          style: GoogleFonts.outfit(fontSize: 12)),
                      selected: identifierType == 'memoraId',
                      onSelected: (s) =>
                          setDialogState(() => identifierType = 'memoraId'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contactCtrl,
                  keyboardType: identifierType == 'phone'
                      ? TextInputType.phone
                      : (identifierType == 'email'
                          ? TextInputType.emailAddress
                          : TextInputType.text),
                  decoration: InputDecoration(
                    hintText: identifierType == 'phone'
                        ? 'e.g. +1 555-0199'
                        : (identifierType == 'email'
                            ? 'e.g. caregiver@example.com'
                            : 'e.g. CG-99214'),
                    hintStyle: GoogleFonts.outfit(
                        color: AppTheme.textSecondary.withOpacity(0.5)),
                    filled: true,
                    fillColor: AppTheme.surfaceVar.withOpacity(0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Color(0xFF2563EB), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The other person must have a caregiver account and accept this request to link.',
                          style: GoogleFonts.outfit(
                              fontSize: 11.5, color: const Color(0xFF1E40AF)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Cancel',
                  style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final contactVal = contactCtrl.text.trim();
                if (name.isEmpty || contactVal.isEmpty) return;
                Navigator.pop(dialogCtx);

                try {
                  final newContact = EmergencyContactModel(
                    id: '',
                    patientId: patientId,
                    name: name,
                    phoneNumber: identifierType == 'phone'
                        ? contactVal
                        : '+1 (555) 019-2834',
                    relationship: relationship,
                    isPrimary: false,
                    createdAt: DateTime.now(),
                  );
                  await ref
                      .read(contactRepositoryProvider)
                      .createContact(newContact);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Request sent to $name! Once accepted on their caregiver account, they will be connected.',
                        ),
                        backgroundColor: const Color(0xFF15803D),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Invitation request sent to $name ($contactVal).')),
                    );
                  }
                }
              },
              child: Text('Send Request',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog: Edit Home Location Address
// ─────────────────────────────────────────────────────────────────────────────

void _showEditHomeAddressDialog(BuildContext context, WidgetRef ref) {
  final current = ref.read(appPreferencesProvider);
  final addrCtrl = TextEditingController(text: current.homeAddress);
  final nameCtrl = TextEditingController(text: current.homeFriendlyName);

  showDialog(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.home_rounded,
                color: Color(0xFF16A34A), size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            'Edit Home Location',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set your address so when you ask "Where am I?", Memora can tell you that you are safely at home.',
            style: GoogleFonts.outfit(
                fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          Text(
            'Location Label',
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. Home, Living Room',
              filled: true,
              fillColor: AppTheme.surfaceVar.withOpacity(0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Address',
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: addrCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'e.g. 123 Maple Avenue, Springfield',
              filled: true,
              fillColor: AppTheme.surfaceVar.withOpacity(0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: Text('Cancel',
              style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: AppColors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            final addr = addrCtrl.text.trim();
            final name = nameCtrl.text.trim();
            if (addr.isNotEmpty) {
              ref.read(appPreferencesProvider.notifier).setHomeAddress(
                    addr,
                    friendlyName: name.isNotEmpty ? name : 'Home',
                  );
            }
            Navigator.pop(dialogCtx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Home address updated successfully!')),
            );
          },
          child: Text('Save Address',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}


