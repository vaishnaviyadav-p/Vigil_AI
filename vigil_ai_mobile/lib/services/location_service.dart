import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSub;
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionController.stream;

  Position? lastKnownPosition;

  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        return _fallbackPosition();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      lastKnownPosition = position;
      return position;
    } catch (e) {
      return lastKnownPosition ?? _fallbackPosition();
    }
  }

  void startTracking({void Function(Position)? onUpdate}) {
    _positionStreamSub?.cancel();
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // meters
    );

    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      lastKnownPosition = position;
      _positionController.add(position);
      if (onUpdate != null) onUpdate(position);
    }, onError: (e) {
      // Fallback
    });
  }

  void stopTracking() {
    _positionStreamSub?.cancel();
  }

  Position _fallbackPosition() {
    return Position(
      latitude: 12.9716,
      longitude: 77.5946,
      timestamp: DateTime.now(),
      accuracy: 10.0,
      altitude: 920.0,
      altitudeAccuracy: 5.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
  }
}
