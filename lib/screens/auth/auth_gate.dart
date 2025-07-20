// lib/screens/auth/auth_gate.dart

import 'package:flutter/material.dart';
import 'package:onecup/database/supabase_service.dart';
import 'package:onecup/main.dart'; // 导入 MainTabsScreen
import 'package:onecup/screens/auth/auth_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      // 监听 SupabaseService 中提供的认证状态流
      stream: SupabaseService().authStateChanges,
      builder: (context, snapshot) {
        // 当 Stream 正在等待第一个事件时，显示一个启动/加载屏幕
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 检查快照中是否有数据，以及 session 是否存在
        if (snapshot.hasData && snapshot.data!.session != null) {
          // 如果用户已登录，导航到应用主页
          return const MainTabsScreen();
        } else {
          // 如果用户未登录，显示认证页面
          return const AuthScreen();
        }
      },
    );
  }
}