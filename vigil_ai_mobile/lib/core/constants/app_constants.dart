import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'VIGIL AI';
  static const String appTagline = 'AI-Powered Safety Monitoring';
  
  // Default API base URL for Android Emulator (10.0.2.2 points to host localhost)
  // Can be adjusted in Settings for physical device testing
  static const String defaultBaseUrl ='http://10.86.146.132:5000/api';
  
  // Storage keys
  static const String tokenKey = 'vigil_jwt_token';
  static const String refreshTokenKey = 'vigil_refresh_token';
  static const String baseUrlKey = 'vigil_base_url';
  static const String userKey = 'vigil_current_user';
  static const String onboardingCompletedKey = 'vigil_onboarding_done';
  static const String demoModeKey = 'vigil_demo_mode_active';

  // Ethical AI Disclaimer
  static const String aiDisclaimer = 
      'VIGIL AI signals and risk scores serve as probabilistic indicators '
      'to assist safety monitoring and cannot definitively determine danger.';
}

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF090D16);
  static const Color surface = Color(0xFF111827);
  static const Color card = Color(0xFF1E293B);
  static const Color cardSecondary = Color(0xFF283548);
  static const Color border = Color(0xFF334155);

  // Safety Accents
  static const Color sosRed = Color(0xFFE11D48);
  static const Color sosRedGlow = Color(0x66E11D48);
  static const Color safeGreen = Color(0xFF10B981);
  static const Color cautionYellow = Color(0xFFF59E0B);
  static const Color highRiskOrange = Color(0xFFEA580C);
  static const Color primaryIndigo = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);

  // Text
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Risk Color Resolver
  static Color getRiskColor(String level) {
    switch (level.toUpperCase()) {
      case 'SAFE':
        return safeGreen;
      case 'LOW':
        return const Color(0xFF34D399);
      case 'MEDIUM':
        return cautionYellow;
      case 'HIGH':
        return highRiskOrange;
      case 'CRITICAL':
        return sosRed;
      default:
        return safeGreen;
    }
  }
}
