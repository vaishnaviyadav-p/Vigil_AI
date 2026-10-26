class ContactModel {
  final int id;
  final int userId;
  final String name;
  final String phone;
  final String? email;
  final String relationship;
  final int priority;
  final bool isActive;
  final String notificationPreference;

  ContactModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    this.email,
    required this.relationship,
    required this.priority,
    required this.isActive,
    required this.notificationPreference,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      relationship: json['relationship'] ?? 'Friend',
      priority: json['priority'] ?? 1,
      isActive: json['is_active'] ?? true,
      notificationPreference: json['notification_preference'] ?? 'ALL',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'phone': phone,
      'email': email,
      'relationship': relationship,
      'priority': priority,
      'is_active': isActive,
      'notification_preference': notificationPreference,
    };
  }

  ContactModel copyWith({
    int? id,
    int? userId,
    String? name,
    String? phone,
    String? email,
    String? relationship,
    int? priority,
    bool? isActive,
    String? notificationPreference,
  }) {
    return ContactModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      relationship: relationship ?? this.relationship,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      notificationPreference: notificationPreference ?? this.notificationPreference,
    );
  }
}
