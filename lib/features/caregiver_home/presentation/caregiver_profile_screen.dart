import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memora/core/router/app_routes.dart';
import 'package:memora/core/theme/app_theme.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/widgets/app_widgets.dart';
import 'package:memora/features/auth/data/auth_providers.dart';
import 'package:memora/data/models/link_model.dart';

class CaregiverProfileScreen extends ConsumerWidget {
  const CaregiverProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final links = ref.watch(caregiverLinksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: user.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load your profile.')),
        data: (account) {
          if (account == null) return const Center(child: Text('Please sign in again.'));
          final link = links.valueOrNull?.where((item) =>
              item.status == 'active' || item.status == 'pending').firstOrNull;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.primaryContainer,
                  child: Text(
                    account.name.trim().isEmpty ? '?' : account.name.trim()[0].toUpperCase(),
                    style: TextStyle(fontSize: 28, color: AppTheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(account.name, textAlign: TextAlign.center, style: AppTheme.heading1(context)),
              const SizedBox(height: 4),
              Text(account.email, textAlign: TextAlign.center, style: AppTheme.bodySmall(context)),
              const SizedBox(height: 32),
              Text('Linked patient', style: AppTheme.heading2(context)),
              const SizedBox(height: 12),
              if (link == null)
                _NoPatientLink(onLink: () => context.push(AppRoutes.linkPatient))
              else
                _PatientLinkRow(link: link),
            ],
          );
        },
      ),
    );
  }
}

class _NoPatientLink extends StatelessWidget {
  final VoidCallback onLink;
  const _NoPatientLink({required this.onLink});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('No patient linked', style: AppTheme.body(context)),
        const SizedBox(height: 12),
        AppButton(label: 'Link to a Patient', onPressed: onLink),
      ],
    );
  }
}

class _PatientLinkRow extends ConsumerWidget {
  final LinkModel link;
  const _PatientLinkRow({required this.link});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(linkedPatientProfileProvider(link.patientId));
    final name = patient.valueOrNull?.name.trim();
    final status = link.status == 'pending'
        ? 'Waiting for approval'
        : 'Connected · You are the ${link.isPrimary ? 'primary' : 'backup'} caregiver';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name != null && name.isNotEmpty)
          Text(name, style: AppTheme.body(context)),
        Text('Patient ID: ${link.patientId}', style: AppTheme.body(context)),
        const SizedBox(height: 4),
        Text(status, style: AppTheme.bodySmall(context)),
      ],
    );
  }
}