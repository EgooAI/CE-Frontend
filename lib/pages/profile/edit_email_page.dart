import 'package:flutter/material.dart';
import '../../models/auth/user.dart';
import '../../services/core/auth_service.dart';

class EditEmailPage extends StatefulWidget {
  final User user;

  const EditEmailPage({super.key, required this.user});

  @override
  State<EditEmailPage> createState() => _EditEmailPageState();
}

class _EditEmailPageState extends State<EditEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final _newEmailController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _canSave = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // 监听输入变化，控制保存按钮状态
    _newEmailController.addListener(_updateSaveButtonState);
    _confirmEmailController.addListener(_updateSaveButtonState);
    _passwordController.addListener(_updateSaveButtonState);
  }

  @override
  void dispose() {
    _newEmailController.dispose();
    _confirmEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updateSaveButtonState() {
    setState(() {
      _canSave =
          _newEmailController.text.isNotEmpty &&
          _confirmEmailController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty &&
          _newEmailController.text == _confirmEmailController.text &&
          _newEmailController.text != widget.user.email;
    });
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入邮箱';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return '请输入有效的邮箱地址';
    }

    if (value == widget.user.email) {
      return '新邮箱不能与当前邮箱相同';
    }

    return null;
  }

  String? _validateConfirmEmail(String? value) {
    if (value == null || value.isEmpty) {
      return '请确认邮箱';
    }

    if (value != _newEmailController.text) {
      return '两次输入的邮箱不一致';
    }

    return null;
  }

  Future<void> _saveEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedUser = await _authService.updateEmail(
        _newEmailController.text,
        _passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('邮箱更新成功！下次登录请使用新邮箱'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // 返回更新后的用户信息
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
        title: const Text('修改邮箱'),
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
            // 当前邮箱显示
            Card(
              child: ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('当前邮箱'),
                subtitle: Text(
                  widget.user.email,
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

            // 新邮箱输入
            TextFormField(
              controller: _newEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '新邮箱',
                hintText: '请输入新的邮箱地址',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              validator: _validateEmail,
              enabled: !_isLoading,
            ),

            const SizedBox(height: 16),

            // 确认邮箱输入
            TextFormField(
              controller: _confirmEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '确认新邮箱',
                hintText: '请再次输入新邮箱',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              validator: _validateConfirmEmail,
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
              onPressed: _canSave && !_isLoading ? _saveEmail : null,
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
                  const Text('• 邮箱将用于登录和接收通知'),
                  const SizedBox(height: 4),
                  const Text('• 请确保邮箱地址正确'),
                  const SizedBox(height: 4),
                  const Text('• 需要输入当前密码以确认身份'),
                  const SizedBox(height: 4),
                  const Text('• 修改后下次登录请使用新邮箱'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
