import 'package:ce_frontend/models/auth/user_config.dart';
import 'package:hive/hive.dart';

part 'user.g.dart';

@HiveType(typeId: 2)
class User {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String email;
  @HiveField(2)
  final String username;
  @HiveField(3)
  final DateTime? createdAt;
  @HiveField(4)
  final DateTime? updatedAt;
  @HiveField(5)
  final String? notificationEmail;
  @HiveField(6)
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
