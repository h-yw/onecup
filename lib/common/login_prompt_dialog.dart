// lib/common/login_prompt_dialog.dart

import 'package:flutter/material.dart';
import 'package:onecup/screens/auth/auth_screen.dart';

/// 显示一个引导用户登录或注册的对话框。
///
/// 当游客用户尝试访问需要认证的功能时调用此函数。
Future<void> showLoginPromptDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('需要登录'),
        content: const SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text('此功能需要一个账户。'),
              Text('登录或注册以继续。'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('取消'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            child: const Text('登录/注册'),
            onPressed: () {
              Navigator.of(context).pop(); // 关闭对话框
              Navigator.push( // 打开认证页面
                context,
                MaterialPageRoute(builder: (context) => const AuthScreen()),
              );
            },
          ),
        ],
      );
    },
  );
}