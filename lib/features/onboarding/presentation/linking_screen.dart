import 'package:go_router/go_router.dart';
import 'package:memora/core/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memora/core/theme/app_theme.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/constants/app_constants.dart';
import 'package:memora/features/auth/data/auth_providers.dart';

/// Screen where a caregiver enters a patient's 8-char ID to link accounts.
/// After linking:
///   - If primary → success message with immediate access.
///   - If secondary → "Waiting for approval" message.
class LinkingScreen extends ConsumerStatefulWidget {
  const LinkingScreen({super.key});

  @override
  ConsumerState<LinkingScreen> createState() => _LinkingScreenState();
}

class _LinkingScreenState extends ConsumerState<LinkingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _patientIdController = TextEditingController();

  @override
  void dispose() {
    _patientIdController.dispose();
    super.dispose();
  }

  Future<void> _submit(String caregiverUid) async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(linkNotifierProvider(caregiverUid).notifier)
        .requestLink(_patientIdController.text.trim().toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
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

        final linkState = ref.watch(linkNotifierProvider(user.uid));

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),

                    // Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTheme.secondary.withOpacity(0.3),
                              width: 1.5),
                        ),
                        child: const Icon(Icons.link_rounded,
                            size: 48, color: AppTheme.secondary),
                      ),
                    ),
                    const SizedBox(height: 32),

                    Text(
                      'Link to a Patient',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Enter the ${AppConstants.patientIdLength}-character Patient ID that your patient can share with you from their app.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontSize: 15, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 40),

                    // Error banner
                    if (linkState.errorMessage != null)
                      _ErrorBanner(linkState.errorMessage!),

                    // Success banners — differentiate primary vs secondary
                    if (linkState.success && linkState.resultStatus == 'active')
                      _SuccessBanner(
                        linkState.resultRole == 'primary'
                            ? 'Linked as primary caregiver!'
                            : 'Linked successfully!',
                      ),
                    if (linkState.success && linkState.resultStatus == 'pending')
                      _PendingBanner(
                        'Request sent! Waiting for the primary caregiver to approve you.',
                      ),

                    Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _patientIdController,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          letterSpacing: 4,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: AppConstants.patientIdLength,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9]')),
                          UpperCaseTextFormatter(),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Patient ID',
                          hintText: 'e.g. SSZ8LX',
                          prefixIcon: Icon(Icons.person_search_rounded,
                              color: AppTheme.textSecondary),
                          counterStyle:
                              TextStyle(color: AppTheme.textSecondary),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter a Patient ID';
                          }
                          if (v.trim().length != AppConstants.patientIdLength) {
                            return 'Patient ID must be exactly ${AppConstants.patientIdLength} characters';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 32),

                    _GradientButton(
                      id: 'linking_submit_button',
                      label: 'Link Patient',
                      isLoading: linkState.isLoading,
                      onPressed: () => _submit(user.uid),
                    ),
                    const SizedBox(height: 24),

                    TextButton(
                      onPressed: () => context.go(AppRoutes.caregiverHome),
                      child: Text(
                        'Skip for now',
                        style: GoogleFonts.outfit(
                            color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.error.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: GoogleFonts.outfit(
                    color: AppTheme.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  final String message;
  const _SuccessBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: AppTheme.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: GoogleFonts.outfit(
                    color: AppTheme.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  final String message;
  const _PendingBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: GoogleFonts.outfit(
                    color: AppColors.warning,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;
  final String id;

  const _GradientButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    required this.id,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isLoading ? null : AppTheme.primaryGradient,
        color: isLoading ? AppTheme.surface.withOpacity(0.5) : null,
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                ),
              )
            : Text(
                label,
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.white),
              ),
      ),
    );
  }
}

/// Forces text field input to uppercase.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
