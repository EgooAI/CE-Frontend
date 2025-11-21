import 'package:dio/dio.dart';

class ApiClient {
  static const String _baseUrl = 'http://localhost:8080/api';

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  static Dio get instance => _dio;

  static void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  static void clearToken() {
    _dio.options.headers.remove('Authorization');
  }
}
