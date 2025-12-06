import 'package:dio/dio.dart';

/// API 统一响应格式
class ApiResponse<T> {
  final int code;
  final String message;
  final T? data;
  final String? traceId;

  ApiResponse({
    required this.code,
    required this.message,
    this.data,
    this.traceId,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse<T>(
      code: json['code'] as int,
      message: json['message'] as String,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
      traceId: json['trace_id'] as String?,
    );
  }

  bool get isSuccess => code == 200 || code == 0;
}

class ApiClient {
  static const String _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8080/api',
  );

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  static bool _interceptorAdded = false;

  static Dio get instance {
    if (!_interceptorAdded) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onResponse: (response, handler) {
            // 处理统一响应格式
            if (response.data is Map<String, dynamic>) {
              final data = response.data as Map<String, dynamic>;

              // 检查是否是统一响应格式
              if (data.containsKey('code') && data.containsKey('message')) {
                final code = data['code'] as int;
                final message = data['message'] as String;

                // 如果 code 不是成功状态，抛出异常
                if (code != 200 && code != 201 && code != 0) {
                  handler.reject(
                    DioException(
                      requestOptions: response.requestOptions,
                      response: response,
                      type: DioExceptionType.badResponse,
                      error: message,
                      message: message,
                    ),
                  );
                  return;
                }

                // 将 data 字段提取出来作为响应数据
                // 如果 data 为 null，保持原样
                if (data.containsKey('data')) {
                  response.data = data['data'];
                }
              }
            }

            handler.next(response);
          },
          onError: (error, handler) {
            // 处理错误响应中的统一格式
            if (error.response?.data is Map<String, dynamic>) {
              final data = error.response!.data as Map<String, dynamic>;
              if (data.containsKey('message')) {
                error = DioException(
                  requestOptions: error.requestOptions,
                  response: error.response,
                  type: error.type,
                  error: data['message'],
                  message: data['message'] as String,
                );
              }
            }
            handler.next(error);
          },
        ),
      );
      _interceptorAdded = true;
    }
    return _dio;
  }

  static void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  static void clearToken() {
    _dio.options.headers.remove('Authorization');
  }
}
