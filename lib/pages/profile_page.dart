import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  final User initialUser;

  const ProfilePage({super.key, required this.initialUser});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late User user;

  @override
  void initState() {
    super.initState();
    user = widget.initialUser;
  }

  Future<void> _navigateToEditEmail() async {
    final result = await Navigator.pushNamed(
      context,
      '/edit-email',
      arguments: user,
    );

    if (result != null && result is User) {
      setState(() {
        user = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人主页'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
            const SizedBox(height: 24),
            Text(
              user.username,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('邮箱'),
              subtitle: Text(user.email),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _navigateToEditEmail,
                tooltip: '修改邮箱',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('注册时间'),
              subtitle: Text(
                user.createdAt != null
                    ? '${user.createdAt!.year}-${user.createdAt!.month.toString().padLeft(2, '0')}-${user.createdAt!.day.toString().padLeft(2, '0')}'
                    : "未知",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
