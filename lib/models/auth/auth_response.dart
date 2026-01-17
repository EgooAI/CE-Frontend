import 'user.dart';

class TokenResponse {
  final String accessToken;
  final String expiresIn;
  final String tokenType;

  TokenResponse({
    required this.accessToken,
    required this.expiresIn,
    required this.tokenType,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['accessToken'],
      expiresIn: json['expiresIn'],
      tokenType: json['tokenType'],
    );
  }
}

class AuthResponse {
  final User user;
  final String accessToken; // 修改: token -> access_token
  final String? refreshToken; // 新增
  final int? expiresIn; // 新增
  final int? refreshExpiresIn; // 新增

  AuthResponse({
    required this.user,
    required this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.refreshExpiresIn,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      accessToken:
          json['access_token'] as String? ?? json['token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String?,
      expiresIn: json['expires_in'] as int?,
      refreshExpiresIn: json['refresh_expires_in'] as int?,
    );
  }
}
