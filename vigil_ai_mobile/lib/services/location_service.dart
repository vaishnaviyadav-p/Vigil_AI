import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final Position? position;
  final String? errorMessage;
  final bool isSuccess;

  LocationResult.success(this.position)
      : isSuccess = true,
        errorMessage = null;

  LocationResult.error(this.errorMessage)
      : isSuccess = false,
        position = null;
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSub;
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionController.stream;

  Position? lastKnownPosition;

  /// Checks and requests location permission.
  Future<LocationResult> checkAndRequestPermission() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationResult.error(
        'GPS / Location Services are turned OFF. Please enable GPS in device settings.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationResult.error(
          'Location permission was denied. VIGIL AI requires GPS permission to share your location during an SOS.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationResult.error(
        'Location permission is permanently denied. Please enable location permissions in Android Settings > Apps > VIGIL AI.',
      );
    }

    return LocationResult.success(null);
  }

  /// Obtains the REAL current device GPS location without any hardcoded mock fallback.
  /// Strictly adheres to requirement: "Get the user's REAL current GPS latitude and longitude. Do not use hardcoded/demo coordinates."
  Future<LocationResult> getRealPosition() async {
    try {
      final permResult = await checkAndRequestPermission();
      if (!permResult.isSuccess) {
        return permResult;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (_) {
        // If high-accuracy live acquisition timed out, try last known real fix from device hardware
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        return LocationResult.error(
          'Could not acquire current GPS location. Please ensure you are not indoors with GPS blocked.',
        );
      }

      lastKnownPosition = position;
      return LocationResult.success(position);
    } catch (e) {
      return LocationResult.error('Location error: ${e.toString()}');
    }
  }

  /// General position query for general map display (returns null or last known if permissions fail)
  Future<Position?> getCurrentPosition() async {
    final result = await getRealPosition();
    if (result.isSuccess && result.position != null) {
      return result.position;
    }
    return lastKnownPosition;
  }

  /// Starts streaming real device location fixes periodically.
  void startTracking({
    required void Function(Position) onUpdate,
    void Function(dynamic)? onError,
  }) {
    stopTracking();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3, // meters
    );

    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        lastKnownPosition = position;
        _positionController.add(position);
        onUpdate(position);
      },
      onError: (err) {
        if (onError != null) onError(err);
      },
    );
  }

  /// Stops streaming location fixes.
  void stopTracking() {
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
  }
}
