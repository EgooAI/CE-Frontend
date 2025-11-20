import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/login_page.dart';
import 'pages/main_page.dart';
import 'services/auth_service.dart';
import 'models/user.dart';

void main() async {
  // 强制竖屏
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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
      // 如果已登录，尝试获取用户信息
      try {
        final user = await authService.getProfile();
        setState(() {
          _isLoggedIn = true;
          _user = user;
          _isLoading = false;
        });
      } catch (e) {
        // 如果获取用户信息失败，清除token并跳转到登录页
        await authService.logout();
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
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
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
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
    );
  }
}
