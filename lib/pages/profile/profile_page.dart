import 'package:flutter/material.dart';
import '../../models/auth/user.dart';
import '../../services/core/auth_service.dart';
import '../../widgets/common/app_snack_bar.dart';
import '../auth/login_page.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ProfilePage extends StatefulWidget {
  final User initialUser;

  const ProfilePage({super.key, required this.initialUser});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late User user;
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    user = widget.initialUser;
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      setState(() {
        _appVersion = '未知';
      });
    }
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 44,
                      child: Icon(Icons.person, size: 44),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.username,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2329),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'UUID：${user.id}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8A8F98),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // TODO: 账号管理功能未上线，暂时隐藏入口。
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionCard([
                _buildActionTile(
                  icon: Icons.email,
                  iconColor: const Color(0xFF5B8CFF),
                  title: '邮箱',
                  subtitle: user.email,
                  onTap: _navigateToEditEmail,
                ),
                _buildActionTile(
                  icon: Icons.person,
                  iconColor: const Color(0xFF7B61FF),
                  title: '用户名',
                  subtitle: user.username,
                  onTap: _navigateToEditUsername,
                ),
                _buildActionTile(
                  icon: Icons.lock,
                  iconColor: const Color(0xFF4D9CDB),
                  title: '密码',
                  subtitle: '••••••',
                  onTap: _navigateToEditPassword,
                ),
                _buildInfoTile(
                  icon: Icons.access_time,
                  iconColor: const Color(0xFF8BC34A),
                  title: '注册时间',
                  subtitle: user.createdAt != null
                      ? '${user.createdAt!.year}-${user.createdAt!.month.toString().padLeft(2, '0')}-${user.createdAt!.day.toString().padLeft(2, '0')}'
                      : '未知',
                ),
              ]),
              const SizedBox(height: 12),
              _buildSectionCard([
                _buildActionTile(
                  icon: Icons.notifications_active,
                  iconColor: const Color(0xFF4CAF50),
                  title: '我的提醒',
                  subtitle: '查看所有日程提醒',
                  onTap: () => Navigator.pushNamed(context, '/reminders'),
                ),
                _buildActionTile(
                  icon: Icons.repeat,
                  iconColor: const Color(0xFFFF9800),
                  title: '我的重复事件',
                  subtitle: '查看所有重复日程模板',
                  onTap: () =>
                      Navigator.pushNamed(context, '/recurring-schedules'),
                ),
                _buildActionTile(
                  icon: Icons.history,
                  iconColor: const Color(0xFF607D8B),
                  title: '日常记录',
                  subtitle: '查看打卡记录和坚持统计',
                  onTap: () => Navigator.pushNamed(context, '/daily-records'),
                ),
              ]),
              const SizedBox(height: 12),
              _buildSectionCard([
                _buildSwitchTile(
                  icon: Icons.calendar_today,
                  iconColor: const Color(0xFF5B8CFF),
                  title: '日常事项在日历中显示',
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

                      showAppSnackBar(
                        context,
                        SnackBar(content: Text('更新设置失败: $e')),
                      );
                    }
                  },
                ),
                _buildSwitchTile(
                  icon: Icons.schedule,
                  iconColor: const Color(0xFF5B8CFF),
                  title: '使用24小时制',
                  value: user.config.use24HourFormat,
                  onChanged: (value) async {
                    final oldConfig = user.config;
                    setState(() {
                      user = user.copyWith(
                        config: user.config.copyWith(use24HourFormat: value),
                      );
                    });
                    try {
                      await AuthService().updateUserConfig(user.config);
                    } catch (e) {
                      if (!context.mounted) return;

                      setState(() {
                        user = user.copyWith(config: oldConfig);
                      });

                      showAppSnackBar(
                        context,
                        SnackBar(content: Text('更新设置失败: $e')),
                      );
                    }
                  },
                ),
              ]),
              const SizedBox(height: 12),
              _buildSectionCard([
                _buildActionTile(
                  icon: Icons.storage,
                  iconColor: const Color(0xFF9C27B0),
                  title: '缓存管理',
                  subtitle: '查看和清理本地缓存',
                  onTap: () =>
                      Navigator.pushNamed(context, '/cache-management'),
                ),
              ]),
              Column(
                children: [
                  const SizedBox(height: 12),
                  _buildSectionCard([
                    _buildActionTile(
                      icon: Icons.system_update,
                      iconColor: const Color(0xFF5B8CFF),
                      title: '检查更新',
                      subtitle: '当前版本 ${_appVersion ?? '加载中...'}',
                      onTap: () =>
                          Navigator.pushNamed(context, '/check-update'),
                    ),
                  ]),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Color(0xFF8A8F98),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '应用版本: ',
                    style: TextStyle(fontSize: 13, color: Color(0xFF8A8F98)),
                  ),
                  Text(
                    _appVersion ?? '加载中...',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1F2329),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(children: _withDividers(children)),
    );
  }

  List<Widget> _withDividers(List<Widget> children) {
    final List<Widget> widgets = [];
    for (int i = 0; i < children.length; i++) {
      widgets.add(children[i]);
      if (i != children.length - 1) {
        widgets.add(const Divider(height: 1, color: Color(0xFFEDEDED)));
      }
    }
    return widgets;
  }

  Widget _buildIconAvatar(IconData icon, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: _buildIconAvatar(icon, iconColor),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: Color(0xFF8A8F98)))
          : null,
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFB0B3B8)),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
  }) {
    return ListTile(
      leading: _buildIconAvatar(icon, iconColor),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: Color(0xFF8A8F98)))
          : null,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: _buildIconAvatar(icon, iconColor),
      title: Text(title),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }

  // void _showAccountManagementToast() {
  //   showAppSnackBar(context, const SnackBar(content: Text('暂未开发此功能')));
  // }
}
