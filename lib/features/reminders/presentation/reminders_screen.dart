import 'package:go_router/go_router.dart';
import 'package:memora/core/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memora/core/theme/app_theme.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/data/models/reminder_models.dart';
import 'package:memora/features/reminders/data/reminder_providers.dart';

/// Primary caregiver screen to create/edit/delete reminders for a patient.
/// Secondary caregivers see read-only view.
class RemindersScreen extends ConsumerWidget {
  final String patientId;
  final bool isPrimary;

  const RemindersScreen({
    super.key,
    required this.patientId,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remAsync = ref.watch(remindersProvider(patientId));

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go(AppRoutes.caregiverHome),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Reminders',
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          )),
                    ),
                    if (isPrimary)
                      IconButton(
                        onPressed: () =>
                            _showReminderDialog(context, ref, null),
                        icon: const Icon(Icons.add_circle_rounded,
                            color: AppTheme.primary, size: 28),
                        tooltip: 'Add reminder',
                      ),
                  ],
                ),
              ),
              Expanded(
                child: remAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                      child: Text('Error: $e',
                          style: GoogleFonts.outfit(
                              color: AppTheme.error))),
                  data: (reminders) {
                    if (reminders.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.alarm_off_rounded,
                                color: AppTheme.textSecondary, size: 48),
                            const SizedBox(height: 16),
                            Text('No active reminders',
                                style: GoogleFonts.outfit(
                                    color: AppTheme.textSecondary,
                                    fontSize: 16)),
                            if (isPrimary) ...[
                              const SizedBox(height: 8),
                              Text('Tap + to create one',
                                  style: GoogleFonts.outfit(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13)),
                            ],
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: reminders.length,
                      itemBuilder: (_, i) => _ReminderTile(
                        reminder: reminders[i],
                        isPrimary: isPrimary,
                        patientId: patientId,
                        onEdit: () =>
                            _showReminderDialog(context, ref, reminders[i]),
                      ),
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

  Future<void> _showReminderDialog(
      BuildContext context, WidgetRef ref, ReminderModel? existing) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => _ReminderFormSheet(
        patientId: patientId,
        existing: existing,
        ref: ref,
      ),
    );
  }
}

// ── Reminder Tile ──────────────────────────────────────────────────────────

class _ReminderTile extends ConsumerWidget {
  final ReminderModel reminder;
  final bool isPrimary;
  final String patientId;
  final VoidCallback onEdit;

  const _ReminderTile({
    required this.reminder,
    required this.isPrimary,
    required this.patientId,
    required this.onEdit,
  });

