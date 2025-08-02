// lib/providers/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onecup/theme/app_theme.dart'; // 导入默认主题
import 'package:onecup/theme/soft_app_theme.dart'; // 导入柔和主题
import 'package:onecup/theme/dark_app_theme.dart'; // 导入暗色主题
import 'package:onecup/theme/another_dark_app_theme.dart'; // 导入另一个深色主题

enum AppThemeMode {
  light,
  soft,
  dark,
  anotherDark,
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<AppThemeMode> {
  ThemeNotifier() : super(AppThemeMode.light) {
    _loadThemeMode();
  }

  static const String _themeModeKey = 'app_theme_mode';

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final storedThemeMode = prefs.getString(_themeModeKey);
    debugPrint('ThemeNotifier: Loaded theme mode from prefs: $storedThemeMode');
    if (storedThemeMode != null) {
      state = AppThemeMode.values.firstWhere(
        (e) => e.toString() == 'AppThemeMode.\$storedThemeMode',
        orElse: () => AppThemeMode.light,
      );
      debugPrint('ThemeNotifier: Set initial theme mode to: $state');
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    debugPrint('ThemeNotifier: Setting theme mode to: $mode');
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.toString().split('.').last);
    debugPrint('ThemeNotifier: Saved theme mode to prefs: ${mode.toString().split('.').last}');
  }

  ThemeData get currentTheme {
    switch (state) {
      case AppThemeMode.light:
        return AppTheme.lightTheme;
      case AppThemeMode.soft:
        return SoftAppTheme.lightTheme;
      case AppThemeMode.dark:
        return DarkAppTheme.darkTheme;
      case AppThemeMode.anotherDark:
        return AnotherDarkAppTheme.darkTheme;
    }
  }
}
