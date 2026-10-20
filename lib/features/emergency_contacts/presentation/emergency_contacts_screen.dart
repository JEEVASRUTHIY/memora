import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:memora/core/theme/app_theme.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/core/widgets/app_widgets.dart';
import 'package:memora/data/models/emergency_contact_model.dart';
import 'package:go_router/go_router.dart';
import 'package:memora/core/router/app_routes.dart';
import 'package:memora/features/voice_assistant/presentation/voice_assistant_modal.dart';
import 'package:memora/features/auth/data/auth_providers.dart';
import 'package:memora/features/emergency_contacts/data/contact_providers.dart';

class EmergencyContactsScreen extends ConsumerStatefulWidget {
  /// Optional explicit patientId. If not provided, will be resolved
  /// from the authenticated session (patient's own ID or caregiver's linked patient).
  final String? explicitPatientId;

  const EmergencyContactsScreen({super.key, this.explicitPatientId});

  @override
  ConsumerState<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState
    extends ConsumerState<EmergencyContactsScreen> {
  Future<void> _makeCall(BuildContext context, String phoneNumber) async {
    final clean = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid phone number.')),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: clean);
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dialer opened for $phoneNumber ($clean)'),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Calling $phoneNumber: $clean'),
          ),
        );
      }
    }
  }

  void _showAddEditDialog({
    required BuildContext context,
    required String patientId,
    EmergencyContactModel? existingContact,
  }) {
    final cleanPatientId = patientId.trim();
    if (cleanPatientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot add contact: No active patient link.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ContactFormDialog(
        patientId: cleanPatientId,
        existingContact: existingContact,
      ),
    );
  }

  Future<void> _confirmDelete({
    required BuildContext context,
    required String patientId,
    required EmergencyContactModel contact,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Contact',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to remove ${contact.name} from emergency contacts?',
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: AppColors.white,
              minimumSize: const Size(72, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await ref
            .read(contactRepositoryProvider)
            .deleteContact(patientId, contact.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${contact.name} removed.'),
              backgroundColor: AppTheme.surface,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete contact: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final caregiverLinksAsync = ref.watch(caregiverLinksProvider);
    final currentUser = currentUserAsync.valueOrNull;
    final resolvedPatientId = widget.explicitPatientId ??
        ref.watch(activePatientIdProvider) ??
        (currentUser?.isPatient == true && (currentUser?.uid.isNotEmpty ?? false)
            ? currentUser!.uid
            : null);

    // If auth state or caregiver links are still loading, show loading screen
    if (currentUserAsync.isLoading ||
        (currentUser?.isCaregiver == true && caregiverLinksAsync.isLoading)) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Emergency Contacts',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(
          child: LoadingView(message: 'Loading emergency contacts…'),
        ),
      );
    }

    // If caregiver has no active link
    if (currentUser?.isCaregiver == true &&
        (resolvedPatientId == null || resolvedPatientId.isEmpty)) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Emergency Contacts',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(
          child: EmptyState(
            icon: Icons.person_off_rounded,
            title: 'No Linked Patient',
            subtitle:
                'You must be linked to an active patient to manage their emergency contacts.',
          ),
        ),
      );
    }

    if (resolvedPatientId == null || resolvedPatientId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Emergency Contacts',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(
          child: EmptyState(
            icon: Icons.person_off_rounded,
            title: 'No Patient Profile Found',
            subtitle:
                'Could not load patient profile for emergency contacts. Please verify your connection or sign in again.',
          ),
        ),
      );
    }

    final contactsAsync =
        ref.watch(patientContactsProvider(resolvedPatientId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Emergency Contacts',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: contactsAsync.when(
            loading: () => const Center(
              child: LoadingView(message: 'Loading emergency contacts…'),
            ),
            error: (err, _) {
              final devCode = err is FirebaseException ? err.code : 'unknown';
              debugPrint('[EmergencyContactsScreen] Error loading contacts (patientId: $resolvedPatientId): code=$devCode');

              final devHint = kDebugMode
                  ? '\n\n[Dev Debug: $devCode${err is FirebaseException && err.message != null ? ' - ${err.message}' : ''}]'
                  : '';

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ErrorView(
                    message:
                        'Could not load emergency contacts.\nPlease verify connection and permissions.$devHint',
                    onRetry: () => ref.invalidate(
                        patientContactsProvider(resolvedPatientId)),
                  ),
                ),
              );
            },
            data: (contacts) {
              return CustomScrollView(
                slivers: [
                  // Top summary banner
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.primary.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.shield_rounded,
                                    color: AppTheme.primary,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Quick Call & Voice Ready',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Say "Call [Name]" to your assistant or tap any contact card to reach help instantly.',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12.5,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Add Contact Action Button
                          ElevatedButton.icon(
                            key: const ValueKey('add_emergency_contact_button'),
                            onPressed: () => _showAddEditDialog(
                              context: context,
                              patientId: resolvedPatientId,
                            ),
                            icon: const Icon(Icons.add_rounded, size: 22),
                            label: Text(
                              'Add Emergency Contact',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: AppColors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Contact list or empty state
                  if (contacts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: EmptyState(
                            icon: Icons.contact_phone_outlined,
                            title: 'No Emergency Contacts',
                            subtitle:
                                'Add family members, caregivers, or doctors so you can reach them in one touch or via voice.',
                            action: ElevatedButton.icon(
                              key: const ValueKey('add_emergency_contact_button_empty'),
                              onPressed: () => _showAddEditDialog(
                                context: context,
                                patientId: resolvedPatientId,
                              ),
                              icon: const Icon(Icons.add_rounded, size: 20),
                              label: Text(
                                'Add Emergency Contact',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: AppColors.white,
                                minimumSize: const Size(160, 44),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 22, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final contact = contacts[index];
                            return _ElderlyContactCard(
                              contact: contact,
                              onCall: () => _makeCall(context, contact.phoneNumber),
                              onEdit: () => _showAddEditDialog(
                                context: context,
                                patientId: resolvedPatientId,
                                existingContact: contact,
                              ),
                              onDelete: () => _confirmDelete(
                                context: context,
                                patientId: resolvedPatientId,
                                contact: contact,
                              ),
                            );
                          },
                          childCount: contacts.length,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
      floatingActionButton: currentUser?.isPatient == true
          ? Container(
              height: 64,
              width: 64,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.4),
                    blurRadius: 14,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton(
                key: const ValueKey('patient_mic_record_contacts_fab'),
                elevation: 0,
                backgroundColor: Colors.transparent,
                tooltip: 'Tap to speak',
                onPressed: () => VoiceAssistantModal.show(
                  context: context,
                  onOpenContacts: () {},
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  size: 32,
                  color: AppColors.white,
                ),
              ),
            )
          : null,
      bottomNavigationBar: currentUser?.isPatient == true
          ? BottomAppBar(
              shape: const CircularNotchedRectangle(),
              notchMargin: 8,
              color: AppTheme.surface,
              elevation: 8,
              child: SizedBox(
                height: 56,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: InkWell(
                        key: const ValueKey('patient_nav_home_from_contacts'),
                        onTap: () => context.go(AppRoutes.patientHome),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.home_rounded,
                                  color: AppTheme.textSecondary, size: 24),
                              const SizedBox(height: 2),
                              Text(
                                'Home',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Spacer for center docked mic
                    Expanded(
                      child: InkWell(
                        key: const ValueKey('patient_nav_contacts_active'),
                        onTap: () {},
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.contact_phone_rounded,
                                  color: AppTheme.primary, size: 24),
                              const SizedBox(height: 2),
                              Text(
                                'Emergency Contacts',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

// ── Contact Card (Clear, high-contrast, elderly friendly) ────────────────────

class _ElderlyContactCard extends StatelessWidget {
  final EmergencyContactModel contact;
  final VoidCallback onCall;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ElderlyContactCard({
    required this.contact,
    required this.onCall,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: contact.isPrimary
              ? AppTheme.primary.withOpacity(0.6)
              : AppColors.white.withOpacity(0.08),
          width: contact.isPrimary ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: contact.isPrimary
                ? AppTheme.primary.withOpacity(0.12)
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Name + Relationship + Primary Badge
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: contact.isPrimary
                      ? AppTheme.primary
                      : AppTheme.primary.withOpacity(0.15),
                  child: Text(
                    contact.name.isNotEmpty
                        ? contact.name[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: contact.isPrimary
                          ? AppColors.white
                          : AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              contact.name,
                              style: GoogleFonts.outfit(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (contact.isPrimary)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppTheme.primary.withOpacity(0.4)),
                              ),
                              child: Text(
                                'PRIMARY',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVar,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          contact.relationship,
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurfaceMid,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Middle: Large legible phone number
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVar.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.phone_rounded,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    contact.phoneNumber,
                    style: GoogleFonts.outfit(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Bottom Actions: Large Call Button + Edit/Delete
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.call_rounded, size: 20),
                    label: Text(
                      'Call Now',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981), // Emerald green
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  tooltip: 'Edit Contact',
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.surfaceVar,
                    foregroundColor: AppTheme.textPrimary,
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  tooltip: 'Delete Contact',
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.error.withOpacity(0.12),
                    foregroundColor: AppTheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Contact Add / Edit Form Dialog ──────────────────────────────────────────

class _ContactFormDialog extends ConsumerStatefulWidget {
  final String patientId;
  final EmergencyContactModel? existingContact;

  const _ContactFormDialog({
    required this.patientId,
    this.existingContact,
  });

  @override
  ConsumerState<_ContactFormDialog> createState() => _ContactFormDialogState();
}

class _ContactFormDialogState extends ConsumerState<_ContactFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _relationCtrl;
  late bool _isPrimary;
  bool _saving = false;

  final _commonRelationships = const [
    'Daughter',
    'Son',
    'Spouse',
    'Doctor',
    'Caregiver',
    'Neighbor',
    'Friend',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existingContact?.name ?? '');
    _phoneCtrl =
        TextEditingController(text: widget.existingContact?.phoneNumber ?? '');
    _relationCtrl =
        TextEditingController(text: widget.existingContact?.relationship ?? 'Daughter');
    _isPrimary = widget.existingContact?.isPrimary ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _relationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(contactRepositoryProvider);
      if (widget.existingContact == null) {
        // Create
        final newContact = EmergencyContactModel(
          id: '',
          patientId: widget.patientId.trim(),
          name: _nameCtrl.text.trim(),
          phoneNumber: _phoneCtrl.text.trim(),
          relationship: _relationCtrl.text.trim(),
          isPrimary: _isPrimary,
          createdAt: DateTime.now(),
        );
        await repo.createContact(newContact);
      } else {
        // Update
        final updated = widget.existingContact!.copyWith(
          name: _nameCtrl.text.trim(),
          phoneNumber: _phoneCtrl.text.trim(),
          relationship: _relationCtrl.text.trim(),
          isPrimary: _isPrimary,
          updatedAt: DateTime.now(),
        );
        await repo.updateContact(updated);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingContact == null
                ? 'Contact added successfully.'
                : 'Contact updated.'),
            backgroundColor: AppTheme.surface,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ContactFormDialog] Error saving contact: $e');
      if (mounted) {
        setState(() => _saving = false);
        final errorMsg = e is FirebaseException
            ? 'Firebase Error (${e.code}): ${e.message ?? 'Unknown'}'
            : e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save contact: $errorMsg'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingContact != null;

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final dialogWidth = (screenWidth - 32).clamp(280.0, 440.0);

    return Dialog(
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.85,
          ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title (Pinned)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEdit ? 'Edit Contact' : 'Add Emergency Contact',
                        style: GoogleFonts.outfit(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Scrollable Form Fields
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Name field
                        TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Full Name *',
                            hintText: 'e.g. Dr. Ravi Kumar or Sarah Jenkins',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter a contact name';
                            }
                            if (v.trim().length < 2) {
                              return 'Name is too short';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Phone field
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Phone Number *',
                            hintText: 'e.g. +1 555-0199 or 9876543210',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter a phone number';
                            }
                            final digitsOnly = v.replaceAll(RegExp(r'\D'), '');
                            if (digitsOnly.length < 7) {
                              return 'Please enter a valid phone number (at least 7 digits)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Relationship selector chips
                        Text(
                          'Relationship',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _commonRelationships.map((rel) {
                            final isSelected = _relationCtrl.text == rel;
                            return ChoiceChip(
                              label: Text(rel),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _relationCtrl.text = rel);
                                }
                              },
                              labelStyle: GoogleFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                              ),
                              selectedColor: AppTheme.primary.withOpacity(0.18),
                              backgroundColor: AppTheme.surfaceVar,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // Primary Contact Switch
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _isPrimary,
                          onChanged: (val) => setState(() => _isPrimary = val),
                          title: Text(
                            'Primary Emergency Contact',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'Prioritized for "Call my emergency contact" command.',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          activeColor: AppTheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Action buttons (Pinned at bottom)
                dialogWidth < 360
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              key: const ValueKey('save_emergency_contact_action_btn'),
                              onPressed: _saving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: AppColors.white,
                                minimumSize: const Size(0, 48),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.white,
                                      ),
                                    )
                                  : Text(
                                      isEdit ? 'Save Changes' : 'Add Contact',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.5,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: _saving ? null : () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 44),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.outfit(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _saving ? null : () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.outfit(
                                color: AppTheme.textSecondary,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            key: const ValueKey('save_emergency_contact_action_btn'),
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: AppColors.white,
                              minimumSize: const Size(88, 44),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.white,
                                    ),
                                  )
                                : Text(
                                    isEdit ? 'Save Changes' : 'Add Contact',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                    ),
                                  ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
