import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_ai_mobile/core/constants/app_constants.dart';
import 'package:vigil_ai_mobile/core/network/api_client.dart';
import 'package:vigil_ai_mobile/core/storage/storage_service.dart';
import 'package:vigil_ai_mobile/providers/auth_provider.dart';
import 'package:vigil_ai_mobile/providers/demo_mode_provider.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  final StorageService _storage = StorageService();
  late TextEditingController _urlCtrl;
  int _countdown = 5;
  bool _shakeToSos = true;
  bool _voiceDistress = true;
  bool _fallDetection = true;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: _storage.getBaseUrl());

    final user = ref.read(authProvider).user;
    if (user?.profile != null) {
      _countdown = user!.profile!.emergencyCountdown;
      _shakeToSos = user.profile!.shakeToSos;
      _voiceDistress = user.profile!.voiceDistressDetection;
      _fallDetection = user.profile!.fallDetection;
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final cleanUrl = StorageService.normalizeUrl(_urlCtrl.text.trim());
    await _storage.saveBaseUrl(cleanUrl);
    ApiClient().updateBaseUrl(cleanUrl);
    await ref.read(authProvider.notifier).updateSettings(
          emergencyCountdown: _countdown,
          shakeToSos: _shakeToSos,
          voiceDistressDetection: _voiceDistress,
          fallDetection: _fallDetection,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Settings saved. URL: $cleanUrl')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final demoState = ref.watch(demoModeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('System Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save Settings',
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Backend Connectivity Section
            const Text(
              'Backend Connectivity',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 8),
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
                  TextField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'API Base URL',
                      prefixIcon: Icon(Icons.dns_outlined),
                      helperText: 'Android Emulator: http://10.0.2.2:5000/api',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Emergency Trigger Controls
            const Text(
              'Emergency Triggers & Thresholds',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SOS Countdown Timer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Grace period before alert broadcast', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryIndigo.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_countdown s',
                          style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _countdown.toDouble(),
                    min: 3,
                    max: 10,
                    divisions: 7,
                    label: '$_countdown s',
                    activeColor: AppColors.primaryLight,
                    onChanged: (val) {
                      setState(() => _countdown = val.toInt());
                    },
                  ),
                  const Divider(color: AppColors.border),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Shake-to-SOS Detection', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Vigorously shaking device initiates 5s emergency countdown', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    value: _shakeToSos,
                    activeColor: AppColors.primaryLight,
                    onChanged: (val) => setState(() => _shakeToSos = val),
                  ),
                  const Divider(color: AppColors.border),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Voice Distress Keyword Monitor', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Detects urgent cries like "HELP" or "EMERGENCY"', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    value: _voiceDistress,
                    activeColor: AppColors.primaryLight,
                    onChanged: (val) => setState(() => _voiceDistress = val),
                  ),
                  const Divider(color: AppColors.border),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Automatic Fall Detection', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Uses accelerometer magnitude spike and stillness heuristics', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    value: _fallDetection,
                    activeColor: AppColors.primaryLight,
                    onChanged: (val) => setState(() => _fallDetection = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Academic Viva / College Demo Mode Switch
            const Text(
              'Academic Demonstration & Simulation',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.cautionYellow),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cautionYellow.withOpacity(0.5)),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable Demo Mode / Simulated Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text(
                  'Activates simulation toolbar to demonstrate falls, unsafe zones, and voice keywords without hardware risks.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                value: demoState.isDemoModeActive,
                activeColor: AppColors.cautionYellow,
                onChanged: (val) {
                  ref.read(demoModeProvider.notifier).toggleDemoMode(val);
                },
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Save System Configurations'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
