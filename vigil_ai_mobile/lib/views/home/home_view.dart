import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vigil_ai_mobile/core/constants/app_constants.dart';
import 'package:vigil_ai_mobile/providers/auth_provider.dart';
import 'package:vigil_ai_mobile/providers/contact_provider.dart';
import 'package:vigil_ai_mobile/providers/emergency_provider.dart';
import 'package:vigil_ai_mobile/providers/risk_provider.dart';
import 'package:vigil_ai_mobile/providers/sensor_provider.dart';
import 'package:vigil_ai_mobile/views/demo/demo_controls_sheet.dart';
import 'package:vigil_ai_mobile/views/emergency/sos_countdown_dialog.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final riskState = ref.watch(riskProvider);
    final sensorState = ref.watch(sensorProvider);
    final contactState = ref.watch(contactProvider);
    final emergencyState = ref.watch(emergencyProvider);

    final userName = authState.user?.fullName.split(' ').first ?? 'User';
    final safetyScore = riskState.scoreModel.safetyScore;
    final riskLevel = riskState.scoreModel.riskLevel;
    final riskColor = AppColors.getRiskColor(riskLevel);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello, $userName 👋', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text(
              'System Active & Guarding',
              style: TextStyle(fontSize: 11, color: AppColors.safeGreen, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.science_outlined, color: AppColors.cautionYellow),
            tooltip: 'College Demo Controls',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => const DemoControlsSheet(),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Active Emergency Warning Card if SOS is currently triggered
            if (emergencyState.isEmergencyActive) ...[
              GestureDetector(
                onTap: () => context.push('/emergency'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.sosRed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.sosRed, width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.sosRed, size: 32),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ACTIVE EMERGENCY DISPATCH',
                              style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.sosRed, fontSize: 14),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Live GPS is broadcasting. Tap to view status or resolve.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.sosRed),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Safety Score Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.card, AppColors.cardSecondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  // Circular Score Display
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: (safetyScore / 100.0).clamp(0.0, 1.0),
                          strokeWidth: 8,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${safetyScore.toInt()}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Text(
                            '/ 100',
                            style: TextStyle(fontSize: 9, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Risk Level: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: riskColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: riskColor, width: 1),
                              ),
                              child: Text(
                                riskLevel,
                                style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          riskState.scoreModel.factors.isNotEmpty
                              ? riskState.scoreModel.factors.first.factor
                              : 'Nominal baseline monitoring.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => context.go('/safety'),
                          child: const Text(
                            'View Full Analysis →',
                            style: TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Live Sensors & Status telemetry chips
            Row(
              children: [
                Expanded(
                  child: _telemetryChip(
                    icon: Icons.sensors,
                    title: 'Motion Sensor',
                    subtitle: '${sensorState.currentMagnitude.toStringAsFixed(1)} m/s²',
                    detail: sensorState.currentActivity,
                    color: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _telemetryChip(
                    icon: Icons.contact_phone_outlined,
                    title: 'Emergency Circle',
                    subtitle: '${contactState.contacts.length} Contacts',
                    detail: 'All Configured',
                    color: AppColors.safeGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick Actions Section
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _actionCard(
                  icon: Icons.emergency,
                  title: 'Instant SOS',
                  subtitle: '5s Countdown',
                  color: AppColors.sosRed,
                  onTap: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => const SosCountdownDialog(),
                    );
                  },
                ),
                _actionCard(
                  icon: Icons.alt_route_rounded,
                  title: 'Safe Routes',
                  subtitle: 'AI Path Risk',
                  color: AppColors.primaryLight,
                  onTap: () => context.push('/routes/safe'),
                ),
                _actionCard(
                  icon: Icons.people_alt_outlined,
                  title: 'Contacts',
                  subtitle: '${contactState.contacts.length} Trusted',
                  color: AppColors.safeGreen,
                  onTap: () => context.push('/contacts'),
                ),
                _actionCard(
                  icon: Icons.report_problem_outlined,
                  title: 'Report Incident',
                  subtitle: 'Community alert',
                  color: AppColors.cautionYellow,
                  onTap: () => context.push('/incidents/report'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Ethical AI Disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border.withOpacity(0.5)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppConstants.aiDisclaimer,
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _telemetryChip({
    required IconData icon,
    required String title,
    required String subtitle,
    required String detail,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(detail, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
