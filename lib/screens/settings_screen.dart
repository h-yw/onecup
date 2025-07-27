// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:onecup/screens/edit_profile_screen.dart';
import 'package:onecup/screens/about_screen.dart';
import 'package:onecup/database/supabase_service.dart';
import 'package:share_plus/share_plus.dart';
import '../common/show_top_banner.dart';


class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // 登出方法 (可以从 ProfileScreen 移到这里，或者由 AuthController/AuthService 处理)
  Future<void> _signOut(BuildContext context) async {
    try {
      await SupabaseService().signOut();
      // 登出后，StreamBuilder 在 ProfileScreen 和其他地方会自动处理 UI 更新
      // 你可能想导航回主页或登录页
      if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (context.mounted) {
        // 使用局部变量避免 "Don't use BuildContexts across async gaps."
        showTopBanner(context, '登出失败: $e', isError: true);
      }
    }
  }

  // 分享应用方法
 /* Future<void> _shareApp(BuildContext context) async {
    // 你可以自定义分享的内容
    const String appName = "OneCup"; // 你的应用名称
    // TODO: 替换为你的应用在各应用商店的链接，或者你的应用网站链接
    const String appStoreLink = "https://apps.apple.com/app/your-app-id";
    const String playStoreLink = "https://play.google.com/store/apps/details?id=com.example.onecup";
    const String websiteLink = "https://your-app-website.com";

    String shareText;
    // 根据平台选择合适的链接，或者提供一个通用链接
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      shareText = "快来试试 $appName 应用吧！帮助你调制美味鸡尾酒：$appStoreLink";
    } else if (Theme.of(context).platform == TargetPlatform.android) {
      shareText = "快来试试 $appName 应用吧！帮助你调制美味鸡尾酒：$playStoreLink";
    } else {
      shareText = "快来试试 $appName 应用吧！帮助你调制美味鸡尾酒：$websiteLink";
    }

    // 你还可以分享一个主题（subject），这在邮件分享时有用
    const String subject = "推荐一款好用的鸡尾酒App：$appName";

    try {
      // Share.share(text, subject: subject)
      // Share.shareWithResult(text, subject: subject) // 可以获取分享结果
      final params =ShareParams(
        text: shareText,
        subject: subject,
      );
      final result = await SharePlus.instance.share(params);

      if (result.status == ShareResultStatus.success) {
        if (context.mounted) showTopBanner(context, '感谢您的分享！');
      } else if (result.status == ShareResultStatus.dismissed) {
        // 用户关闭了分享对话框
        if (context.mounted) showTopBanner(context, '分享已取消');
      } else if (result.status == ShareResultStatus.unavailable) {
        // 分享不可用 (例如，在某些模拟器或环境中)
        if (context.mounted) showTopBanner(context, '分享功能当前不可用', isError: true);
      }
    } catch (e) {
      if (context.mounted) showTopBanner(context, '分享失败: $e', isError: true);
    }
  }*/

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 获取当前用户，如果需要显示一些依赖用户状态的设置项
    final currentUser = SupabaseService().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        elevation: 0.5,
      ),
      body: ListView(
        children: <Widget>[
          if (currentUser != null) // 仅当用户登录时显示编辑资料
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
          /*ListTile(
            leading: Icon(Icons.share_outlined, color: theme.colorScheme.primary), // 分享图标
            title: const Text('分享给朋友'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _shareApp(context), // 调用分享方法
          ),
          const Divider(height: 0, indent: 16, endIndent: 16),*/
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

          // 更多设置项可以放在这里，例如：
          // ListTile(
          //   leading: Icon(Icons.notifications_none_outlined, color: theme.colorScheme.primary),
          //   title: const Text('通知设置'),
          //   trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          //   onTap: () { /* ... */ },
          // ),
          // const Divider(height: 0, indent: 16, endIndent: 16),
          // ListTile(
          //   leading: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
          //   title: const Text('隐私与安全'),
          //   trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          //   onTap: () { /* ... */ },
          // ),
          // const Divider(height: 0, indent: 16, endIndent: 16),

          if (currentUser != null) // 仅当用户登录时显示登出按钮
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
                onPressed: () => _signOut(context),
              ),
            ),
        ],
      ),
    );
  }
}
