import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vigil_ai_mobile/core/constants/app_constants.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Token management
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: AppConstants.tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: AppConstants.tokenKey);
  }

  Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: AppConstants.refreshTokenKey, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: AppConstants.refreshTokenKey);
  }

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: AppConstants.tokenKey);
    await _secureStorage.delete(key: AppConstants.refreshTokenKey);
  }

  // Base URL config
  static String normalizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return AppConstants.defaultBaseUrl;
    }
    String clean = url.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    // Fix accidental duplication like http://.../api/api
    while (clean.endsWith('/api/api')) {
      clean = clean.substring(0, clean.length - 4);
    }
    // Ensure /api suffix exists for Flask backend API routes
    if (!clean.endsWith('/api')) {
      clean = '$clean/api';
    }
    return clean;
  }

  Future<void> saveBaseUrl(String url) async {
    final clean = normalizeUrl(url);
    await _prefs?.setString(AppConstants.baseUrlKey, clean);
  }

  String getBaseUrl() {
    final raw = _prefs?.getString(AppConstants.baseUrlKey);
    return normalizeUrl(raw);
  }

  Future<void> resetBaseUrl() async {
    await _prefs?.remove(AppConstants.baseUrlKey);
  }

  // Onboarding
  Future<void> setOnboardingCompleted(bool completed) async {
    await _prefs?.setBool(AppConstants.onboardingCompletedKey, completed);
  }

  bool isOnboardingCompleted() {
    return _prefs?.getBool(AppConstants.onboardingCompletedKey) ?? false;
  }

  // Demo Mode
  Future<void> setDemoMode(bool active) async {
    await _prefs?.setBool(AppConstants.demoModeKey, active);
  }

  bool isDemoMode() {
    return _prefs?.getBool(AppConstants.demoModeKey) ?? false;
  }

  // Clear all
  Future<void> clearAll() async {
    await clearTokens();
    await _prefs?.clear();
  }
}
