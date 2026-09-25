class EmergencyModel {
  final int id;
  final int userId;
  final String? userName;
  final String? userPhone;
  final String alertType;
  final String severity;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double riskScore;
  final String? description;
  final String status;
  final bool isLiveSharing;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? acknowledgedBy;

  EmergencyModel({
    required this.id,
    required this.userId,
    this.userName,
    this.userPhone,
    required this.alertType,
    required this.severity,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.riskScore,
    this.description,
    required this.status,
    required this.isLiveSharing,
    this.createdAt,
    this.resolvedAt,
    this.acknowledgedBy,
  });

  factory EmergencyModel.fromJson(Map<String, dynamic> json) {
    return EmergencyModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      userName: json['user_name'],
      userPhone: json['user_phone'],
      alertType: json['alert_type'] ?? 'SOS_MANUAL',
      severity: json['severity'] ?? 'HIGH',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 10.0,
      riskScore: (json['risk_score'] as num?)?.toDouble() ?? 75.0,
      description: json['description'],
      status: json['status'] ?? 'ACTIVE',
      isLiveSharing: json['is_live_sharing'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at']) : null,
      acknowledgedBy: json['acknowledged_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_phone': userPhone,
      'alert_type': alertType,
      'severity': severity,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'risk_score': riskScore,
      'description': description,
      'status': status,
      'is_live_sharing': isLiveSharing,
      'created_at': createdAt?.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'acknowledged_by': acknowledgedBy,
    };
  }
}
