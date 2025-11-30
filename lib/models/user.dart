import 'package:ce_frontend/models/user_config.dart';

class User {
  final String id;
  final String email;
  final String username;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? notificationEmail;
  final UserConfig config;

  User({
    required this.id,
    required this.email,
    required this.username,
    this.createdAt,
    this.updatedAt,
    this.notificationEmail,
    required this.config,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      notificationEmail: json['notificationEmail'],
      config: json['config'] != null
          ? UserConfig.fromJson(json['config'])
          : UserConfig(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'notificationEmail': notificationEmail,
      'config': config.toJson(),
    };
  }

  User copyWith({
    String? notificationEmail,
    UserConfig? config,
    // ... 其他字段
  }) {
    return User(
      id: this.id,
      email: this.email,
      username: this.username,
      createdAt: this.createdAt,
      updatedAt: this.updatedAt,
      notificationEmail: notificationEmail ?? this.notificationEmail,
      config: config ?? this.config,
    );
  }
}
