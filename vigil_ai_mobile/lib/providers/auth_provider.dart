import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_ai_mobile/core/network/api_client.dart';
import 'package:vigil_ai_mobile/core/storage/storage_service.dart';
import 'package:vigil_ai_mobile/models/user_model.dart';
import 'package:vigil_ai_mobile/providers/contact_provider.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  factory AuthState.initial() => AuthState(status: AuthStatus.initial);

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  final ApiClient _api = ApiClient();
  final StorageService _storage = StorageService();

  AuthNotifier(this._ref) : super(AuthState.initial());

  Future<void> checkAuth() async {
    state = state.copyWith(status: AuthStatus.loading);
    final token = await _storage.getToken();
    if (token == null || token.isEmpty) {
      _ref.read(contactProvider.notifier).clear();
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final response = await _api.dio.get('/users/profile');
      if (response.data['success'] == true) {
        final user = UserModel.fromJson(response.data['data']);
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
        // Automatically fetch emergency contacts for the authenticated user
        await _ref.read(contactProvider.notifier).fetchContacts();
      } else {
        await _storage.clearTokens();
        _ref.read(contactProvider.notifier).clear();
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      // In demo mode or offline, prompt login
      _ref.read(contactProvider.notifier).clear();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  String _extractDioErrorMessage(DioException e, String defaultPrefix) {
    if (e.response?.data is Map && (e.response!.data as Map)['message'] != null) {
      return (e.response!.data as Map)['message'].toString();
    }
    if (e.response?.statusCode != null) {
      return 'HTTP ${e.response!.statusCode} (${e.response?.statusMessage ?? "Error"}) for ${e.requestOptions.uri}';
    }
    if (e.type == DioExceptionType.connectionTimeout) {
      return 'Connection timed out reaching ${e.requestOptions.uri}. Check Wi-Fi / IP.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Cannot connect to ${e.requestOptions.uri}. Check server URL in Settings.';
    }
    return e.message ?? '$defaultPrefix. Check server URL in Settings.';
  }

  Future<bool> login(String identifier, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final response = await _api.dio.post('/auth/login', data: {
        'email': identifier,
        'password': password,
      });

      if (response.data['success'] == true) {
        final data = response.data['data'];
        await _storage.saveToken(data['access_token']);
        if (data['refresh_token'] != null) {
          await _storage.saveRefreshToken(data['refresh_token']);
        }
        final user = UserModel.fromJson(data['user']);
        state = state.copyWith(status: AuthStatus.authenticated, user: user);

        // Synchronize emergency contacts for this specific authenticated user
        await _ref.read(contactProvider.notifier).fetchContacts();
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: response.data['message'] ?? 'Login failed',
        );
        return false;
      }
    } on DioException catch (e) {
      final msg = _extractDioErrorMessage(e, 'Connection error');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: msg,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'An unexpected error occurred: $e',
      );
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final response = await _api.dio.post('/auth/register', data: {
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'password': password,
        'confirm_password': confirmPassword,
      });

      if (response.data['success'] == true) {
        final data = response.data['data'];
        await _storage.saveToken(data['access_token']);
        final user = UserModel.fromJson(data['user']);
        state = state.copyWith(status: AuthStatus.authenticated, user: user);

        // Synchronize fresh contacts for registered user
        await _ref.read(contactProvider.notifier).fetchContacts();
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: response.data['message'] ?? 'Registration failed',
        );
        return false;
      }
    } on DioException catch (e) {
      final msg = _extractDioErrorMessage(e, 'Registration error');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: msg,
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _api.dio.post('/auth/logout');
    } catch (_) {}
    await _storage.clearTokens();
    // Wipe contacts from memory immediately on logout to prevent leak to another account
    _ref.read(contactProvider.notifier).clear();
    state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
  }

  Future<void> updateSettings({
    int? emergencyCountdown,
    bool? shakeToSos,
    bool? voiceDistressDetection,
    bool? fallDetection,
    bool? demoMode,
  }) async {
    try {
      final Map<String, dynamic> payload = {};
      if (emergencyCountdown != null) payload['emergency_countdown'] = emergencyCountdown;
      if (shakeToSos != null) payload['shake_to_sos'] = shakeToSos;
      if (voiceDistressDetection != null) payload['voice_distress_detection'] = voiceDistressDetection;
      if (fallDetection != null) payload['fall_detection'] = fallDetection;
      if (demoMode != null) payload['demo_mode'] = demoMode;

      final res = await _api.dio.put('/users/settings', data: payload);
      if (res.data['success'] == true && state.user != null) {
        final updatedProfile = ProfileModel.fromJson(res.data['data']);
        final updatedUser = UserModel(
          id: state.user!.id,
          fullName: state.user!.fullName,
          email: state.user!.email,
          phone: state.user!.phone,
          role: state.user!.role,
          isActive: state.user!.isActive,
          profile: updatedProfile,
        );
        state = state.copyWith(user: updatedUser);
      }
    } catch (_) {}
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
