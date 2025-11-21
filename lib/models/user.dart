class User {
  final String id;
  final String email;
  final String username;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.email,
    required this.username,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
