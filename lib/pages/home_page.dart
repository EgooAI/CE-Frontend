import 'package:flutter/material.dart';
import '../models/user.dart';

class HomePage extends StatelessWidget {
  final User user;

  const HomePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // 这里可以添加登出逻辑
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '欢迎回来！',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('用户名: ${user.username}'),
            Text('邮箱: ${user.email}'),
            Text('注册时间: ${user.createdAt != null ? user.createdAt.toString() : "未知"}'),
          ],
        ),
      ),
    );
  }
}