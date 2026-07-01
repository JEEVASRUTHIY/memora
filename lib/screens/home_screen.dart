import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/reminder_provider.dart';
import 'reminder_list_screen.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../providers/safe_zone_provider.dart';
import 'safe_zone_status_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _patientIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _initializedPatientId;

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
    final targetPatientId = user != null ? (user.isPatient ? user.userId : user.linkedPatientId) : null;

    if (targetPatientId != null && _initializedPatientId != targetPatientId) {
      _initializedPatientId = targetPatientId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<ReminderProvider>(context, listen: false).initialize(targetPatientId, isPatient: user!.isPatient);
        Provider.of<SafeZoneProvider>(context, listen: false).initialize(targetPatientId, isPatient: user.isPatient);
      });
    }

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
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Active Breach Banner
                        if (targetPatientId != null)
                          StreamBuilder<UserModel?>(
                            stream: userService.watchUserProfile(targetPatientId),
                            builder: (context, snapshot) {
                              final patientProfile = snapshot.data;
                              final isBreached = patientProfile != null && 
                                  (patientProfile.toJson()['isBreached'] == true);

                              if (!isBreached) return const SizedBox.shrink();

                              return Container(
                                key: const Key('breachAlertBanner'),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: AppTheme.error,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SafeZoneStatusScreen(patientId: targetPatientId),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'EMERGENCY: SAFE ZONE BREACH!',
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Text(
                                                  user.isPatient
                                                      ? 'You have left your home safe zone! Tap to view details.'
                                                      : '${patientProfile.name} has left their safe zone! Tap to view details.',
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.white.withOpacity(0.9),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
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
                      const SizedBox(height: 16),

                      // Safe Zone Breach Alert
                      if (targetPatientId != null)
                        Consumer<SafeZoneProvider>(
                          builder: (context, safeZoneProv, _) {
                            final isBreached = safeZoneProv.latestLocation?.breachFlag == true;
                            final active = safeZoneProv.currentSafeZone?.activeStatus == true;
                            if (!active || !isBreached) return const SizedBox.shrink();

                            return Container(
                              key: const Key('safeZoneBreachWarningCard'),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.error, width: 2.0),
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SafeZoneStatusScreen(patientId: targetPatientId),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.security_update_warning_rounded, color: AppTheme.error, size: 32),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'CRITICAL: SAFE ZONE BREACHED!',
                                              style: GoogleFonts.outfit(
                                                color: AppTheme.error,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              user.isPatient 
                                                  ? 'You have exited the designated safe zone. Please return immediately.' 
                                                  : 'The patient has exited the safe zone boundary. Tap to check coordinates on map.',
                                              style: GoogleFonts.outfit(
                                                color: AppTheme.textPrimary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.error, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                      // Active Trigger Alerts
                      if (user.isPatient)
                        Consumer<ReminderProvider>(
                          builder: (context, provider, _) {
                            final triggers = provider.pendingTriggers;
                            if (triggers.isEmpty) return const SizedBox.shrink();

                            return Column(
                              children: triggers.map((log) {
                                return Container(
                                  key: Key('trigger_${log.logId}'),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.error.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppTheme.error.withOpacity(0.3), width: 1.5),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, color: AppTheme.error),
                                          const SizedBox(width: 8),
                                          Text(
                                            'REMINDER TRIGGERED!',
                                            style: GoogleFonts.outfit(
                                              color: AppTheme.error,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        log.description,
                                        style: GoogleFonts.outfit(
                                          color: AppTheme.textPrimary,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (log.instructions != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          log.instructions!,
                                          style: GoogleFonts.outfit(
                                            color: AppTheme.textSecondary,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time_rounded, color: AppTheme.textSecondary, size: 16),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Scheduled: ${TimeOfDay.fromDateTime(log.scheduledTime).format(context)}',
                                            style: GoogleFonts.outfit(
                                              color: AppTheme.textSecondary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          if (log.snoozeEnabled) ...[
                                            TextButton(
                                              key: Key('snooze_${log.logId}'),
                                              onPressed: () => provider.snoozeTrigger(log.logId),
                                              child: Text(
                                                'Snooze',
                                                style: GoogleFonts.outfit(color: Colors.amber),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                          ],
                                          ElevatedButton(
                                            key: Key('confirm_${log.logId}'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.accent,
                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                            ),
                                            onPressed: () => provider.confirmTrigger(log.logId),
                                            child: Text(
                                              'Confirm',
                                              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      const SizedBox(height: 16),

                      // Adherence Dashboard Card (Caregiver Only)
                      if (user.isCaregiver && targetPatientId != null) ...[
                        Consumer<ReminderProvider>(
                          builder: (context, provider, _) {
                            final now = DateTime.now();
                            final todayLogs = provider.allLogs.where((l) {
                              return l.scheduledTime.year == now.year &&
                                     l.scheduledTime.month == now.month &&
                                     l.scheduledTime.day == now.day;
                            }).toList();
                            
                            final completedCount = todayLogs.where((l) => l.status.toLowerCase() == 'completed' || l.status.toLowerCase() == 'confirmed').length;
                            final missedCount = todayLogs.where((l) => l.status.toLowerCase() == 'missed').length;
                            final snoozedCount = todayLogs.where((l) => l.status.toLowerCase() == 'snoozed').length;
                            
                            final totalFinished = completedCount + missedCount;
                            final adherenceRate = totalFinished > 0 
                                ? (completedCount / totalFinished * 100).round() 
                                : 100;
                                
                            Color statusColor;
                            String statusText;
                            IconData statusIcon;
                            
                            if (adherenceRate >= 80) {
                              statusColor = AppTheme.accent;
                              statusText = 'Excellent Adherence';
                              statusIcon = Icons.check_circle_outline_rounded;
                            } else if (adherenceRate >= 50) {
                              statusColor = Colors.orangeAccent;
                              statusText = 'Needs Attention';
                              statusIcon = Icons.info_outline_rounded;
                            } else {
                              statusColor = AppTheme.error;
                              statusText = 'Critical Level!';
                              statusIcon = Icons.warning_amber_rounded;
                            }
                            
                            return Card(
                              key: const Key('adherenceDashboardCard'),
                              color: AppTheme.primary.withOpacity(0.05),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Adherence Dashboard',
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const Divider(height: 24, color: Colors.white10),
                                    Row(
                                      children: [
                                        // Left: Percentage ring
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            SizedBox(
                                              width: 70,
                                              height: 70,
                                              child: CircularProgressIndicator(
                                                value: adherenceRate / 100,
                                                strokeWidth: 8,
                                                backgroundColor: Colors.white10,
                                                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                                              ),
                                            ),
                                            Text(
                                              '$adherenceRate%',
                                              style: GoogleFonts.outfit(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 20),
                                        // Right: Detail stats
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(statusIcon, color: statusColor, size: 18),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    statusText,
                                                    style: GoogleFonts.outfit(
                                                      color: statusColor,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  _buildStatMetric('Total', todayLogs.length, Colors.blue),
                                                  _buildStatMetric('Completed', completedCount, AppTheme.accent),
                                                  _buildStatMetric('Missed', missedCount, AppTheme.error),
                                                  _buildStatMetric('Snoozed', snoozedCount, Colors.amber),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],

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
                      const SizedBox(height: 24),

                      // Reminders Card (if patient or linked caregiver has patientId)
                      if (targetPatientId != null) ...[
                        _buildRemindersCard(context, targetPatientId),
                        const SizedBox(height: 16),
                        _buildSafeZoneCard(context, targetPatientId),
                        const SizedBox(height: 24),
                      ],

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
                      user.isPatient
                          ? _buildPatientLinkingUI(user, userService)
                          : _buildCaregiverLinkingUI(user, authProvider, userService),
                    ],
                  ),
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

  Widget _buildSafeZoneCard(BuildContext context, String patientId) {
    return Card(
      color: AppTheme.secondary.withOpacity(0.08),
      child: InkWell(
        key: const Key('safeZoneModuleCard'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SafeZoneStatusScreen(patientId: patientId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.security_rounded, color: AppTheme.secondary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Safe Zone Module',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure geofence zones, monitor location in real-time, and check alerts logs.',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textSecondary, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemindersCard(BuildContext context, String patientId) {
    return Card(
      color: AppTheme.primary.withOpacity(0.08),
      child: InkWell(
        key: const Key('remindersModuleCard'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReminderListScreen(patientId: patientId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.alarm_on_rounded, color: AppTheme.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reminders Module',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage medications, schedules, and view logging history.',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textSecondary, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatMetric(String label, int count, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count.toString(),
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
