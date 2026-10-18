import 'package:go_router/go_router.dart';
import 'package:memora/core/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memora/core/theme/app_theme.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/constants/app_constants.dart';
import 'package:memora/data/models/link_model.dart';
import 'package:memora/features/auth/data/auth_providers.dart';

/// Home screen for caregivers.
/// - Primary caregiver: full dashboard access + Caregivers management button.
/// - Secondary (active): read-only dashboard access.
/// - Secondary (pending): dashboard with a waiting-for-approval banner.
class CaregiverHomeScreen extends ConsumerWidget {
  const CaregiverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final linksAsync = ref.watch(caregiverLinksProvider);

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

        // Determine this caregiver's link status
        return linksAsync.when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => _buildDashboard(context, ref, user.name, null, 0),
          data: (links) {
            final visibleLinks = links.where((link) =>
                link.status == AppConstants.linkStatusActive ||
                link.status == AppConstants.linkStatusPending).toList();
            if (visibleLinks.isEmpty) {
              // No link yet → show link-patient prompt
              return _buildNoLinkScreen(context, ref, user.name);
            }

            // Find the caregiver's role: look for their own link doc
            final myLink = visibleLinks.firstWhere(
              (l) => l.caregiverUid == user.uid,
              orElse: () => visibleLinks.first,
            );

            // Count pending secondaries for badge (primary only)
            final pendingCount = myLink.isPrimary
                ? links
                    .where((l) =>
                        l.role == AppConstants.linkRoleSecondary &&
                        l.status == AppConstants.linkStatusPending)
                    .length
                : 0;

            return _buildDashboard(
                  context, ref, user.name, myLink, pendingCount,
                  isPending: myLink.status == AppConstants.linkStatusPending);
          },
        );
      },
    );
  }

  Widget _buildNoLinkScreen(
      BuildContext context, WidgetRef ref, String name) {
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
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${name.split(' ').first}!',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Caregiver Account',
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
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _LinkPatientCard(
                  onTap: () => context.push(AppRoutes.linkPatient),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingScreen(
      BuildContext context, WidgetRef ref, String name) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.hourglass_top_rounded,
                        color: AppColors.warning, size: 56),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Waiting for Approval',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your request to be a secondary caregiver is pending. The primary caregiver will need to approve you before you can access the patient\'s information.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                        fontSize: 15, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 40),
                  OutlinedButton.icon(
                    onPressed: () => _logout(context, ref),
                    icon: const Icon(Icons.logout_rounded,
                        color: AppTheme.textSecondary),
                    label: Text('Logout',
                        style: GoogleFonts.outfit(
                            color: AppTheme.textSecondary)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppTheme.textSecondary.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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

  Widget _buildDashboard(BuildContext context, WidgetRef ref, String name,
      LinkModel? myLink, int pendingCount, {bool isPending = false}) {
    final isPrimary = myLink?.isPrimary ?? false;
    final patientId = myLink?.patientId ?? '';
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
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${name.split(' ').first}!',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            isPrimary
                                ? 'Primary Caregiver'
                                : 'Secondary Caregiver',
                            style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: isPrimary
                                    ? AppTheme.primary
                                    : AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => context.push(AppRoutes.caregiverProfile),
                      borderRadius: BorderRadius.circular(24),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primaryContainer,
                        child: Text(
                          name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
                          style: GoogleFonts.outfit(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isPrimary)
                      _CaregiversBadgeButton(
                        pendingCount: pendingCount,
                        onTap: () => context.push(AppRoutes.careCircle),
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
                if (isPending) ...[
                  _pendingBanner(),
                  const SizedBox(height: 20),
                ],
                // Reminders card
                _DashboardCard(
                  icon: Icons.alarm_rounded,
                  iconColor: AppTheme.primary,
                  title: 'Reminders',
                  subtitle: isPrimary
                      ? 'Create and manage patient reminders'
                      : 'View patient reminders',
                  onTap: patientId.isNotEmpty
                      ? () => context.push(AppRoutes.caregiverReminders)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pendingBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withOpacity(0.35)),
      ),
      child: const Row(
        children: [
          Icon(Icons.hourglass_top_rounded, color: AppColors.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text('Waiting for the patient\'s primary caregiver to approve your link.'),
          ),
        ],
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

class _CaregiversBadgeButton extends StatelessWidget {
  final int pendingCount;
  final VoidCallback onTap;

  const _CaregiversBadgeButton(
      {required this.pendingCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.group_rounded, color: AppTheme.textSecondary),
          tooltip: 'Manage Caregivers',
        ),
        if (pendingCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: const BoxDecoration(
                color: AppColors.warning,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$pendingCount',
                style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _LinkPatientCard extends StatelessWidget {
  final VoidCallback onTap;
  const _LinkPatientCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.secondaryAccent, AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.secondary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_rounded,
                  color: AppColors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Link a Patient',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                  Text(
                    'Enter your patient\'s ID to connect',
                    style: GoogleFonts.outfit(
                        fontSize: 14, color: AppColors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.white70, size: 20),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _DashboardCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: iconColor.withOpacity(0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: iconColor.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.outfit(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: GoogleFonts.outfit(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
