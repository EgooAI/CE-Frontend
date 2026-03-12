import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:ce_frontend/models/auth/user_config.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/auth/auth_response.dart';
import '../../models/auth/user.dart';
import 'api_client.dart';
import 'device_service.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _refreshTokenExpiryKey = 'refresh_token_expiry';
  static const String _userKey = 'auth_user';

  // 防止并发刷新
  static Future<String>? _refreshingFuture;
  // 防止重复登出
  static bool _isLoggingOut = false;

  Future<AuthResponse> login(String username, String password) async {
    try {
      final deviceId = await DeviceService.getDeviceId();
      final response = await ApiClient.instance.post(
        '/login',
        data: {
          'username': username,
          'password': password,
          'deviceId': deviceId,
        },
      );
      debugPrint('📱 登录响应数据: ${response.data}');

      late AuthResponse authResponse;
      try {
        authResponse = AuthResponse.fromJson(
          response.data as Map<String, dynamic>,
        );
      } catch (parseError) {
        debugPrint('❌ 响应解析失败: $parseError');
        debugPrint('❌ 响应类型: ${response.data.runtimeType}');
        rethrow;
      }

      await _saveTokens(
        authResponse.accessToken,
        authResponse.refreshToken,
        authResponse.expiresIn,
        authResponse.refreshExpiresIn,
      );
      await _saveUser(authResponse.user);
      ApiClient.setToken(authResponse.accessToken);
      return authResponse;
    } on DioException catch (e) {
      debugPrint('❌ 登录 DioException: ${e.message}');
      debugPrint('❌ 响应状态码: ${e.response?.statusCode}');
      debugPrint('❌ 响应体: ${e.response?.data}');
      throw Exception(_mapLoginErrorMessage(e));
    } catch (e) {
      debugPrint('❌ 登录异常: $e');
      throw Exception('登录失败: $e');
    }
  }

  String _mapLoginErrorMessage(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401) {
      return '用户名或密码错误';
    }

    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'] ?? data['error'] ?? data['detail'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    } else if (data is String && data.isNotEmpty) {
      return data;
    }

    return e.message ?? '登录失败';
  }

  Future<AuthResponse> register(
    String email,
    String username,
    String password,
  ) async {
    try {
      final deviceId = await DeviceService.getDeviceId();
      final response = await ApiClient.instance.post(
        '/register',
        data: {
          'email': email,
          'username': username,
          'password': password,
          'deviceId': deviceId,
        },
      );
      debugPrint('📱 注册响应数据: ${response.data}');

      late AuthResponse authResponse;
      try {
        authResponse = AuthResponse.fromJson(
          response.data as Map<String, dynamic>,
        );
      } catch (parseError) {
        debugPrint('❌ 响应解析失败: $parseError');
        debugPrint('❌ 响应类型: ${response.data.runtimeType}');
        rethrow;
      }

      await _saveTokens(
        authResponse.accessToken,
        authResponse.refreshToken,
        authResponse.expiresIn,
        authResponse.refreshExpiresIn,
      );
      await _saveUser(authResponse.user);
      ApiClient.setToken(authResponse.accessToken);
      return authResponse;
    } on DioException catch (e) {
      debugPrint('❌ 注册 DioException: ${e.message}');
      debugPrint('❌ 响应状态码: ${e.response?.statusCode}');
      debugPrint('❌ 响应体: ${e.response?.data}');
      throw Exception(e.message ?? '注册失败');
    } catch (e) {
      debugPrint('❌ 注册异常: $e');
      throw Exception('注册失败: $e');
    }
  }

  Future<void> logout() async {
    // 防止重复登出
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    try {
      // 尝试调用后端登出接口吊销 refresh_token
      final refreshToken = await getRefreshToken();
      final deviceId = await DeviceService.getDeviceId();

      if (refreshToken != null) {
        try {
          await ApiClient.instance.post(
            '/auth/logout',
            data: {'refresh_token': refreshToken, 'deviceId': deviceId},
          );
        } catch (e) {
          // 登出接口失败不影响本地清理
          print('AuthService: 登出接口调用失败 - $e');
        }
      }
    } finally {
      // 无论如何都清理本地状态
      await _clearLocalAuth();
      _isLoggingOut = false;
    }
  }

  /// 清理本地认证状态
  Future<void> _clearLocalAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_tokenExpiryKey);
    await prefs.remove(_refreshTokenExpiryKey);
    await prefs.remove(_userKey);
    ApiClient.clearToken();
    print('AuthService: 本地认证状态已清理');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// 保存所有 token 和过期时间
  Future<void> _saveTokens(
    String accessToken,
    String? refreshToken,
    int? expiresIn,
    int? refreshExpiresIn,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);

    if (refreshToken != null) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }

    // 存储过期时间戳（当前时间 + 有效期）
    if (expiresIn != null) {
      final expiry = DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);
      await prefs.setInt(_tokenExpiryKey, expiry);
    }

    if (refreshExpiresIn != null) {
      final refreshExpiry =
          DateTime.now().millisecondsSinceEpoch + (refreshExpiresIn * 1000);
      await prefs.setInt(_refreshTokenExpiryKey, refreshExpiry);
    }
  }

  /// 获取 refresh_token
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  /// 检查 access_token 是否即将过期（距离过期 < 5 分钟）
  Future<bool> isTokenExpiringSoon() async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = prefs.getInt(_tokenExpiryKey);

    if (expiry == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final fiveMinutes = 5 * 60 * 1000;

    return (expiry - now) < fiveMinutes;
  }

  /// 检查 refresh_token 是否已过期
  /// 若本地未存储过期时间（如老版本升级），乐观返回 false，
  /// 由服务端在实际刷新请求时给出最终判断。
  Future<bool> isRefreshTokenExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshExpiry = prefs.getInt(_refreshTokenExpiryKey);

    if (refreshExpiry == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    return now >= refreshExpiry;
  }

  Future<void> _saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_userKey);
    if (userStr != null) {
      try {
        return User.fromJson(jsonDecode(userStr));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// 刷新访问令牌
  /// 使用 refresh_token 获取新的 access_token 和 refresh_token
  /// 支持并发防抖：多个请求同时触发时只刷新一次
  Future<String> refreshAccessToken() async {
    // 如果已经在刷新中，等待当前刷新完成
    if (_refreshingFuture != null) {
      print('AuthService: 等待当前刷新完成...');
      return await _refreshingFuture!;
    }

    // 开始新的刷新流程
    _refreshingFuture = _performRefresh();

    try {
      final newToken = await _refreshingFuture!;
      return newToken;
    } finally {
      _refreshingFuture = null;
    }
  }

  /// 执行实际的刷新操作
  Future<String> _performRefresh() async {
    try {
      final refreshToken = await getRefreshToken();
      final deviceId = await DeviceService.getDeviceId();

      if (refreshToken == null) {
        throw Exception('未找到 refresh_token');
      }

      // 检查 refresh_token 是否过期
      if (await isRefreshTokenExpired()) {
        throw Exception('refresh_token 已过期');
      }

      print('AuthService: 正在刷新 access_token...');

      final response = await ApiClient.instance.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken, 'deviceId': deviceId},
      );

      // 注意：ApiClient 拦截器已自动解包 data 字段
      // response.data 已经是 {access_token, refresh_token, expires_in, ...}
      final data = response.data as Map<String, dynamic>;
      final newAccessToken = data['access_token'] as String;
      final newRefreshToken = data['refresh_token'] as String?;
      final expiresIn = data['expires_in'] as int?;
      final refreshExpiresIn = data['refresh_expires_in'] as int?;

      // 保存新的 tokens
      await _saveTokens(
        newAccessToken,
        newRefreshToken,
        expiresIn,
        refreshExpiresIn,
      );

      // 更新 API 客户端的 token
      ApiClient.setToken(newAccessToken);

      print('AuthService: Token 刷新成功');
      return newAccessToken;
    } on DioException catch (e) {
      print('AuthService: Token 刷新失败 - ${e.message}');
      // 刷新失败，清空本地状态
      await _clearLocalAuth();
      throw Exception('刷新令牌失败，请重新登录');
    } catch (e) {
      print('AuthService: Token 刷新异常 - $e');
      await _clearLocalAuth();
      rethrow;
    }
  }

  /// 初始化认证状态
  /// 仅做本地校验，网络验证由 ApiClient 的 401 拦截器惰性处理，
  /// 避免冷启动时因网络超时/服务不可达而误清除有效 token。
  Future<bool> initAuth() async {
    final token = await getToken();
    if (token == null) {
      print('AuthService: 未找到 token，跳过认证初始化');
      return false;
    }

    // refresh_token 已确认过期 → 必须重新登录
    if (await isRefreshTokenExpired()) {
      print('AuthService: refresh_token 已过期，需要重新登录');
      await _clearLocalAuth();
      return false;
    }

    // 设置 token 到 API 客户端
    ApiClient.setToken(token);

    // access_token 即将过期时尝试静默刷新；
    // 失败不退出登录，由 ApiClient 的 401 拦截器在实际请求时处理
    if (await isTokenExpiringSoon()) {
      print('AuthService: Token 即将过期，尝试静默刷新...');
      try {
        await refreshAccessToken();
      } catch (e) {
        print('AuthService: 静默刷新失败 - $e，将由 ApiClient 拦截器处理');
      }
    }

    return true;
  }

  Future<User> getProfile() async {
    try {
      final response = await ApiClient.instance.get('/profile');
      // 注意：ApiClient 拦截器已自动解包 data 字段
      // response.data 已经是 {user: {...}}
      final data = response.data as Map<String, dynamic>;
      final userData = data['user'];
      final user = User.fromJson(userData);
      await _saveUser(user);
      return user;
    } on DioException catch (e) {
      throw Exception(e.message ?? '获取用户信息失败');
    }
  }

  Future<User> updateEmail(String newEmail, String currentPassword) async {
    try {
      await ApiClient.instance.put(
        '/profile',
        data: {'email': newEmail, 'currentPassword': currentPassword},
      );
      // 更新成功后，重新获取完整的用户信息
      return await getProfile();
    } on DioException catch (e) {
      throw Exception(e.message ?? '更新邮箱失败');
    }
  }

  Future<User> updateUsername(
    String newUsername,
    String currentPassword,
  ) async {
    try {
      await ApiClient.instance.put(
        '/profile',
        data: {'username': newUsername, 'currentPassword': currentPassword},
      );
      return await getProfile();
    } on DioException catch (e) {
      throw Exception(e.message ?? '更新用户名失败');
    }
  }

  Future<void> updatePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      await ApiClient.instance.put(
        '/profile',
        data: {'password': newPassword, 'currentPassword': currentPassword},
      );
    } on DioException catch (e) {
      throw Exception(e.message ?? '更新密码失败');
    }
  }

  Future<void> updateUserConfig(UserConfig config) async {
    try {
      await ApiClient.instance.put('/profile/config', data: config.toJson());
      // 更新 SharedPreferences 中缓存的 user，确保其他页面读到最新 config
      final cachedUser = await getUser();
      if (cachedUser != null) {
        await _saveUser(cachedUser.copyWith(config: config));
      }
    } on DioException catch (e) {
      throw Exception(e.message ?? '更新用户配置失败');
    }
  }
}
