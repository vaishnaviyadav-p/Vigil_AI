import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_ai_mobile/core/constants/app_constants.dart';
import 'package:vigil_ai_mobile/models/contact_model.dart';
import 'package:vigil_ai_mobile/providers/contact_provider.dart';

class ContactsView extends ConsumerStatefulWidget {
  const ContactsView({super.key});

  @override
  ConsumerState<ContactsView> createState() => _ContactsViewState();
}

class _ContactsViewState extends ConsumerState<ContactsView> {
  @override
  void initState() {
    super.initState();
    // Always refresh contacts dynamically from database for the authenticated user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contactProvider.notifier).fetchContacts();
    });
  }

  void _showAddContactDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String relationship = 'Friend';
    int priority = 1;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: AppColors.primaryLight, size: 22),
              SizedBox(width: 8),
              Text('Add Emergency Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      prefixIcon: Icon(Icons.person_outline),
                      hintText: 'e.g., Nayana or My Own Number',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number *',
                      prefixIcon: Icon(Icons.phone_outlined),
                      hintText: 'e.g., 9066397259 or +919066397259',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter a phone number';
                      final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                      if (digits.length < 10) return 'Enter a valid phone number (at least 10 digits)';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email (Optional)',
                      prefixIcon: Icon(Icons.email_outlined),
                      hintText: 'contact@example.com',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: relationship,
                    dropdownColor: AppColors.card,
                    decoration: const InputDecoration(labelText: 'Relationship'),
                    items: const [
                      DropdownMenuItem(value: 'Friend', child: Text('Friend')),
                      DropdownMenuItem(value: 'Parent', child: Text('Parent')),
                      DropdownMenuItem(value: 'Sibling', child: Text('Sibling')),
                      DropdownMenuItem(value: 'Spouse', child: Text('Spouse')),
                      DropdownMenuItem(value: 'Guardian', child: Text('Guardian')),
                      DropdownMenuItem(value: 'Self', child: Text('Self / My Own Number')),
                      DropdownMenuItem(value: 'Colleague', child: Text('Colleague')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => relationship = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: priority,
                    dropdownColor: AppColors.card,
                    decoration: const InputDecoration(labelText: 'Alert Priority'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Priority 1 (Dispatched First in SOS)')),
                      DropdownMenuItem(value: 2, child: Text('Priority 2 (Secondary Alert)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => priority = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);

                      final res = await ref.read(contactProvider.notifier).addContact(
                            name: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                            relationship: relationship,
                            priority: priority,
                          );

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res.message),
                            backgroundColor: res.success ? AppColors.safeGreen : AppColors.sosRed,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Contact'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditContactDialog(ContactModel contact) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: contact.name);
    final phoneCtrl = TextEditingController(text: contact.phone);
    final emailCtrl = TextEditingController(text: contact.email ?? '');
    String relationship = [
      'Friend',
      'Parent',
      'Sibling',
      'Spouse',
      'Guardian',
      'Self',
      'Colleague'
    ].contains(contact.relationship)
        ? contact.relationship
        : 'Friend';
    int priority = contact.priority;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.edit_outlined, color: AppColors.primaryLight, size: 22),
              SizedBox(width: 8),
              Text('Edit Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number *',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter a phone number';
                      final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                      if (digits.length < 10) return 'Enter a valid phone number (at least 10 digits)';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email (Optional)',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: relationship,
                    dropdownColor: AppColors.card,
                    decoration: const InputDecoration(labelText: 'Relationship'),
                    items: const [
                      DropdownMenuItem(value: 'Friend', child: Text('Friend')),
                      DropdownMenuItem(value: 'Parent', child: Text('Parent')),
                      DropdownMenuItem(value: 'Sibling', child: Text('Sibling')),
                      DropdownMenuItem(value: 'Spouse', child: Text('Spouse')),
                      DropdownMenuItem(value: 'Guardian', child: Text('Guardian')),
                      DropdownMenuItem(value: 'Self', child: Text('Self / My Own Number')),
                      DropdownMenuItem(value: 'Colleague', child: Text('Colleague')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => relationship = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: priority,
                    dropdownColor: AppColors.card,
                    decoration: const InputDecoration(labelText: 'Alert Priority'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Priority 1 (Dispatched First in SOS)')),
                      DropdownMenuItem(value: 2, child: Text('Priority 2 (Secondary Alert)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => priority = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);

                      final res = await ref.read(contactProvider.notifier).updateContact(
                            id: contact.id,
                            name: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                            relationship: relationship,
                            priority: priority,
                          );

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res.message),
                            backgroundColor: res.success ? AppColors.safeGreen : AppColors.sosRed,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteContact(ContactModel contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Emergency Contact?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to remove "${contact.name}" (${contact.phone}) from your emergency contacts list?\n\nThey will no longer receive live GPS tracking links when you trigger SOS.',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sosRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await ref.read(contactProvider.notifier).deleteContact(contact.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res.message),
                    backgroundColor: res.success ? AppColors.safeGreen : AppColors.sosRed,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmCleanDemoContacts() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Demo Contacts?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will remove all demo and placeholder contacts (such as Sunita, Rajesh, Pooja, or @example.com) from your account.\n\nYour custom contacts (like Nayana or your own number) will remain safe and unchanged.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cautionYellow,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await ref.read(contactProvider.notifier).cleanDemoContacts();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res.message),
                    backgroundColor: res.success ? AppColors.safeGreen : AppColors.sosRed,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text('Remove Demo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactState = ref.watch(contactProvider);

    // Detect if any demo contacts exist in the current list
    final hasDemoContacts = contactState.contacts.any((c) =>
        c.email?.contains('example.com') == true ||
        c.name.contains('(Mother)') ||
        c.name.contains('(Father)') ||
        c.name.contains('(Best Friend)') ||
        ['+919876543220', '+919876543221', '+919876543222'].contains(c.phone));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trusted Emergency Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Contacts',
            onPressed: () => ref.read(contactProvider.notifier).fetchContacts(),
          ),
          if (hasDemoContacts)
            IconButton(
              icon: const Icon(Icons.cleaning_services_rounded, color: AppColors.cautionYellow),
              tooltip: 'Purge Demo Contacts',
              onPressed: _confirmCleanDemoContacts,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryIndigo,
        onPressed: _showAddContactDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Contact', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(contactProvider.notifier).fetchContacts(),
        child: contactState.isLoading && contactState.contacts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // Information banner
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, color: AppColors.primaryLight, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Emergency contacts automatically receive your live location tracking link over cellular SMS and WhatsApp whenever SOS is triggered.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (contactState.errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.sosRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.sosRed.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.sosRed, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              contactState.errorMessage!,
                              style: const TextStyle(color: AppColors.sosRed, fontSize: 13),
                            ),
                          ),
                          TextButton(
                            onPressed: () => ref.read(contactProvider.notifier).fetchContacts(),
                            child: const Text('Retry', style: TextStyle(color: AppColors.sosRed, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                  if (contactState.contacts.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 40),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.people_alt_outlined, size: 40, color: AppColors.primaryLight),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No Emergency Contacts Yet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add your family, close friends, or your own secondary mobile number. When you activate SOS, your live GPS map link will be dispatched immediately.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryIndigo,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _showAddContactDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Emergency Contact', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    )
                  else
                    ...contactState.contacts.map((c) {
                      final isDemo = c.email?.contains('example.com') == true ||
                          ['+919876543220', '+919876543221', '+919876543222'].contains(c.phone);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDemo ? AppColors.cautionYellow.withValues(alpha: 0.5) : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: (c.priority == 1 ? AppColors.sosRed : AppColors.primaryLight)
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: c.priority == 1 ? AppColors.sosRed : AppColors.primaryLight,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          c.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: c.priority == 1
                                              ? AppColors.sosRed.withValues(alpha: 0.15)
                                              : AppColors.border,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          c.priority == 1 ? 'Primary (P1)' : 'Secondary (P2)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: c.priority == 1 ? AppColors.sosRed : AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        c.phone,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryLight,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '• ${c.relationship}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                  if (c.email != null && c.email!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      c.email!,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: AppColors.primaryLight, size: 20),
                              tooltip: 'Edit Contact',
                              onPressed: () => _showEditContactDialog(c),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
                              tooltip: 'Delete Contact',
                              onPressed: () => _confirmDeleteContact(c),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 60),
                ],
              ),
      ),
    );
  }
}
