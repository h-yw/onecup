// lib/screens/about_screen.dart
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _version = '${packageInfo.version} (Build ${packageInfo.buildNumber})';
      });
    } catch (e) {
      setState(() {
        _version = '无法获取版本号';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于 OneCup'),
        elevation: 0.5,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // 你可以放一个 App Logo
              Image.asset('assets/logo/logo-white-512x512.png',width: 80,height:80,),
              const SizedBox(height: 24),
              Text(
                'OneCup',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '版本 $_version',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Text(
                '一款帮助您探索和调制美味鸡尾酒的应用。',
                textAlign: TextAlign.center,

                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              Text(
                '© ${DateTime.now().year} Mr.Hou', // 替换为你的公司或开发者名称
                style: theme.textTheme.bodySmall,
              ),
              // 你还可以添加链接到隐私政策、服务条款等
            ],
          ),
        ),
      ),
    );
  }
}
