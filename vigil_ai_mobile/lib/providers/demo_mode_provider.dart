import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_ai_mobile/core/storage/storage_service.dart';
import 'package:vigil_ai_mobile/providers/emergency_provider.dart';
import 'package:vigil_ai_mobile/providers/risk_provider.dart';
import 'package:vigil_ai_mobile/providers/sensor_provider.dart';
import 'package:vigil_ai_mobile/services/notification_service.dart';
import 'package:vigil_ai_mobile/services/sensor_service.dart';

class DemoModeState {
  final bool isDemoModeActive;
  final String? activeSimulationName;

  DemoModeState({
    this.isDemoModeActive = false,
    this.activeSimulationName,
  });

  DemoModeState copyWith({
    bool? isDemoModeActive,
    String? activeSimulationName,
  }) {
    return DemoModeState(
      isDemoModeActive: isDemoModeActive ?? this.isDemoModeActive,
      activeSimulationName: activeSimulationName ?? this.activeSimulationName,
    );
  }
}

class DemoModeNotifier extends StateNotifier<DemoModeState> {
  final Ref _ref;
  final StorageService _storage = StorageService();
  final NotificationService _notification = NotificationService();

  DemoModeNotifier(this._ref) : super(DemoModeState()) {
    state = state.copyWith(isDemoModeActive: _storage.isDemoMode());
  }

  void toggleDemoMode(bool active) {
    _storage.setDemoMode(active);
    _ref.read(sensorProvider.notifier).setMode(active ? SensorMode.simulation : SensorMode.real);
    state = state.copyWith(isDemoModeActive: active);
  }

  Future<void> triggerSimulation(String scenario) async {
    state = state.copyWith(activeSimulationName: scenario);

    switch (scenario.toUpperCase()) {
      case 'NORMAL':
        _ref.read(sensorProvider.notifier).injectDemoState('NORMAL');
        _ref.read(riskProvider.notifier).resetToNominal();
        break;

      case 'ABNORMAL_MOVEMENT':
        _ref.read(sensorProvider.notifier).injectDemoState('RUNNING');
        await _ref.read(riskProvider.notifier).evaluateRisk(
          isAnomaly: true,
          anomalyScore: 0.88,
        );
        await _notification.showNotification(
          id: 501,
          title: '⚠️ Abnormal Movement Detected',
          body: 'Kinematic sensors indicate abrupt anomalous motion.',
        );
        break;

      case 'FALL_DETECTED':
        _ref.read(sensorProvider.notifier).injectDemoState('FALL');
        await _ref.read(riskProvider.notifier).evaluateRisk(
          isFall: true,
        );
        await _notification.showNotification(
          id: 502,
          title: '🚨 Possible Fall Detected',
          body: 'A sudden impact shock was registered. Are you okay?',
        );
        break;

      case 'UNSAFE_ZONE':
        await _ref.read(riskProvider.notifier).evaluateRisk(
          latitude: 12.9810,
          longitude: 77.6040, // Railway underpass (high risk)
        );
        await _notification.showNotification(
          id: 503,
          title: '⚠️ Unsafe Zone Warning',
          body: 'You have entered configured High-Risk Zone: Railway Underpass.',
        );
        break;

      case 'GEOFENCE_BREACH':
        await _ref.read(riskProvider.notifier).evaluateRisk(
          latitude: 12.9900,
          longitude: 77.6200,
        );
        await _notification.showNotification(
          id: 504,
          title: '📍 Geofence Boundary Exited',
          body: 'You have left your configured safe perimeter.',
        );
        break;

      case 'VOICE_DISTRESS':
        await _ref.read(riskProvider.notifier).evaluateRisk(
          isDistressVoice: true,
          voiceKeyword: 'HELP',
        );
        await _notification.showNotification(
          id: 505,
          title: '🎤 Voice Distress Recognized',
          body: 'Emergency keyword "HELP" detected by acoustic monitor.',
        );
        break;

      case 'SOS':
        _ref.read(emergencyProvider.notifier).startCountdown(seconds: 5);
        break;

      case 'HIGH_RISK_EVENT':
        await _ref.read(riskProvider.notifier).evaluateRisk(
          isAnomaly: true,
          anomalyScore: 0.95,
          isDistressVoice: true,
          voiceKeyword: 'EMERGENCY',
          latitude: 12.9810,
          longitude: 77.6040,
        );
        await _notification.showNotification(
          id: 506,
          title: '🚨 CRITICAL SAFETY RISK (Score 86+)',
          body: 'Multiple concurrent risk indicators flagged by AI engine.',
        );
        break;
    }
  }
}

final demoModeProvider = StateNotifierProvider<DemoModeNotifier, DemoModeState>((ref) {
  return DemoModeNotifier(ref);
});
