import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vigil_ai_mobile/core/constants/app_constants.dart';
import 'package:vigil_ai_mobile/providers/auth_provider.dart';
import 'package:vigil_ai_mobile/providers/contact_provider.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final contactState = ref.watch(contactProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Safety Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // User Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryIndigo, AppColors.sosRed],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (user?.fullName.isNotEmpty == true) ? user!.fullName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user?.fullName ?? 'User Profile',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  if (user?.email != null && user!.email.isNotEmpty)
                    Text(
                      user.email,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  if (user?.phone != null && user!.phone.isNotEmpty)
                    Text(
                      user.phone,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Emergency Medical Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.medical_information_outlined, color: AppColors.sosRed, size: 20),
                      SizedBox(width: 8),
                      Text('Emergency Medical Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const Divider(color: AppColors.border, height: 20),
                  _infoRow('Blood Group', user?.profile?.bloodGroup ?? 'O+'),
                  _infoRow('Medical Notes', user?.profile?.medicalNotes ?? 'Asthma inhaler in bag / None reported'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Profile Options Menu
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _menuTile(
                    icon: Icons.contact_phone_outlined,
                    title: 'Trusted Emergency Contacts',
                    subtitle: '${contactState.contacts.length} Registered',
                    color: AppColors.safeGreen,
                    onTap: () => context.push('/contacts'),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _menuTile(
                    icon: Icons.alt_route_rounded,
                    title: 'AI Route Recommendations',
                    subtitle: 'Safer path navigation',
                    color: AppColors.primaryLight,
                    onTap: () => context.push('/routes/safe'),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _menuTile(
                    icon: Icons.report_problem_outlined,
                    title: 'Submit Incident Report',
                    subtitle: 'Report street hazards or harassment',
                    color: AppColors.cautionYellow,
                    onTap: () => context.push('/incidents/report'),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _menuTile(
                    icon: Icons.tune_outlined,
                    title: 'System Settings',
                    subtitle: 'Countdown, Shake, Voice Detection',
                    color: AppColors.textSecondary,
                    onTap: () => context.push('/settings'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.sosRed,
                side: const BorderSide(color: AppColors.border),
              ),
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign Out'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              softWrap: true,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),

    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}
