import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/login_page.dart';
import 'pages/main_page.dart';
import 'pages/edit_email_page.dart';
import 'services/auth_service.dart';
import 'models/user.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  @override
  void initState() {
    super.initState();
    _initializeApp();
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
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'CE Frontend',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: _isLoggedIn && _user != null
          ? MainPage(user: _user!)
          : const LoginPage(),
      routes: {'/login': (context) => const LoginPage()},
      onGenerateRoute: (settings) {
        if (settings.name == '/edit-email') {
          final user = settings.arguments as User;
          return MaterialPageRoute(
            builder: (context) => EditEmailPage(user: user),
          );
        }
        return null;
      },
    );
  }
}
