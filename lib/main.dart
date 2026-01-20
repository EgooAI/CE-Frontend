import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'pages/auth/login_page.dart';
import 'pages/main_page.dart';
import 'pages/profile/user/edit_email_page.dart';
import 'pages/profile/user/edit_username_page.dart';
import 'pages/profile/user/edit_password_page.dart';
import 'pages/reminders/reminders_page.dart'; // ignore: unused_import
import 'pages/profile/recurrence/recurring_schedules_page.dart';
import 'pages/profile/cache/cache_management_page.dart';
import 'pages/profile/daily/daily_records_page.dart';
import 'services/core/auth_service.dart';
import 'services/core/api_client.dart';
import 'services/sync/sync_scheduler.dart';
import 'models/auth/user.dart';
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
    if (kIsWeb || kDebugMode) return;

    // 首次立即检查
    _checkForUpdates();

    // 每隔 5 分钟检查一次状态
    _updateCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    // 仅在非 Web 平台检查 Shorebird 更新
    if (kIsWeb || kDebugMode) return;

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

      // 如果没有缓存用户，再获取一次最新信息
      if (cachedUser == null) {
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
        themeAnimationDuration: Duration.zero,
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
      scrollBehavior: const AppScrollBehavior(),
      themeAnimationDuration: Duration.zero,
      theme: ThemeData(
        useMaterial3: false,
        brightness: Brightness.light,
        primaryColor: const Color(0xFF1F2329),
        scaffoldBackgroundColor: const Color(0xFFF5F6F8),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1F2329),
          secondary: Color(0xFF4B5563),
          surface: Colors.white,
          background: Color(0xFFF5F6F8),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFF1F2329),
          onBackground: Color(0xFF1F2329),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF1F2329)),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF1F2329)),
          bodySmall: TextStyle(fontSize: 13, color: Color(0xFF5F6368)),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1F2329),
          centerTitle: false,
          iconTheme: IconThemeData(color: Color(0xFF1F2329)),
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2329),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1F2329)),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFF0F0F0)),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          minVerticalPadding: 10,
          dense: false,
          textColor: Color(0xFF1F2329),
          iconColor: Color(0xFF1F2329),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE6E8EC),
          thickness: 0.8,
          space: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF3F5F8),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE6E8EC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE6E8EC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1F2329), width: 1),
          ),
          hintStyle: const TextStyle(color: Color(0xFF9AA0A6), fontSize: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1F2329),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF1F2329),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1F2329),
            side: const BorderSide(color: Color(0xFF1F2329)),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.white,
          contentTextStyle: const TextStyle(color: Colors.black, fontSize: 13),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 80,
            vertical: 24,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF1F2329),
          unselectedItemColor: Color(0xFF1F2329),
          showUnselectedLabels: true,
          selectedLabelStyle: TextStyle(fontSize: 12),
          unselectedLabelStyle: TextStyle(fontSize: 12),
          type: BottomNavigationBarType.fixed,
        ),
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

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return ClipRect(
      child: GlowingOverscrollIndicator(
        axisDirection: details.direction,
        color: const Color(0x1A000000),
        child: child,
      ),
    );
  }
}
