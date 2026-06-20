import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _patientIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _patientIdController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: AppTheme.accent),
            const SizedBox(width: 8),
            Text(
              'Patient ID copied to clipboard!',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: AppTheme.surface,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _linkPatient() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final patientId = _patientIdController.text.trim();

    final success = await authProvider.linkPatient(patientId);

    if (success && mounted) {
      _patientIdController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.link_rounded, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(
                'Successfully linked with patient!',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: AppTheme.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userService = Provider.of<UserService>(context, listen: false);
    final user = authProvider.userModel;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.bgGradient,
        ),
        child: SafeArea(
          child: user == null
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                user.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary, size: 28),
                            onPressed: () {
                              authProvider.logout();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // User Info Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Profile Info',
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  _buildRoleBadge(user.role),
                                ],
                              ),
                              const Divider(height: 24, color: Colors.white10),
                              _buildInfoRow(Icons.email_outlined, 'Contact', user.contactDetails),
                              const SizedBox(height: 12),
                              _buildInfoRow(Icons.fingerprint_rounded, 'User ID', user.userId),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Linking section heading
                      Text(
                        'Caregiver Link Status',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Linking logic
                      Expanded(
                        child: SingleChildScrollView(
                          child: user.isPatient
                              ? _buildPatientLinkingUI(user, userService)
                              : _buildCaregiverLinkingUI(user, authProvider, userService),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    final isPatient = role == 'Patient';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: (isPatient ? AppTheme.primary : AppTheme.secondary).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isPatient ? AppTheme.primary : AppTheme.secondary).withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Text(
        role,
        style: GoogleFonts.outfit(
          color: isPatient ? AppTheme.primary : AppTheme.secondary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 12)),
              Text(
                value,
                style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPatientLinkingUI(UserModel patient, UserService userService) {
    if (patient.linkedCaregiverId != null) {
      // Stream user details of the caregiver
      return StreamBuilder<UserModel?>(
        stream: userService.watchUserProfile(patient.linkedCaregiverId!),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildStatusCard(
              icon: Icons.error_outline_rounded,
              color: AppTheme.error,
              title: 'Error loading caregiver info',
              subtitle: 'Caregiver ID: ${patient.linkedCaregiverId}',
            );
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return _buildStatusCard(
              icon: Icons.link_rounded,
              color: AppTheme.accent,
              title: 'Linked with Caregiver',
              subtitle: 'Caregiver ID: ${patient.linkedCaregiverId}',
            );
          }

          final caregiver = snapshot.data!;
          final caregiverName = caregiver.name;
          final caregiverContact = caregiver.contactDetails;

          return Card(
            color: AppTheme.surface.withOpacity(0.6),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.link_rounded, color: AppTheme.accent, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status: Connected',
                            style: GoogleFonts.outfit(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Connected to Caregiver',
                            style: GoogleFonts.outfit(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                  const Divider(height: 32, color: Colors.white10),
                  _buildInfoRow(Icons.person_outline_rounded, 'Caregiver Name', caregiverName),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.phone_outlined, 'Caregiver Contact', caregiverContact),
                ],
              ),
            ),
          );
        },
      );
    }

    return Card(
      color: AppTheme.surface.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.link_off_rounded, color: AppTheme.textSecondary, size: 48),
            const SizedBox(height: 16),
            Text(
              'No Caregiver Connected',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Share your unique Patient ID with your caregiver. Once they link it, your profile status will update automatically.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      patient.userId,
                      style: GoogleFonts.outfit(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: AppTheme.primary, size: 20),
                    onPressed: () => _copyToClipboard(patient.userId),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaregiverLinkingUI(UserModel caregiver, AuthProvider authProvider, UserService userService) {
    if (caregiver.linkedPatientId != null) {
      // Stream user details of the patient
      return StreamBuilder<UserModel?>(
        stream: userService.watchUserProfile(caregiver.linkedPatientId!),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildStatusCard(
              icon: Icons.error_outline_rounded,
              color: AppTheme.error,
              title: 'Error loading patient info',
              subtitle: 'Patient ID: ${caregiver.linkedPatientId}',
            );
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return _buildStatusCard(
              icon: Icons.link_rounded,
              color: AppTheme.accent,
              title: 'Linked with Patient',
              subtitle: 'Patient ID: ${caregiver.linkedPatientId}',
            );
          }

          final patient = snapshot.data!;
          final patientName = patient.name;
          final patientContact = patient.contactDetails;

          return Card(
            color: AppTheme.surface.withOpacity(0.6),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.link_rounded, color: AppTheme.accent, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status: Connected',
                            style: GoogleFonts.outfit(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Connected to Patient',
                            style: GoogleFonts.outfit(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                  const Divider(height: 32, color: Colors.white10),
                  _buildInfoRow(Icons.person_outline_rounded, 'Patient Name', patientName),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.phone_outlined, 'Patient Contact', patientContact),
                ],
              ),
            ),
          );
        },
      );
    }

    return Form(
      key: _formKey,
      child: Card(
        color: AppTheme.surface.withOpacity(0.5),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.link_rounded, color: AppTheme.primary, size: 48),
              const SizedBox(height: 16),
              Text(
                'Connect to a Patient',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the Patient ID provided by the patient to link accounts. This establishes secure access.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),

              if (authProvider.errorMessage != null) ...[
                Text(
                  authProvider.errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: AppTheme.error, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
              ],

              TextFormField(
                controller: _patientIdController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Patient ID',
                  hintText: 'Enter unique patient ID',
                  prefixIcon: Icon(Icons.vpn_key_outlined, color: AppTheme.textSecondary),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a Patient ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: !authProvider.isLoading ? AppTheme.primaryGradient : null,
                  color: authProvider.isLoading ? AppTheme.surface.withOpacity(0.5) : null,
                ),
                child: ElevatedButton(
                  onPressed: authProvider.isLoading ? null : _linkPatient,
                  child: authProvider.isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Link Patient Account',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Card(
      color: AppTheme.surface.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
