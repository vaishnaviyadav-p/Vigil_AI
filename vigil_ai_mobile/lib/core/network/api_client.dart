import 'package:dio/dio.dart';
import 'package:vigil_ai_mobile/core/storage/storage_service.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio dio;
  final StorageService _storage = StorageService();

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: _storage.getBaseUrl(),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Always read latest configured baseUrl
          options.baseUrl = _storage.getBaseUrl();

          final token = await _storage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          // Pass cleanly to callers
          return handler.next(error);
        },
      ),
    );
  }

  void updateBaseUrl(String newUrl) {
    dio.options.baseUrl = StorageService.normalizeUrl(newUrl);
  }

  Future<({bool success, String message})> testConnection([String? testUrl]) async {
    final targetUrl = StorageService.normalizeUrl(testUrl ?? _storage.getBaseUrl());
    final testDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
      ),
    );

    // Root test URL: strips /api to hit Flask root /
    String rootUrl = targetUrl;
    if (rootUrl.endsWith('/api')) {
      rootUrl = rootUrl.substring(0, rootUrl.length - 4);
    }
    if (rootUrl.isEmpty) rootUrl = '/';

    try {
      final res = await testDio.get(rootUrl);
      if (res.statusCode == 200) {
        final status = (res.data is Map) ? (res.data['status'] ?? 'OK') : 'OK';
        return (
          success: true,
          message: 'Connected successfully ($status) to $targetUrl',
        );
      }
      return (
        success: false,
        message: 'Server responded with HTTP ${res.statusCode}',
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return (
          success: false,
          message: 'Timeout connecting to $targetUrl. Verify same Wi-Fi network.',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        return (
          success: false,
          message: 'Connection failed at $targetUrl. Check IP / port 5000.',
        );
      }
      return (
        success: false,
        message: 'Network error: ${e.message ?? e.toString()}',
      );
    } catch (e) {
      return (
        success: false,
        message: 'Connection failed: $e',
      );
    }
  }
}