  Color _impColor(String imp) {
    switch (imp) {
      case 'high':
        return AppColors.emergency;
      case 'low':
        return AppColors.success;
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: _impColor(reminder.importance).withOpacity(0.25),
            width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _impColor(reminder.importance).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.alarm_rounded,
                color: _impColor(reminder.importance), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reminder.title,
                    style: GoogleFonts.outfit(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${reminder.recurrence}'
                  '${reminder.times.isNotEmpty ? ' · ${reminder.times.join(", ")}' : ''}'
                  ' · ${reminder.importance}',
                  style: GoogleFonts.outfit(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isPrimary) ...[
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined,
                  color: AppTheme.textSecondary, size: 20),
            ),
            IconButton(
              onPressed: () => _confirmDelete(context, ref),
              icon:
                  const Icon(Icons.delete_outline, color: AppColors.emergency, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Delete Reminder',
            style: GoogleFonts.outfit(color: AppTheme.textPrimary)),
        content: Text('Delete "${reminder.title}"? This cannot be undone.',
            style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.outfit(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(reminderManagementProvider(patientId).notifier)
          .delete(reminder.reminderId);
    }
  }
}

// ── Reminder Form Sheet ────────────────────────────────────────────────────

class _ReminderFormSheet extends ConsumerStatefulWidget {
  final String patientId;
  final ReminderModel? existing;
  final WidgetRef ref;

  const _ReminderFormSheet({
    required this.patientId,
    required this.existing,
    required this.ref,
  });

  @override
  ConsumerState<_ReminderFormSheet> createState() => _ReminderFormSheetState();
}

class _ReminderFormSheetState extends ConsumerState<_ReminderFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _timesCtrl;
  String _recurrence = 'daily';
  String _importance = 'medium';
  int _maxRepeats = 3;
  int _repeatEveryMinutes = 15;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _timesCtrl =
        TextEditingController(text: e?.times.join(', ') ?? '08:00');
    _recurrence = e?.recurrence ?? 'daily';
    _importance = e?.importance ?? 'medium';
    _maxRepeats = e?.maxRepeats ?? 3;
    _repeatEveryMinutes = e?.repeatEveryMinutes ?? 15;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _timesCtrl.dispose();
    super.dispose();
  }

  List<String> get _parsedTimes => _timesCtrl.text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final isEdit = widget.existing != null;
    final reminder = ReminderModel(
      reminderId:
          widget.existing?.reminderId ?? ref.read(reminderRepositoryProvider).newReminderId(widget.patientId),
      patientId: widget.patientId,
      title: _titleCtrl.text.trim(),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      recurrence: _recurrence,
      times: _parsedTimes,
      importance: _importance,
      maxRepeats: _maxRepeats,
      repeatEveryMinutes: _repeatEveryMinutes,
      active: true,
      createdBy: widget.existing?.createdBy ?? '',
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    bool ok;
    if (isEdit) {
      ok = await ref
          .read(reminderManagementProvider(widget.patientId).notifier)
          .update(reminder);
    } else {
      ok = await ref
          .read(reminderManagementProvider(widget.patientId).notifier)
          .create(reminder);
    }

    setState(() => _saving = false);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.text,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(isEdit ? 'Edit Reminder' : 'New Reminder',
                  style: GoogleFonts.outfit(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              // Title
              _field(
                controller: _titleCtrl,
                label: 'Title',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title required' : null,
              ),
              const SizedBox(height: 16),
              // Note
              _field(
                  controller: _noteCtrl, label: 'Note (optional)', maxLines: 2),
              const SizedBox(height: 16),
              // Recurrence
              _dropdown<String>(
                label: 'Recurrence',
                value: _recurrence,
                items: const ['once', 'daily', 'weekly'],
                onChanged: (v) => setState(() => _recurrence = v!),
              ),
              const SizedBox(height: 16),
              // Times
              _field(
                controller: _timesCtrl,
                label: 'Times (HH:mm, comma-separated)',
                hint: '08:00, 13:00, 20:00',
              ),
              const SizedBox(height: 16),
              // Importance
              _dropdown<String>(
                label: 'Importance',
                value: _importance,
                items: const ['low', 'medium', 'high'],
                onChanged: (v) => setState(() => _importance = v!),
              ),
              const SizedBox(height: 16),
              // Max repeats
              _dropdown<int>(
                label: 'Max repeats before missed',
                value: _maxRepeats,
                items: const [1, 2, 3, 5, 8],
                onChanged: (v) => setState(() => _maxRepeats = v!),
              ),
              const SizedBox(height: 16),
              // Repeat interval
              _dropdown<int>(
                label: 'Repeat every (minutes)',
                value: _repeatEveryMinutes,
                items: const [5, 10, 15, 20, 30],
                onChanged: (v) => setState(() => _repeatEveryMinutes = v!),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: AppColors.white, strokeWidth: 2))
                      : Text(isEdit ? 'Save Changes' : 'Create Reminder',
                          style: GoogleFonts.outfit(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: GoogleFonts.outfit(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.outfit(color: AppTheme.textSecondary),
        hintStyle:
            GoogleFonts.outfit(color: AppTheme.textSecondary.withOpacity(0.5)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppColors.white.withOpacity(0.15), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.white.withOpacity(0.05),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(color: AppTheme.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppColors.white.withOpacity(0.15), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.white.withOpacity(0.05),
      ),
      dropdownColor: AppColors.text,
      style: GoogleFonts.outfit(color: AppTheme.textPrimary),
      items: items
          .map((i) => DropdownMenuItem<T>(
              value: i,
              child: Text(i.toString(),
                  style: GoogleFonts.outfit(color: AppTheme.textPrimary))))
          .toList(),
      onChanged: onChanged,
    );
  }
}
