import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memora/core/router/app_routes.dart';
import 'package:memora/core/widgets/app_widgets.dart';
import 'package:memora/features/auth/data/auth_providers.dart';

class PatientOnboardingScreen extends ConsumerWidget {
  const PatientOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final patientProfile = ref.watch(patientProfileProvider);
    return Scaffold(
            appBar: AppBar(title: const Text('Welcome to Memora')),
      body: user.when(
        loading: () => const LoadingView(message: 'Loading your ID...'),
        error: (_, __) => const ErrorView(message: 'We could not load your account.'),
        data: (account) {
          if (account == null) {
            return const ErrorView(message: 'Please sign in again.');
          }
          return patientProfile.when(
            loading: () => const LoadingView(message: 'Loading your patient profile...'),
            error: (_, __) => ErrorView(
              message: 'We could not load your patient profile.',
              onRetry: () => ref.invalidate(patientProfileProvider),
            ),
            data: (patient) {
              if (patient == null) return _buildProfileForm(context, ref);
              final id = patient.patientId;
              return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 16),
              const Text('Your Patient ID', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              SelectableText(id, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold,
                      letterSpacing: 8)),
              const SizedBox(height: 12),
              const Text('Give this ID to your caregiver.', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22)),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: id));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Patient ID copied.')));
                  }
                },
                icon: const Icon(Icons.copy), label: const Text('Copy ID'),
              ),
              const SizedBox(height: 24),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Your caregivers can see your location and your reminders.',
                      style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'Continue',
                onPressed: () async {
                  await ref.read(authServiceProvider).finishOnboarding(account.uid);
                  if (context.mounted) context.go(AppRoutes.patientHome);
                },
              ),
            ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildProfileForm(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final age = TextEditingController();
    final details = TextEditingController();

    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Create Patient Profile', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Tell us a little about the person using Memora.'),
          const SizedBox(height: 24),
          TextFormField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (value) => value == null || value.trim().length < 2 ? 'Enter a name' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: age,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Age'),
            validator: (value) {
              final age = int.tryParse(value ?? '');
              return age == null || age < 1 || age > 120 ? 'Enter an age from 1 to 120' : null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: details,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Basic details (optional)', hintText: 'Anything caregivers should know'),
          ),
          const SizedBox(height: 32),
          AppButton(label: 'Save profile', onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            final user = ref.read(currentUserProvider).valueOrNull;
            if (user == null) return;
            try {
              await ref.read(authServiceProvider).savePatientProfile(
                    uid: user.uid,
                    patientId: user.patientId,
                    name: name.text,
                    age: int.parse(age.text),
                    details: details.text,
                  );
              ref.invalidate(currentUserProvider);
              ref.invalidate(patientProfileProvider);
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
                );
              }
            }
          }),
        ],
      ),
    );
  }
}
