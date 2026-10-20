import 'package:go_router/go_router.dart';
import 'package:memora/core/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memora/core/theme/app_theme.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/features/auth/data/auth_providers.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  String? _selectedRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppTheme.primary.withOpacity(0.3), width: 1.5),
                    ),
                    child: const Icon(Icons.diversity_3_rounded,
                        size: 40, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome to Memora',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Select your role to personalize your experience.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 36),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                    children: [
                      _RoleCard(
                        id: 'role_card_patient',
                        role: 'patient',
                        title: 'I am a Patient',
                        description:
                            'I want to link with my caregiver and share updates.',
                        icon: Icons.person_rounded,
                        isSelected: _selectedRole == 'patient',
                        onTap: () => setState(() => _selectedRole = 'patient'),
                      ),
                      const SizedBox(height: 20),
                      _RoleCard(
                        id: 'role_card_caregiver',
                        role: 'caregiver',
                        title: 'I am a Caregiver',
                        description:
                            'I support a patient and manage care coordination.',
                        icon: Icons.favorite_rounded,
                        isSelected: _selectedRole == 'caregiver',
                        onTap: () =>
                            setState(() => _selectedRole = 'caregiver'),
                      ),
                    ],
                    ),
                ),
                  ),

                // Continue button
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: _selectedRole != null
                        ? AppTheme.primaryGradient
                        : null,
                    color: _selectedRole == null
                        ? AppTheme.surface.withOpacity(0.5)
                        : null,
                  ),
                  child: ElevatedButton(
                    onPressed: _selectedRole != null
                        ? () {
                            ref
                                .read(authNotifierProvider.notifier)
                                .clearError();
                            context.push('${AppRoutes.register}?role=$_selectedRole');
                          }
                        : null,
                    child: Text(
                      'Continue',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _selectedRole != null
                            ? AppColors.white
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: GoogleFonts.outfit(fontSize: 13.5, color: AppTheme.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () {
                        context.go(AppRoutes.login);
                      },
                      child: Text(
                        'Log In',
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String id;
  final String role;
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.id,
    required this.role,
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.08)
              : AppTheme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppColors.white.withOpacity(0.08),
            width: isSelected ? 2.0 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.2),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withOpacity(0.2)
                    : AppTheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 26,
                  color: isSelected
                      ? AppTheme.primary
                      : AppTheme.textSecondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
