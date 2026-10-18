import 'package:go_router/go_router.dart';
import 'package:memora/core/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memora/core/theme/app_theme.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/data/models/link_model.dart';
import 'package:memora/data/models/user_model.dart';
import 'package:memora/features/auth/data/auth_providers.dart';

/// Screen shown to the PRIMARY caregiver.
/// Lists all secondary caregivers (pending / active) with approve/reject/remove actions.
class CaregiversScreen extends ConsumerWidget {
  const CaregiversScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final caregiverLinksAsync = ref.watch(primaryPatientLinksProvider);
    final mgmt = ref.watch(caregiverManagementProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go(AppRoutes.caregiverHome),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Manage Caregivers',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (userAsync.valueOrNull?.isCaregiver == true)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => _addBackup(context, ref),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Add backup'),
                    ),
                  ),
                ),
              // Error from management actions
              if (mgmt is AsyncError)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      mgmt.error.toString().replaceFirst('Exception: ', ''),
                      style: GoogleFonts.outfit(color: AppTheme.error, fontSize: 13),
                    ),
                  ),
                ),
              Expanded(
                child: userAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (user) {
                    if (user == null) return const SizedBox();
                    return caregiverLinksAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) =>
                          Center(child: Text('Error loading links: $e')),
                      data: (links) {
                        // Only show secondary links; primary is the viewer
                        final secondaryLinks = links
                            .where((l) => l.role == 'secondary')
                            .toList()
                            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

                        if (secondaryLinks.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.group_outlined,
                                    size: 64, color: AppTheme.textSecondary),
                                const SizedBox(height: 16),
                                Text(
                                  'No secondary caregivers yet',
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.textSecondary,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Up to 3 additional caregivers can request\naccess and await your approval.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.textSecondary.withOpacity(0.7),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: secondaryLinks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final link = secondaryLinks[i];
                            return _CaregiverLinkCard(
                              link: link,
                              onApprove: link.isPending
                                  ? () => _respond(context, ref, link.linkId, true)
                                  : null,
                              onReject: link.isPending
                                  ? () => _respond(context, ref, link.linkId, false)
                                  : null,
                              onRemove: link.isActive
                                  ? () => _remove(context, ref, link.linkId)
                                  : null,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _respond(
      BuildContext context, WidgetRef ref, String linkId, bool approve) async {
    await ref
        .read(caregiverManagementProvider.notifier)
        .respondToLink(linkId, approve);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve ? 'Caregiver approved.' : 'Request rejected.'),
        backgroundColor: approve ? AppTheme.accent : AppTheme.error,
      ));
    }
  }

  Future<void> _remove(
      BuildContext context, WidgetRef ref, String linkId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Remove caregiver?',
            style: GoogleFonts.outfit(color: AppTheme.textPrimary)),
        content: Text('This caregiver will lose access to the patient.',
            style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove',
                style: GoogleFonts.outfit(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await ref
          .read(caregiverManagementProvider.notifier)
          .removeSecondary(linkId);
    }
  }

  Future<void> _addBackup(BuildContext context, WidgetRef ref) async {
    final email = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add backup caregiver'),
        content: TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Caregiver email'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, email.text), child: const Text('Add')),
        ],
      ),
    );
    email.dispose();
    if (value == null || value.trim().isEmpty || !context.mounted) return;
    final primary = ref.read(caregiverLinksProvider).valueOrNull
        ?.where((link) => link.isPrimary && link.isActive).firstOrNull;
    if (primary == null) return;
    final ok = await ref.read(linkNotifierProvider(primary.caregiverUid).notifier)
        .addBackupCaregiver(primary.patientId, value.trim());
    if (context.mounted && !ok) {
      final error = ref.read(linkNotifierProvider(primary.caregiverUid)).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Could not add backup.')));
    }
  }
}

class _CaregiverLinkCard extends ConsumerWidget {
  final LinkModel link;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onRemove;

  const _CaregiverLinkCard({
    required this.link,
    this.onApprove,
    this.onReject,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPending = link.status == 'pending';

    return FutureBuilder<UserModel?>(
      future: ref.read(linkRepositoryProvider).getCaregiverUser(link.caregiverUid),
      builder: (context, snapshot) {
        final name = snapshot.data?.name ?? '…';
        final email = snapshot.data?.email ?? link.caregiverUid;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPending
                  ? AppColors.warning.withOpacity(0.4)
                  : AppColors.white.withOpacity(0.08),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isPending
                        ? AppColors.warning.withOpacity(0.2)
                        : AppTheme.primary.withOpacity(0.2),
                    child: Icon(
                      isPending
                          ? Icons.hourglass_top_rounded
                          : Icons.person_rounded,
                      color: isPending ? AppColors.warning : AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: GoogleFonts.outfit(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        Text(email,
                            style: GoogleFonts.outfit(
                                color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  _StatusChip(link.status),
                ],
              ),
              if (isPending) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: AppTheme.error.withOpacity(0.6)),
                          foregroundColor: AppTheme.error,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Reject',
                            style: GoogleFonts.outfit(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onApprove,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Approve',
                            style: GoogleFonts.outfit(
                                fontSize: 13, color: AppColors.white)),
                      ),
                    ),
                  ],
                ),
              ] else if (link.isActive) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.person_remove_rounded,
                        size: 16, color: AppTheme.error),
                    label: Text('Remove',
                        style: GoogleFonts.outfit(
                            color: AppTheme.error, fontSize: 13)),
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

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => AppTheme.accent,
      'pending' => AppColors.warning,
      'rejected' => AppTheme.error,
      _ => AppTheme.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: GoogleFonts.outfit(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
