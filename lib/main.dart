import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'pages/login_page.dart';
import 'pages/main_page.dart';
import 'pages/edit_email_page.dart';
import 'pages/edit_username_page.dart';
import 'pages/edit_password_page.dart';
import 'pages/reminders_page.dart'; // ignore: unused_import
import 'pages/recurring_schedules_page.dart';
import 'pages/cache_management_page.dart';
import 'pages/daily_records_page.dart';
import 'services/auth_service.dart';
import 'services/api_client.dart';
import 'services/sync_scheduler.dart';
import 'models/user.dart';
import 'utils/service_locator.dart';

// 全局 Navigator Key，用于 401 拦截跳转
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 全局 MainPage Key，用于访问 MainPage 的状态
final GlobalKey mainPageKey = GlobalKey();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化服务定位器（Hive + 依赖注入）
  await setupServiceLocator();

  // 设置全局 Navigator Key 到 ApiClient
  ApiClient.navigatorKey = navigatorKey;

  // 初始化 WorkManager（后台任务）- 仅在非 Web 平台
  if (!kIsWeb) {
    try {
      await Workmanager().initialize(
        syncQueueCallback, // 后台任务回调函数
        isInDebugMode: false, // 生产环境关闭调试
      );
      print('[Main] WorkManager 初始化完成');
    } catch (e) {
      print('[Main] ⚠️ WorkManager 初始化失败（可能不支持当前平台）: $e');
    }
  } else {
    print('[Main] ℹ️ Web 平台跳过 WorkManager 初始化');
  }

  // 启动同步调度器（网络监听 + 定期同步）
  final syncScheduler = SyncScheduler();
  await syncScheduler.init();

  // 强制竖屏（仅在移动平台）
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    // Web 平台不支持屏幕方向设置，忽略错误
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  User? _user;
  Timer? _updateCheckTimer;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _startUpdateMonitoring();
  }

  @override
  void dispose() {
    _updateCheckTimer?.cancel();
    super.dispose();
  }

  void _startUpdateMonitoring() {
    if (kIsWeb) return;

    // 首次立即检查
    _checkForUpdates();

    // 每隔 5 分钟检查一次状态
    _updateCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    // 仅在非 Web 平台检查 Shorebird 更新
    if (kIsWeb) return;

    try {
      final updater = ShorebirdUpdater();

      // 检查是否已下载完成（Shorebird 后台自动下载）
      final status = await updater.checkForUpdate();

      if (status == UpdateStatus.restartRequired) {
        print('[Shorebird] 检测到已下载的更新，提示重启');

        // 停止轮询
        _updateCheckTimer?.cancel();

        if (mounted && navigatorKey.currentContext != null) {
          _showUpdateDialog();
        }
      }
    } catch (e) {
      print('[Shorebird] 检查更新失败: $e');
    }
  }

  void _showUpdateDialog() {
    showDialog(
      context: navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue),
            SizedBox(width: 8),
            Text('已获取更新'),
          ],
        ),
        content: const Text(
          '应用已下载最新版本，请重启应用以应用更新。',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('稍后重启'),
          ),
          ElevatedButton(
            onPressed: () {
              // 关闭应用（用户手动重启）
              SystemNavigator.pop();
            },
            child: const Text('立即重启'),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeApp() async {
    final authService = AuthService();
    final isLoggedIn = await authService.initAuth();

    if (isLoggedIn) {
      // 尝试先从本地缓存获取用户信息
      final cachedUser = await authService.getUser();
      if (cachedUser != null) {
        setState(() {
          _isLoggedIn = true;
          _user = cachedUser;
          _isLoading = false;
        });
      }

      // 如果已登录，尝试获取最新用户信息
      try {
        final user = await authService.getProfile();
        if (mounted) {
          setState(() {
            _isLoggedIn = true;
            _user = user;
            _isLoading = false;
          });
        }
      } catch (e) {
        // 如果获取用户信息失败且没有缓存，清除token并跳转到登录页
        if (cachedUser == null) {
          await authService.logout();
          if (mounted) {
            setState(() {
              _isLoggedIn = false;
              _isLoading = false;
            });
          }
        }
      }
    } else {
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh', 'CN')],
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'CE Frontend',
      navigatorKey: navigatorKey, // 设置全局 Navigator Key
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          // primary: Colors.black,
          // onPrimary: Colors.white,
          surface: Colors.grey.shade100,
          // onSurface: Colors.black,
          // secondary: Colors.grey.shade700,
          // onSecondary: Colors.white,
          // error: Colors.red,
          // onError: Colors.white,
        ),

        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      locale: const Locale('zh', 'CN'),
      home: _isLoggedIn && _user != null
          ? MainPage(key: mainPageKey, user: _user!)
          : const LoginPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/reminders': (context) => const RemindersPage(),
        '/recurring-schedules': (context) => const RecurringSchedulesPage(),
        '/cache-management': (context) => const CacheManagementPage(),
        '/daily-records': (context) => const DailyRecordsPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/edit-email') {
          final user = settings.arguments as User;
          return MaterialPageRoute(
            builder: (context) => EditEmailPage(user: user),
          );
        }
        if (settings.name == '/edit-username') {
          final user = settings.arguments as User;
          return MaterialPageRoute(
            builder: (context) => EditUsernamePage(user: user),
          );
        }
        if (settings.name == '/edit-password') {
          final user = settings.arguments as User;
          return MaterialPageRoute(
            builder: (context) => EditPasswordPage(user: user),
          );
        }
        return null;
      },
    );
  }
}
