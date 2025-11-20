import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/auth_response.dart';

class AuthService {
  static const String baseUrl = 'http://localhost:8080'; // 根据后端地址调整

  Future<AuthResponse> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return AuthResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('登录失败: ${response.body}');
    }
  }

  Future<AuthResponse> register(String email, String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      return AuthResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('注册失败: ${response.body}');
    }
  }

  Future<TokenResponse> refreshToken() async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return TokenResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('刷新token失败: ${response.body}');
    }
  }
}