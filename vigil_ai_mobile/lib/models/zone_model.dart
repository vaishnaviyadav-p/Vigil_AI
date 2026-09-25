class ZoneModel {
  final int id;
  final String name;
  final String? description;
  final String zoneType; // SAFE, CAUTION, HIGH_RISK
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final double riskWeight;

  ZoneModel({
    required this.id,
    required this.name,
    this.description,
    required this.zoneType,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.riskWeight,
  });

  factory ZoneModel.fromJson(Map<String, dynamic> json) {
    return ZoneModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      zoneType: json['zone_type'] ?? 'HIGH_RISK',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (json['radius_meters'] as num?)?.toDouble() ?? 300.0,
      riskWeight: (json['risk_weight'] as num?)?.toDouble() ?? 25.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'zone_type': zoneType,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      'risk_weight': riskWeight,
    };
  }
}
