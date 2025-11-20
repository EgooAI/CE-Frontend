import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_response.dart';
import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';

  Future<AuthResponse> login(String username, String password) async {
    try {
      final response = await ApiClient.instance.post(
        '/login',
        data: {
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(response.data);
        await _saveToken(authResponse.token);
        ApiClient.setToken(authResponse.token);
        return authResponse;
      } else {
        throw Exception('登录失败: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception('登录失败: ${e.response?.data ?? e.message}');
    }
  }

  Future<AuthResponse> register(String email, String username, String password) async {
    try {
      final response = await ApiClient.instance.post(
        '/register',
        data: {
          'email': email,
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 201) {
        final authResponse = AuthResponse.fromJson(response.data);
        await _saveToken(authResponse.token);
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
        return User.fromJson(userData);
      } else {
        throw Exception('获取用户信息失败: ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception('获取用户信息失败: ${e.response?.data ?? e.message}');
    }
  }
}
