import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_ai_mobile/services/sensor_service.dart';

class SensorState {
  final SensorMode mode;
  final double currentMagnitude;
  final double x;
  final double y;
  final double z;
  final bool possibleFallDetected;
  final String currentActivity;

  SensorState({
    this.mode = SensorMode.real,
    this.currentMagnitude = 9.8,
    this.x = 0.0,
    this.y = 0.0,
    this.z = 9.8,
    this.possibleFallDetected = false,
    this.currentActivity = 'STATIONARY',
  });

  SensorState copyWith({
    SensorMode? mode,
    double? currentMagnitude,
    double? x,
    double? y,
    double? z,
    bool? possibleFallDetected,
    String? currentActivity,
  }) {
    return SensorState(
      mode: mode ?? this.mode,
      currentMagnitude: currentMagnitude ?? this.currentMagnitude,
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      possibleFallDetected: possibleFallDetected ?? this.possibleFallDetected,
      currentActivity: currentActivity ?? this.currentActivity,
    );
  }
}

class SensorNotifier extends StateNotifier<SensorState> {
  final SensorService _sensorService = SensorService();
  StreamSubscription? _sensorSub;
  StreamSubscription? _fallSub;
  StreamSubscription? _shakeSub;

  SensorNotifier() : super(SensorState()) {
    init();
  }

  void init() {
    _sensorService.startMonitoring();

    _sensorSub = _sensorService.sensorStream.listen((point) {
      String activity = 'STATIONARY';
      if (point.magnitude > 25.0) {
        activity = 'IMPACT / SPIKE';
      } else if (point.magnitude > 14.0) {
        activity = 'RUNNING / SHAKE';
      } else if (point.magnitude > 10.8) {
        activity = 'WALKING';
      }

      state = state.copyWith(
        currentMagnitude: point.magnitude,
        x: point.x,
        y: point.y,
        z: point.z,
        mode: _sensorService.currentMode,
        currentActivity: activity,
      );
    });

    _fallSub = _sensorService.fallDetectedStream.listen((_) {
      state = state.copyWith(possibleFallDetected: true);
    });
  }

  void setMode(SensorMode mode) {
    _sensorService.currentMode = mode;
    state = state.copyWith(mode: mode);
  }

  void dismissFallAlert() {
    state = state.copyWith(possibleFallDetected: false);
  }

  void injectDemoState(String event) {
    _sensorService.injectSimulatedState(event);
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    _fallSub?.cancel();
    _shakeSub?.cancel();
    _sensorService.stopMonitoring();
    super.dispose();
  }
}

final sensorProvider = StateNotifierProvider<SensorNotifier, SensorState>((ref) {
  return SensorNotifier();
});
