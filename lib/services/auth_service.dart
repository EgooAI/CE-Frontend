import 'dart:convert';
import 'package:ce_frontend/models/user_config.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_response.dart';
import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  Future<AuthResponse> login(String username, String password) async {
    try {
      final response = await ApiClient.instance.post(
        '/login',
        data: {'username': username, 'password': password},
      );

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(response.data);
        await _saveToken(authResponse.token);
        await _saveUser(authResponse.user);
        ApiClient.setToken(authResponse.token);
        return authResponse;
      } else {
        throw Exception('登录失败: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception('登录失败: ${e.response?.data ?? e.message}');
    }
  }

  Future<AuthResponse> register(
    String email,
    String username,
    String password,
  ) async {
    try {
      final response = await ApiClient.instance.post(
        '/register',
        data: {'email': email, 'username': username, 'password': password},
      );

      if (response.statusCode == 201) {
        final authResponse = AuthResponse.fromJson(response.data);
        await _saveToken(authResponse.token);
        await _saveUser(authResponse.user);
        ApiClient.setToken(authResponse.token);
        return authResponse;
      } else {
        throw Exception('注册失败: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception('注册失败: ${e.response?.data ?? e.message}');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    ApiClient.clearToken();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
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

  Future<bool> initAuth() async {
    final token = await getToken();
    if (token != null) {
      ApiClient.setToken(token);
      return true;
    }
    return false;
  }

  Future<User> getProfile() async {
    try {
      final response = await ApiClient.instance.get('/profile');
      if (response.statusCode == 200) {
        final userData = response.data['user'];
        final user = User.fromJson(userData);
        await _saveUser(user);
        return user;
      } else {
        throw Exception('获取用户信息失败: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception('获取用户信息失败: ${e.response?.data ?? e.message}');
    }
  }

  Future<User> updateEmail(String newEmail, String currentPassword) async {
    try {
      final response = await ApiClient.instance.put(
        '/profile',
        data: {'email': newEmail, 'currentPassword': currentPassword},
      );

      if (response.statusCode == 200) {
        // 更新成功后，重新获取完整的用户信息
        return await getProfile();
      } else {
        throw Exception('更新邮箱失败: ${response.data}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw Exception('该邮箱已被使用');
      }
      throw Exception('更新邮箱失败: ${e.response?.data ?? e.message}');
    }
  }

  Future<User> updateUsername(
    String newUsername,
    String currentPassword,
  ) async {
    try {
      final response = await ApiClient.instance.put(
        '/profile',
        data: {'username': newUsername, 'currentPassword': currentPassword},
      );

      if (response.statusCode == 200) {
        return await getProfile();
      } else {
        throw Exception('更新用户名失败: ${response.data}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw Exception('该用户名已被使用');
      }
      if (e.response?.statusCode == 401) {
        throw Exception('密码错误');
      }
      throw Exception('更新用户名失败: ${e.response?.data ?? e.message}');
    }
  }

  Future<void> updatePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final response = await ApiClient.instance.put(
        '/profile',
        data: {'password': newPassword, 'currentPassword': currentPassword},
      );

      if (response.statusCode != 200) {
        throw Exception('更新密码失败: ${response.data}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('当前密码错误');
      }
      throw Exception('更新密码失败: ${e.response?.data ?? e.message}');
    }
  }

  Future<void> updateUserConfig(UserConfig config) async {
    try {
      final response = await ApiClient.instance.put(
        '/profile/config',
        data: config.toJson(),
      );

      if (response.statusCode != 200) {
        throw Exception('更新用户配置失败: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception('更新用户配置失败: ${e.response?.data ?? e.message}');
    }
  }
}
