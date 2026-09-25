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
  Future<void> saveBaseUrl(String url) async {
    await _prefs?.setString(AppConstants.baseUrlKey, url);
  }

  String getBaseUrl() {
    return _prefs?.getString(AppConstants.baseUrlKey) ?? AppConstants.defaultBaseUrl;
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
