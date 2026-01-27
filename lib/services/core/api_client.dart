import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../cache/conditional_request_service.dart';

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

  // 全局 Navigator Key，用于 401 跳转登录页
  static GlobalKey<NavigatorState>? navigatorKey;

  static Dio get instance {
    if (!_interceptorAdded) {
      // 1. 条件请求拦截器（If-Modified-Since / Last-Modified）
      _dio.interceptors.add(ConditionalRequestService.getInterceptor());

      // 2. 响应拦截器：处理统一响应格式
      _dio.interceptors.add(
        InterceptorsWrapper(
          onResponse: (response, handler) {
            // 处理统一响应格式
            if (response.data is Map<String, dynamic>) {
              final data = response.data as Map<String, dynamic>;

              // 检查是否是统一响应格式
              if (data.containsKey('code') && data.containsKey('message')) {
                final code = data['code'];
                final message = data['message'];

                // 安全的类型检查和转换
                if (code is! int || message is! String) {
                  print(
                    'ApiClient: 响应格式错误 - code 类型: ${code.runtimeType}, message 类型: ${message.runtimeType}',
                  );
                  handler.next(response);
                  return;
                }

                // 如果 code 不是成功状态，抛出异常
                if (code != 200 && code != 201 && code != 0) {
                  print('ApiClient: 响应错误 - code: $code, message: $message');
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
                // 如果 data 为 null 或不存在，保持为 null（而不是原始响应）
                if (data.containsKey('data') && data['data'] != null) {
                  response.data = data['data'];
                } else {
                  // 没有 data 字段，设置为空 Map（避免 null 导致的类型错误）
                  response.data = {};
                }
              }
            }

            handler.next(response);
          },
          onError: (error, handler) async {
            // 401 拦截：自动刷新 token 或跳转登录
            if (error.response?.statusCode == 401) {
              print('ApiClient: 检测到 401，尝试刷新 token...');

              // 避免刷新接口本身触发无限循环
              if (error.requestOptions.path.contains('/auth/refresh') ||
                  error.requestOptions.path.contains('/login') ||
                  error.requestOptions.path.contains('/register')) {
                print('ApiClient: 认证接口返回 401，跳过刷新');
                if (!error.requestOptions.path.contains('/login') &&
                    !error.requestOptions.path.contains('/register')) {
                  _handleUnauthorized(error);
                }
                handler.next(error);
                return;
              }

              // 尝试刷新 token
              try {
                final authService = AuthService();
                final newToken = await authService.refreshAccessToken();

                // 更新请求头
                error.requestOptions.headers['Authorization'] =
                    'Bearer $newToken';

                // 重试原请求
                print('ApiClient: Token 刷新成功，重试请求...');
                final response = await _dio.fetch(error.requestOptions);
                handler.resolve(response);
                return;
              } catch (e) {
                print('ApiClient: Token 刷新失败 - $e');
                _handleUnauthorized(error);
                handler.next(error);
                return;
              }
            }

            // 优化错误信息：将技术性错误转换为友好提示
            String friendlyMessage = error.message ?? '网络请求失败';

            switch (error.type) {
              case DioExceptionType.connectionTimeout:
                friendlyMessage = '连接服务器超时，请检查网络连接';
                break;
              case DioExceptionType.sendTimeout:
                friendlyMessage = '发送请求超时，请检查网络连接';
                break;
              case DioExceptionType.receiveTimeout:
                friendlyMessage = '服务器响应超时，请稍后重试';
                break;
              case DioExceptionType.badCertificate:
                friendlyMessage = '安全证书验证失败';
                break;
              case DioExceptionType.badResponse:
                // 保持原有的错误消息（来自服务器）
                if (error.response?.data is Map<String, dynamic>) {
                  final data = error.response!.data as Map<String, dynamic>;
                  if (data.containsKey('message')) {
                    friendlyMessage = data['message'] as String;
                  }
                }
                break;
              case DioExceptionType.cancel:
                friendlyMessage = '请求已取消';
                break;
              case DioExceptionType.connectionError:
                friendlyMessage = '无法连接到服务器，请检查网络';
                break;
              case DioExceptionType.unknown:
                friendlyMessage = '网络请求失败，请稍后重试';
                break;
            }

            // 创建优化后的错误
            error = DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: error.error,
              message: friendlyMessage,
            );

            handler.next(error);
          },
        ),
      );
      _interceptorAdded = true;
    }
    return _dio;
  }

  /// 处理未授权错误：清空状态并跳转登录页
  static void _handleUnauthorized(DioException error) async {
    print('ApiClient: 处理 401 未授权，清空认证状态...');

    // 清空本地认证状态
    try {
      final authService = AuthService();
      await authService.logout();
    } catch (e) {
      print('ApiClient: 清空认证状态失败 - $e');
    }

    // 跳转登录页（使用全局 Navigator）
    if (navigatorKey?.currentState != null) {
      navigatorKey!.currentState!.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }
  }

  static void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  static void clearToken() {
    _dio.options.headers.remove('Authorization');
  }
}
