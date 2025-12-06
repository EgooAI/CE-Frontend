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
      final authResponse = AuthResponse.fromJson(response.data);
      await _saveToken(authResponse.token);
      await _saveUser(authResponse.user);
      ApiClient.setToken(authResponse.token);
      return authResponse;
    } on DioException catch (e) {
      throw Exception(e.message ?? '登录失败');
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
      final authResponse = AuthResponse.fromJson(response.data);
      await _saveToken(authResponse.token);
      await _saveUser(authResponse.user);
      ApiClient.setToken(authResponse.token);
      return authResponse;
    } on DioException catch (e) {
      throw Exception(e.message ?? '注册失败');
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
      final userData = response.data['user'];
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
    } on DioException catch (e) {
      throw Exception(e.message ?? '更新用户配置失败');
    }
  }
}
