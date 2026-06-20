import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/reminder_model.dart';
import '../models/reminder_log_model.dart';
import '../providers/auth_provider.dart';
import '../providers/reminder_provider.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import 'reminder_form_screen.dart';

class ReminderListScreen extends StatefulWidget {
  final String patientId;

  const ReminderListScreen({super.key, required this.patientId});

  @override
  State<ReminderListScreen> createState() => _ReminderListScreenState();
}

class _ReminderListScreenState extends State<ReminderListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return AppTheme.error;
      case 'high':
        return Colors.orangeAccent;
      case 'medium':
        return Colors.amber;
      case 'low':
      default:
        return AppTheme.accent;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'completed':
        return AppTheme.accent;
      case 'missed':
        return AppTheme.error;
      case 'snoozed':
        return Colors.amber;
      case 'triggered':
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isCaregiver = authProvider.userModel?.isCaregiver ?? false;
    final service = Provider.of<ReminderService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reminders',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(text: 'Schedules', icon: Icon(Icons.alarm_on_rounded)),
            Tab(text: 'History Logs', icon: Icon(Icons.history_toggle_off_rounded)),
          ],
        ),
      ),
      floatingActionButton: isCaregiver
          ? FloatingActionButton(
              key: const Key('addReminderFAB'),
              backgroundColor: AppTheme.primary,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReminderFormScreen(patientId: widget.patientId),
                  ),
                );
              },
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Schedules Tab
              Consumer<ReminderProvider>(
                builder: (context, provider, _) {
                  final reminders = provider.allReminders;
                  
                  if (reminders.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.alarm_off_rounded, color: AppTheme.textSecondary.withOpacity(0.5), size: 64),
                          const SizedBox(height: 16),
                          Text(
                            'No reminders scheduled.',
                            style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: reminders.length,
                    itemBuilder: (context, index) {
                      final reminder = reminders[index];
                      final severityColor = _getSeverityColor(reminder.severityLevel);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Row: Type Badge + Severity Badge + Active Switch/Indicator
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      // Type Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          reminder.reminderType,
                                          style: GoogleFonts.outfit(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Severity Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: severityColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: severityColor.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          reminder.severityLevel,
                                          style: GoogleFonts.outfit(color: severityColor, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  // Active Switch (Caregiver only) or Status Dot
                                  isCaregiver
                                      ? SizedBox(
                                          height: 30,
                                          child: Switch(
                                            value: reminder.activeStatus,
                                            activeColor: AppTheme.accent,
                                            onChanged: (val) async {
                                              await service.updateReminder(reminder.copyWith(activeStatus: val));
                                              provider.initialize(widget.patientId); // Refresh timers
                                            },
                                          ),
                                        )
                                      : Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: reminder.activeStatus ? AppTheme.accent : AppTheme.textSecondary,
                                          ),
                                        ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Description
                              Text(
                                reminder.description,
                                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              ),
                              const SizedBox(height: 4),

                              // Instructions
                              if (reminder.instructions != null) ...[
                                Text(
                                  reminder.instructions!,
                                  style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 12),
                              ],

                              const Divider(color: Colors.white10),
                              const SizedBox(height: 8),

                              // Scheduled Time & Actions Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time_rounded, color: AppTheme.textSecondary, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Time: ${TimeOfDay.fromDateTime(reminder.scheduledTime).format(context)}',
                                        style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  
                                  if (isCaregiver)
                                    IconButton(
                                      icon: const Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 24),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ReminderFormScreen(
                                              patientId: widget.patientId,
                                              existingReminder: reminder,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              // History Logs Tab
              StreamBuilder<List<ReminderLogModel>>(
                stream: service.getReminderLogs(widget.patientId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.error)),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final logs = snapshot.data!;
                  
                  if (logs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_rounded, color: AppTheme.textSecondary.withOpacity(0.5), size: 64),
                          const SizedBox(height: 16),
                          Text(
                            'No reminder history yet.',
                            style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final statusColor = _getStatusColor(log.status);
                      
                      return Card(
                        color: AppTheme.surface.withOpacity(0.6),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Log info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      log.description,
                                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'Scheduled: ${TimeOfDay.fromDateTime(log.scheduledTime).format(context)}',
                                          style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary),
                                        ),
                                        const SizedBox(width: 8),
                                        if (log.status.toLowerCase() == 'completed' || log.status.toLowerCase() == 'confirmed') ...[
                                          Text(
                                            '• Completed: ${TimeOfDay.fromDateTime(log.completedAt ?? log.actionTime).format(context)}',
                                            style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary),
                                          ),
                                        ] else if (log.status.toLowerCase() != 'triggered') ...[
                                          Text(
                                            '• Action: ${TimeOfDay.fromDateTime(log.actionTime).format(context)}',
                                            style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: statusColor.withOpacity(0.4), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      log.status,
                                      style: GoogleFonts.outfit(
                                        color: statusColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    // Escalation star indicator on misses
                                    if (log.status.toLowerCase() == 'missed' && log.escalationNotified) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.star_rounded, color: AppTheme.error, size: 12),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
