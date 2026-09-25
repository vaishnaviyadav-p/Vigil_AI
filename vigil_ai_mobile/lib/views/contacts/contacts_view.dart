import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_ai_mobile/core/constants/app_constants.dart';
import 'package:vigil_ai_mobile/providers/contact_provider.dart';

class ContactsView extends ConsumerWidget {
  const ContactsView({super.key});

  void _showAddContactDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String relationship = 'Parent';
    int priority = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Trusted Contact', style: TextStyle(fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email (Optional)', prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: relationship,
                  dropdownColor: AppColors.card,
                  decoration: const InputDecoration(labelText: 'Relationship'),
                  items: ['Parent', 'Sibling', 'Spouse', 'Friend', 'Guardian', 'Colleague']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => relationship = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: priority,
                  dropdownColor: AppColors.card,
                  decoration: const InputDecoration(labelText: 'Alert Priority'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Priority 1 (Primary)')),
                    DropdownMenuItem(value: 2, child: Text('Priority 2 (Secondary)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => priority = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
                await ref.read(contactProvider.notifier).addContact(
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                      relationship: relationship,
                      priority: priority,
                    );
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Contact'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactState = ref.watch(contactProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trusted Contacts'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryIndigo,
        onPressed: () => _showAddContactDialog(context, ref),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Contact', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: contactState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : contactState.contacts.isEmpty
              ? const Center(
                  child: Text('No emergency contacts added yet.', style: TextStyle(color: AppColors.textSecondary)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: contactState.contacts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final c = contactState.contacts[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryLight),
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
                                        c.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: c.priority == 1 ? AppColors.sosRed.withOpacity(0.15) : AppColors.border,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'P${c.priority}',
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
                                Text('${c.relationship} • ${c.phone}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                if (c.email != null && c.email!.isNotEmpty)
                                  Text(c.email!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
                            onPressed: () {
                              ref.read(contactProvider.notifier).deleteContact(c.id);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
