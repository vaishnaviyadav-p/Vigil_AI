class UserModel {
  final int id;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final bool isActive;
  final ProfileModel? profile;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    this.profile,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'USER',
      isActive: json['is_active'] ?? true,
      profile: json['profile'] != null ? ProfileModel.fromJson(json['profile']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'is_active': isActive,
      'profile': profile?.toJson(),
    };
  }
}

class ProfileModel {
  final String? bloodGroup;
  final String? medicalNotes;
  final String? avatarUrl;
  final int emergencyCountdown;
  final bool shakeToSos;
  final bool voiceDistressDetection;
  final bool fallDetection;
  final bool demoMode;

  ProfileModel({
    this.bloodGroup,
    this.medicalNotes,
    this.avatarUrl,
    this.emergencyCountdown = 5,
    this.shakeToSos = true,
    this.voiceDistressDetection = true,
    this.fallDetection = true,
    this.demoMode = false,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      bloodGroup: json['blood_group'],
      medicalNotes: json['medical_notes'],
      avatarUrl: json['avatar_url'],
      emergencyCountdown: json['emergency_countdown'] ?? 5,
      shakeToSos: json['shake_to_sos'] ?? true,
      voiceDistressDetection: json['voice_distress_detection'] ?? true,
      fallDetection: json['fall_detection'] ?? true,
      demoMode: json['demo_mode'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'blood_group': bloodGroup,
      'medical_notes': medicalNotes,
      'avatar_url': avatarUrl,
      'emergency_countdown': emergencyCountdown,
      'shake_to_sos': shakeToSos,
      'voice_distress_detection': voiceDistressDetection,
      'fall_detection': fallDetection,
      'demo_mode': demoMode,
    };
  }
}
