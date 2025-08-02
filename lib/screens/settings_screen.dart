// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onecup/providers/auth_provider.dart';
import 'package:onecup/screens/edit_profile_screen.dart';
import 'package:onecup/screens/about_screen.dart';
import '../common/show_top_banner.dart';
import 'package:onecup/providers/theme_provider.dart'; // 导入主题提供者

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authRepositoryProvider).signOut();
      if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (context.mounted) {
        showTopBanner(context, '登出失败: $e', isError: true);
      }
    }
  }

  void _showThemeSelectionDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('选择主题'),
          content: Consumer(
            builder: (context, watch, child) {
              final currentThemeMode = ref.watch(themeProvider);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: AppThemeMode.values.map((themeMode) {
                  String themeName = '';
                  switch (themeMode) {
                    case AppThemeMode.light:
                      themeName = '默认主题';
                      break;
                    case AppThemeMode.soft:
                      themeName = '柔和主题';
                      break;
                    case AppThemeMode.dark:
                      themeName = '暗色主题';
                      break;
                    case AppThemeMode.anotherDark:
                      themeName = '深色主题';
                      break;
                  }
                  return RadioListTile<AppThemeMode>(
                    title: Text(themeName),
                    value: themeMode,
                    groupValue: currentThemeMode,
                    onChanged: (AppThemeMode? newValue) {
                      if (newValue != null) {
                        ref.read(themeProvider.notifier).setThemeMode(newValue);
                        Navigator.of(dialogContext).pop(); // 关闭对话框
                      }
                    },
                  );
                }).toList(),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        elevation: 0.5,
      ),
      body: ListView(
        children: <Widget>[
          if (currentUser != null)
            ListTile(
              leading: Icon(Icons.person_outline, color: theme.colorScheme.primary),
              title: const Text('编辑个人资料'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                );
              },
            ),
          if (currentUser != null) const Divider(height: 0, indent: 16, endIndent: 16),
          ListTile(
            leading: Icon(Icons.color_lens_outlined, color: theme.colorScheme.primary), // 新增主题选择图标
            title: const Text('主题选择'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showThemeSelectionDialog(context, ref), // 调用主题选择对话框
          ),
          const Divider(height: 0, indent: 16, endIndent: 16),
          ListTile(
            leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
            title: const Text('关于 OneCup'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),
          const Divider(height: 0, indent: 16, endIndent: 16),
          if (currentUser != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('退出登录'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                onPressed: () => _signOut(context, ref),
              ),
            ),
        ],
      ),
    );
  }
}
