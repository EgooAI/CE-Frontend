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

  Future<void> _navigateToEditUsername() async {
    final result = await Navigator.pushNamed(
      context,
      '/edit-username',
      arguments: user,
    );

    if (result != null && result is User) {
      setState(() {
        user = result;
      });
    }
  }

  Future<void> _navigateToEditPassword() async {
    await Navigator.pushNamed(context, '/edit-password', arguments: user);
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
              leading: const Icon(Icons.person),
              title: const Text('用户名'),
              subtitle: Text(user.username),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _navigateToEditUsername,
                tooltip: '修改用户名',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('密码'),
              subtitle: const Text('••••••'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _navigateToEditPassword,
                tooltip: '修改密码',
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
            ListTile(
              leading: const Icon(Icons.notifications_active),
              title: const Text('我的提醒'),
              subtitle: const Text('查看所有日程提醒'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pushNamed(context, '/reminders');
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('日常事项在日历中显示'),
              trailing: Switch(
                value: user.config.dailyScheduleDisplayInCalendar,
                onChanged: (value) async {
                  final oldConfig = user.config;
                  setState(() {
                    user = user.copyWith(
                      config: user.config.copyWith(
                        dailyScheduleDisplayInCalendar: value,
                      ),
                    );
                  });
                  try {
                    await AuthService().updateUserConfig(user.config);
                  } catch (e) {
                    if (!context.mounted) return;

                    setState(() {
                      user = user.copyWith(config: oldConfig);
                    });

                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('更新设置失败: $e')));
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
