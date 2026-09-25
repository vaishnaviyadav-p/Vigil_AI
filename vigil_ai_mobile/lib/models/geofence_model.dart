class GeofenceModel {
  final int id;
  final int userId;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool notifyOnExit;
  final bool isActive;

  GeofenceModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.notifyOnExit,
    required this.isActive,
  });

  factory GeofenceModel.fromJson(Map<String, dynamic> json) {
    return GeofenceModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      name: json['name'] ?? 'Safe Zone',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (json['radius_meters'] as num?)?.toDouble() ?? 250.0,
      notifyOnExit: json['notify_on_exit'] ?? true,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      'notify_on_exit': notifyOnExit,
      'is_active': isActive,
    };
  }
}
