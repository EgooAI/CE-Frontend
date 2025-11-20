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
  final String token;

  AuthResponse({
    required this.user,
    required this.token,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: User.fromJson(json['user']),
      token: json['token'],
    );
  }
}