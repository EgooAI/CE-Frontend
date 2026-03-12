import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'pages/auth/login_page.dart';
import 'pages/main_page.dart';
import 'pages/profile/user/edit_email_page.dart';
import 'pages/profile/user/edit_username_page.dart';
import 'pages/profile/user/edit_password_page.dart';
import 'pages/profile/update/check_update_page.dart';
import 'pages/reminders/reminders_page.dart'; // ignore: unused_import
import 'pages/profile/recurrence/recurring_schedules_page.dart';
import 'pages/profile/cache/cache_management_page.dart';
import 'pages/profile/daily/daily_records_page.dart';
import 'services/app_release/app_release_service.dart';
import 'services/core/auth_service.dart';
import 'services/core/api_client.dart';
import 'services/sync/sync_scheduler.dart';
import 'models/auth/user.dart';
import 'utils/service_locator.dart';
import 'utils/app_keys.dart';

// 全局 Navigator Key，用于 401 拦截跳转
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
  static const String _updateDialogSuppressKeyPrefix =
      'update_dialog_suppress_until_';

  bool _isLoading = true;
  bool _isLoggedIn = false;
  User? _user;
  bool _startupVersionCheckScheduled = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _scheduleStartupVersionCheck();
  }

  void _scheduleStartupVersionCheck() {
    if (_startupVersionCheckScheduled) return;
    _startupVersionCheckScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVersionOnStartup();
    });
  }

  Future<void> _checkVersionOnStartup() async {
    print('[UpdateCheck] startup check begin');
    try {
      final versionInfo = await AppReleaseService().getLatestVersion();
      print(
        '[UpdateCheck] latest version fetched: ${versionInfo.latestVersion}',
      );

      String currentVersion = '0.0.0';
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        currentVersion = packageInfo.version.split('+').first;
      } catch (e) {
        print('[UpdateCheck] current version read failed: $e');
      }
      final latestVersion = versionInfo.latestVersion;
      final hasNewVersion = _hasNewVersion(currentVersion, latestVersion);
      print(
        '[UpdateCheck] current=$currentVersion latest=$latestVersion hasNew=$hasNewVersion debug=$kDebugMode',
      );

      if (!hasNewVersion) {
        print('[UpdateCheck] skip dialog: already latest');
        return;
      }

      final suppressed = await _isUpdateDialogSuppressed(latestVersion);
      if (suppressed) {
        print('[UpdateCheck] skip dialog: suppressed until window expires');
        return;
      }

      _showNewVersionDialogWhenReady(
        currentVersion,
        latestVersion,
        suppressVersion: latestVersion,
      );
    } catch (e) {
      print('[UpdateCheck] latest version request failed: $e');
      // 启动检查失败不影响主流程，静默忽略
    }
  }

  void _showNewVersionDialogWhenReady(
    String currentVersion,
    String latestVersion, {
    String? suppressVersion,
    int attempts = 0,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        _showNewVersionDialog(
          context,
          currentVersion,
          latestVersion,
          suppressVersion: suppressVersion,
        );
        return;
      }
      if (attempts >= 8) return;
      _showNewVersionDialogWhenReady(
        currentVersion,
        latestVersion,
        suppressVersion: suppressVersion,
        attempts: attempts + 1,
      );
    });
  }

  Future<bool> _isUpdateDialogSuppressed(String latestVersion) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_updateDialogSuppressKeyPrefix$latestVersion';
    final suppressUntilMs = prefs.getInt(key);
    if (suppressUntilMs == null) return false;
    return DateTime.now().millisecondsSinceEpoch < suppressUntilMs;
  }

  Future<void> _suppressUpdateDialogForThreeDays(String latestVersion) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_updateDialogSuppressKeyPrefix$latestVersion';
    final suppressUntil = DateTime.now().add(const Duration(days: 3));
    await prefs.setInt(key, suppressUntil.millisecondsSinceEpoch);
  }

  bool _hasNewVersion(String current, String latest) {
    final c = _parseVersion(current);
    final l = _parseVersion(latest);
    for (int i = 0; i < 3; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  List<int> _parseVersion(String value) {
    final parts = value.split('.');
    return List.generate(
      3,
      (i) => i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0,
    );
  }

  void _showNewVersionDialog(
    BuildContext context,
    String currentVersion,
    String latestVersion, {
    String? suppressVersion,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Color(0xFF5B8CFF)),
            const SizedBox(width: 8),
            Flexible(child: Text('发现新版本 v$latestVersion')),
          ],
        ),
        content: Text('当前版本 v$currentVersion，发现新版本，可前往查看更新内容和下载。'),
        actions: [
          TextButton(
            onPressed: () async {
              if (suppressVersion != null) {
                await _suppressUpdateDialogForThreeDays(suppressVersion);
              }
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
            },
            child: const Text('稍后再说'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              navigatorKey.currentState?.pushNamed('/check-update');
            },
            child: const Text('查看详情'),
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
        // 有缓存时：后台静默刷新，更新 config 等最新数据
        authService
            .getProfile()
            .then((user) {
              if (mounted) setState(() => _user = user);
            })
            .catchError((_) {
              /* 静默失败，保持缓存 */
            });
      }

      // 无论有无缓存，都后台拉一次最新 profile（秒开 + 数据保鲜）
      if (cachedUser == null) {
        // 无缓存：必须等待网络返回再进入主页
        try {
          final user = await authService.getProfile();
          if (mounted) {
            setState(() {
              _isLoggedIn = true;
              _user = user;
              _isLoading = false;
            });
          }
        } on DioException catch (e) {
          // 仅在服务端明确返回 401 时才清除 token 并跳转登录页；
          // 网络超时、服务不可达等情况不清除 token，下次启动可自动恢复
          if (e.response?.statusCode == 401) {
            await authService.logout();
          }
          if (mounted) {
            setState(() {
              _isLoggedIn = false;
              _isLoading = false;
            });
          }
        } catch (e) {
          // 其他异常（非网络）：不清除 token，仅退回登录页
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
        navigatorKey: navigatorKey,
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
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          elevation: 10,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          titleTextStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2329),
          ),
          contentTextStyle: const TextStyle(
            fontSize: 14,
            color: Color(0xFF4B5563),
            height: 1.5,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
        '/check-update': (context) => const CheckUpdatePage(),
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
