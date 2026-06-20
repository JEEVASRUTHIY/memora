import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/reminder_model.dart';
import '../providers/reminder_provider.dart';
import '../theme/app_theme.dart';
import '../services/reminder_service.dart';

class ReminderFormScreen extends StatefulWidget {
  final String patientId;
  final ReminderModel? existingReminder;

  const ReminderFormScreen({
    super.key,
    required this.patientId,
    this.existingReminder,
  });

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _descriptionController;
  late TextEditingController _instructionsController;
  
  String _reminderType = 'Medication';
  String _severityLevel = 'Low';
  DateTime _scheduledTime = DateTime.now().add(const Duration(minutes: 5));
  int _escalationDuration = 15;
  bool _activeStatus = true;
  bool _isLoading = false;

  final List<String> _types = ['Medication', 'Routine', 'Appointment'];
  final List<String> _severities = ['Low', 'Medium', 'High', 'Critical'];

  @override
  void initState() {
    super.initState();
    final r = widget.existingReminder;
    _descriptionController = TextEditingController(text: r?.description ?? '');
    _instructionsController = TextEditingController(text: r?.instructions ?? '');
    if (r != null) {
      _reminderType = r.reminderType;
      _severityLevel = r.severityLevel;
      _scheduledTime = r.scheduledTime;
      _escalationDuration = r.escalationWaitingDuration;
      _activeStatus = r.activeStatus;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledTime),
    );
    if (picked != null) {
      final now = DateTime.now();
      setState(() {
        _scheduledTime = DateTime(
          _scheduledTime.year,
          _scheduledTime.month,
          _scheduledTime.day,
          picked.hour,
          picked.minute,
        );
        // If scheduled time is in the past for today, schedule it for tomorrow
        if (_scheduledTime.isBefore(now)) {
          _scheduledTime = _scheduledTime.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _scheduledTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _scheduledTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _scheduledTime.hour,
          _scheduledTime.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final service = Provider.of<ReminderService>(context, listen: false);

    final reminder = ReminderModel(
      reminderId: widget.existingReminder?.reminderId ?? '',
      patientId: widget.patientId,
      description: _descriptionController.text.trim(),
      instructions: _instructionsController.text.trim().isEmpty 
          ? null 
          : _instructionsController.text.trim(),
      reminderType: _reminderType,
      scheduledTime: _scheduledTime,
      severityLevel: _severityLevel,
      escalationWaitingDuration: _escalationDuration,
      activeStatus: _activeStatus,
    );

    try {
      if (widget.existingReminder != null) {
        await service.updateReminder(reminder);
      } else {
        await service.createReminder(reminder);
      }

      // Re-initialize reminder provider to ensure timers pick up changes
      if (mounted) {
        Provider.of<ReminderProvider>(context, listen: false).initialize(widget.patientId);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save reminder: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingReminder != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Reminder' : 'Add Reminder',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Description Input
                      TextFormField(
                        key: const Key('descriptionField'),
                        controller: _descriptionController,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'e.g., Take Blood Pressure Tablet',
                          prefixIcon: Icon(Icons.description_outlined, color: AppTheme.textSecondary),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Instructions Input
                      TextFormField(
                        key: const Key('instructionsField'),
                        controller: _instructionsController,
                        maxLines: 2,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Instructions (Optional)',
                          hintText: 'e.g., Take 1 tablet after breakfast.',
                          prefixIcon: Icon(Icons.info_outline_rounded, color: AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Dropdowns Row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: const Key('typeDropdown'),
                              value: _reminderType,
                              decoration: const InputDecoration(labelText: 'Type'),
                              items: _types.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _reminderType = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: const Key('severityDropdown'),
                              value: _severityLevel,
                              decoration: const InputDecoration(labelText: 'Severity'),
                              items: _severities.map((sev) {
                                return DropdownMenuItem(
                                  value: sev,
                                  child: Text(sev),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _severityLevel = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Date & Time Picker Row
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_month_outlined, color: AppTheme.primary),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Date', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary)),
                                          Text(
                                            '${_scheduledTime.day}/${_scheduledTime.month}/${_scheduledTime.year}',
                                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectTime(context),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded, color: AppTheme.primary),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Time', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary)),
                                          Text(
                                            TimeOfDay.fromDateTime(_scheduledTime).format(context),
                                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Escalation Wait Duration Slider
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Escalation Waiting Duration',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary),
                              ),
                              Text(
                                '$_escalationDuration mins',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Slider(
                            key: const Key('escalationSlider'),
                            value: _escalationDuration.toDouble(),
                            min: 1,
                            max: 120,
                            divisions: 120,
                            activeColor: AppTheme.primary,
                            inactiveColor: AppTheme.surface,
                            onChanged: (val) {
                              setState(() => _escalationDuration = val.round());
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Active Status Switch
                      SwitchListTile(
                        key: const Key('activeStatusSwitch'),
                        title: Text(
                          'Active Status',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          _activeStatus ? 'Reminder triggers at scheduled time.' : 'Reminder is currently disabled.',
                          style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        value: _activeStatus,
                        activeColor: AppTheme.accent,
                        onChanged: (val) => setState(() => _activeStatus = val),
                      ),
                      const SizedBox(height: 40),

                      // Submit Button
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: !_isLoading ? AppTheme.primaryGradient : null,
                          color: _isLoading ? AppTheme.surface.withOpacity(0.5) : null,
                        ),
                        child: ElevatedButton(
                          key: const Key('saveReminderButton'),
                          onPressed: _isLoading ? null : _save,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  isEditing ? 'Update Reminder' : 'Create Reminder',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }
}
