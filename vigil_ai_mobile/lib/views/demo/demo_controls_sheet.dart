import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_ai_mobile/core/constants/app_constants.dart';
import 'package:vigil_ai_mobile/providers/demo_mode_provider.dart';

class DemoControlsSheet extends ConsumerWidget {
  const DemoControlsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.cautionYellow.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.science_outlined, color: AppColors.cautionYellow, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'College Major Project Demo Panel',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Simulate test inputs for examiners and viva defense',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _scenarioBtn(
                context: context,
                ref: ref,
                label: '1. Normal Walk',
                scenario: 'NORMAL',
                color: AppColors.safeGreen,
                icon: Icons.directions_walk,
              ),
              _scenarioBtn(
                context: context,
                ref: ref,
                label: '2. Sensor Anomaly',
                scenario: 'ABNORMAL_MOVEMENT',
                color: AppColors.cautionYellow,
                icon: Icons.show_chart,
              ),
              _scenarioBtn(
                context: context,
                ref: ref,
                label: '3. Fall Impact',
                scenario: 'FALL_DETECTED',
                color: AppColors.highRiskOrange,
                icon: Icons.airline_seat_recline_extra,
              ),
              _scenarioBtn(
                context: context,
                ref: ref,
                label: '4. High-Risk Zone',
                scenario: 'UNSAFE_ZONE',
                color: AppColors.sosRed,
                icon: Icons.warning_amber_rounded,
              ),
              _scenarioBtn(
                context: context,
                ref: ref,
                label: '5. Geofence Exit',
                scenario: 'GEOFENCE_BREACH',
                color: AppColors.primaryLight,
                icon: Icons.fmd_good_outlined,
              ),
              _scenarioBtn(
                context: context,
                ref: ref,
                label: '6. Voice "HELP"',
                scenario: 'VOICE_DISTRESS',
                color: AppColors.sosRed,
                icon: Icons.mic_none,
              ),
              _scenarioBtn(
                context: context,
                ref: ref,
                label: '7. SOS Countdown',
                scenario: 'SOS',
                color: AppColors.sosRed,
                icon: Icons.emergency,
              ),
              _scenarioBtn(
                context: context,
                ref: ref,
                label: '8. Critical Multi-Risk',
                scenario: 'HIGH_RISK_EVENT',
                color: AppColors.sosRed,
                icon: Icons.crisis_alert,
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Academic Note: All simulated events travel through the backend AI Risk Engine and Isolation Forest model, updating database records and analytics in real-time.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _scenarioBtn({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required String scenario,
    required Color color,
    required IconData icon,
  }) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 50) / 2,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: color.withOpacity(0.08),
          side: BorderSide(color: color.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          ref.read(demoModeProvider.notifier).triggerSimulation(scenario);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Simulated Scenario triggered: $label')),
          );
        },
        icon: Icon(icon, size: 18, color: color),
        label: Text(
          label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
