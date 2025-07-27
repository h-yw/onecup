// lib/screens/auth/auth_screen.dart

import 'package:flutter/material.dart';
import 'package:onecup/common/show_top_banner.dart';
import 'package:onecup/database/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabaseService = SupabaseService();

  bool _isLoginMode = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        // --- 登录逻辑 ---
        await _supabaseService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // [核心修复] 登录成功后，关闭当前登录页面
        if (mounted) {
          showTopBanner(context, '登录成功！');
          Navigator.of(context).pop();
        }

      } else {
        // --- 注册逻辑 ---
        await _supabaseService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // [核心修复] 注册成功后，提示用户并保持在登录页，以便他们后续确认邮箱后登录
        if (mounted) {
          showTopBanner(context, '注册成功！请检查您的邮箱以激活账户。');
          // 切换到登录模式，方便用户
          setState(() => _isLoginMode = true);
        }
      }
    } on AuthException catch (e) {
      print("登陆失败：$e");
      if (mounted) {
        if (e.message.contains('Email not confirmed')) {
          showTopBanner(
            context,
            '请先检查您的邮箱，并点击确认链接来激活账户。',
            isError: true,
          );
        } else {
          // [优化] 为无效凭据提供更友好的提示
          final message = e.message.contains('Invalid login credentials')
              ? '邮箱或密码错误，请重试。'
              : e.message;
          showTopBanner(context, message, isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        showTopBanner(context, '发生未知错误: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // [修改] 将整个页面包裹在 Scaffold 中，以提供一个返回按钮
    return Scaffold(
      appBar: AppBar(
        // 提供一个清晰的返回路径，即使用户不登录
        title: Text(_isLoginMode ? '登录' : '注册'),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.liquor_rounded, size: 80, color: theme.primaryColor),
                const SizedBox(height: 16),
                Text(
                  '欢迎来到 OneCup',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayLarge?.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLoginMode ? '登录以继续' : '创建您的账户',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: '电子邮箱',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@')) {
                      return '请输入一个有效的邮箱地址';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return '密码长度不能少于6位';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: _submit,
                  child: Text(_isLoginMode ? '登 录' : '注 册'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoginMode = !_isLoginMode;
                    });
                  },
                  child: Text(
                    _isLoginMode ? '还没有账户？点此注册' : '已有账户？直接登录',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}