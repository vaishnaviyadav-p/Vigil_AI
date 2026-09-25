import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

enum SensorMode { real, simulation }

class SensorDataPoint {
  final double x;
  final double y;
  final double z;
  final double magnitude;
  final DateTime timestamp;

  SensorDataPoint({
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
    required this.timestamp,
  });
}

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  SensorMode currentMode = SensorMode.real;
  StreamSubscription<UserAccelerometerEvent>? _sensorSub;

  final StreamController<SensorDataPoint> _sensorStreamController =
      StreamController<SensorDataPoint>.broadcast();
  Stream<SensorDataPoint> get sensorStream => _sensorStreamController.stream;

  final StreamController<bool> _fallDetectedController =
      StreamController<bool>.broadcast();
  Stream<bool> get fallDetectedStream => _fallDetectedController.stream;

  final StreamController<bool> _shakeDetectedController =
      StreamController<bool>.broadcast();
  Stream<bool> get shakeDetectedStream => _shakeDetectedController.stream;

  // Sensor window for calculations
  final List<double> _magnitudeHistory = [];
  DateTime _lastShakeTime = DateTime.now();
  int _shakeCounter = 0;
  bool _fallCandidate = false;
  DateTime? _fallSpikeTime;

  void startMonitoring() {
    _sensorSub?.cancel();
    _sensorSub = userAccelerometerEventStream().listen(
      (UserAccelerometerEvent event) {
        if (currentMode == SensorMode.real) {
          _processReading(event.x, event.y, event.z);
        }
      },
      onError: (e) {
        // Fallback to demo mode if real sensors unavailable (e.g., standard PC emulator)
        currentMode = SensorMode.simulation;
      },
    );
  }

  void _processReading(double x, double y, double z) {
    // Euclidean magnitude
    final magnitude = sqrt(x * x + y * y + z * z);
    final now = DateTime.now();

    final point = SensorDataPoint(
      x: x,
      y: y,
      z: z,
      magnitude: magnitude,
      timestamp: now,
    );
    _sensorStreamController.add(point);

    _magnitudeHistory.add(magnitude);
    if (_magnitudeHistory.length > 50) {
      _magnitudeHistory.removeAt(0);
    }

    // 1. Shake Detection Heuristic
    if (magnitude > 14.0) {
      if (now.difference(_lastShakeTime).inMilliseconds < 800) {
        _shakeCounter++;
        if (_shakeCounter >= 4) {
          _shakeDetectedController.add(true);
          _shakeCounter = 0;
        }
      } else {
        _shakeCounter = 1;
      }
      _lastShakeTime = now;
    }

    // 2. Fall Detection Heuristic
    // Spike: sudden acceleration spike > 22 m/s^2
    if (magnitude > 22.0 && !_fallCandidate) {
      _fallCandidate = true;
      _fallSpikeTime = now;
    } else if (_fallCandidate && _fallSpikeTime != null) {
      // Inactivity window: check if magnitude drops to low activity within 0.5-2 seconds
      final diff = now.difference(_fallSpikeTime!).inMilliseconds;
      if (diff > 500 && diff < 2000) {
        if (magnitude < 3.5) {
          // Possible fall confirmed
          _fallDetectedController.add(true);
          _fallCandidate = false;
          _fallSpikeTime = null;
        }
      } else if (diff >= 2000) {
        _fallCandidate = false;
        _fallSpikeTime = null;
      }
    }
  }

  // Simulation mode methods for viva / college presentations
  void injectSimulatedState(String state) {
    currentMode = SensorMode.simulation;
    switch (state.toUpperCase()) {
      case 'NORMAL':
        _processReading(0.2, 0.3, 9.8);
        break;
      case 'WALKING':
        _processReading(1.5, 2.0, 9.8);
        break;
      case 'RUNNING':
        _processReading(4.0, 5.5, 11.2);
        break;
      case 'FALL':
        // Trigger simulated fall spike
        _processReading(12.0, 15.0, 26.5);
        Future.delayed(const Duration(milliseconds: 600), () {
          _processReading(0.1, 0.1, 1.2); // Stillness
          _fallDetectedController.add(true);
        });
        break;
      case 'SHAKE':
        _shakeDetectedController.add(true);
        _processReading(8.0, 9.5, 16.0);
        break;
      default:
        _processReading(0.0, 0.0, 9.8);
    }
  }

  void stopMonitoring() {
    _sensorSub?.cancel();
  }
}
