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
    dio.options.baseUrl = newUrl;
  }
}
