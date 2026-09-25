class IncidentModel {
  final int id;
  final int userId;
  final String userName;
  final String category;
  final String description;
  final double latitude;
  final double longitude;
  final String? address;
  final String severity;
  final String? imageUrl;
  final String status;
  final DateTime? incidentTime;
  final DateTime? createdAt;

  IncidentModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.category,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.severity,
    this.imageUrl,
    required this.status,
    this.incidentTime,
    this.createdAt,
  });

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    return IncidentModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      userName: json['user_name'] ?? 'Anonymous',
      category: json['category'] ?? 'Other',
      description: json['description'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      address: json['address'],
      severity: json['severity'] ?? 'MEDIUM',
      imageUrl: json['image_url'],
      status: json['status'] ?? 'REPORTED',
      incidentTime: json['incident_time'] != null ? DateTime.tryParse(json['incident_time']) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'category': category,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'severity': severity,
      'image_url': imageUrl,
      'status': status,
      'incident_time': incidentTime?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
