import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class EditUsernamePage extends StatefulWidget {
  final User user;

  const EditUsernamePage({super.key, required this.user});

  @override
  State<EditUsernamePage> createState() => _EditUsernamePageState();
}

class _EditUsernamePageState extends State<EditUsernamePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _canSave = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_updateSaveButtonState);
    _passwordController.addListener(_updateSaveButtonState);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updateSaveButtonState() {
    setState(() {
      _canSave =
          _usernameController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty &&
          _usernameController.text != widget.user.username;
    });
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入用户名';
    }

    if (value.length < 2) {
      return '用户名至少2个字符';
    }

    if (value.length > 50) {
      return '用户名最多50个字符';
    }

    if (value == widget.user.username) {
      return '新用户名不能与当前用户名相同';
    }

    return null;
  }

  Future<void> _saveUsername() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedUser = await _authService.updateUsername(
        _usernameController.text,
        _passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('用户名更新成功！'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.pop(context, updatedUser);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('修改用户名'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 当前用户名显示
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('当前用户名'),
                subtitle: Text(
                  widget.user.username,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // 新用户名输入
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '新用户名',
                hintText: '请输入新的用户名',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: _validateUsername,
              enabled: !_isLoading,
            ),

            const SizedBox(height: 16),

            // 当前密码输入
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: '当前密码',
                hintText: '请输入当前登录密码以确认身份',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入当前密码';
                }
                return null;
              },
              enabled: !_isLoading,
            ),

            const SizedBox(height: 32),

            // 保存按钮
            ElevatedButton(
              onPressed: _canSave && !_isLoading ? _saveUsername : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存', style: TextStyle(fontSize: 16)),
            ),

            const SizedBox(height: 24),

            // 提示信息
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        '提示',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('• 用户名将在应用中显示'),
                  const SizedBox(height: 4),
                  const Text('• 用户名长度为2-50个字符'),
                  const SizedBox(height: 4),
                  const Text('• 需要输入当前密码以确认身份'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
