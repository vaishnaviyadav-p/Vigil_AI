import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vigil_ai_mobile/core/constants/app_constants.dart';
import 'package:vigil_ai_mobile/providers/emergency_provider.dart';

class ActiveEmergencyView extends ConsumerWidget {
  const ActiveEmergencyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emergencyState = ref.watch(emergencyProvider);
    final emergency = emergencyState.activeEmergency;

    return PopScope(
      canPop: false, // Prevent accidental back button press during emergency
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('EMERGENCY ACTIVE', style: TextStyle(color: AppColors.sosRed, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.surface,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Flashing emergency banner
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.sosRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.sosRed, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.warning_rounded, color: AppColors.sosRed, size: 52),
                      const SizedBox(height: 12),
                      const Text(
                        'DISPATCH SIGNAL ACTIVE',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.sosRed,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        emergencyState.isOfflineQueued
                            ? 'OFFLINE MODE: Alert queued locally. Will dispatch once internet is restored.'
                            : 'Alert broadcasted to Central Monitoring and Trusted Contacts.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: emergencyState.isOfflineQueued ? AppColors.cautionYellow : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Live Location Sharing Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.safeGreen.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.share_location, color: AppColors.safeGreen, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Location sharing is ACTIVE',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Broadcasting GPS coordinates every 5s',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: emergencyState.isLiveLocationSharing,
                        activeColor: AppColors.safeGreen,
                        onChanged: (val) {
                          ref.read(emergencyProvider.notifier).setLiveSharing(val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Telemetry Details Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Incident Telemetry',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const Divider(color: AppColors.border, height: 20),
                      _detailRow('Alert Type', emergency?.alertType ?? 'SOS_MANUAL'),
                      _detailRow('Severity', emergency?.severity ?? 'CRITICAL'),
                      _detailRow(
                        'GPS Coordinates',
                        '${emergency?.latitude.toStringAsFixed(4) ?? "12.9716"}, ${emergency?.longitude.toStringAsFixed(4) ?? "77.5946"}',
                      ),
                      _detailRow('AI Risk Score', '${emergency?.riskScore.toStringAsFixed(1) ?? "82.0"} / 100'),
                      _detailRow('Status', emergency?.status ?? 'ACTIVE'),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Action Buttons
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.safeGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    await ref.read(emergencyProvider.notifier).resolveEmergency();
                    if (context.mounted) {
                      context.go('/home');
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("I'M SAFE – RESOLVE EMERGENCY", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),

                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await ref.read(emergencyProvider.notifier).cancelEmergency();
                    if (context.mounted) {
                      context.go('/home');
                    }
                  },
                  icon: const Icon(Icons.cancel_outlined, color: AppColors.textMuted),
                  label: const Text('CANCEL ALERT (False Alarm)', style: TextStyle(color: AppColors.textMuted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }
}
