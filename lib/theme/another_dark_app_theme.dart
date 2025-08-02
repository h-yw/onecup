// lib/theme/another_dark_app_theme.dart

import 'package:flutter/material.dart';

/// 应用程序的另一个深色UI主题配置。
///
/// 采用深色背景，搭配深绿色作为主色调，活泼的橙红色作为强调色，
/// 营造出沉稳、现代且易于夜间使用的视觉体验。
class AnotherDarkAppTheme {
  // 定义核心颜色以便复用
  static const Color _primaryColor = Color(0xFF5C8C14); // 深绿色
  static const Color _accentColor = Color(0xFFD94423);  // 活泼的橙红色
  static const Color _darkBgColor = Color(0xFF0D0D0D); // 纯黑色，用于深色模式的背景
  static const Color _surfaceColor = Color(0xFF1A1A1A); // 稍浅的深灰色，用于卡片、对话框等表面
  static const Color _lightTextColor = Color(0xFFCAD996); // 浅绿黄色，用于文本

  static ThemeData get darkTheme {
    return ThemeData(
      // 1. 核心颜色与亮度
      brightness: Brightness.dark,
      primaryColor: _primaryColor,
      scaffoldBackgroundColor: _darkBgColor,
      colorScheme: ColorScheme.dark(
        primary: _primaryColor,
        secondary: _accentColor, // 使用橙红色作为辅助色/强调色
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        background: _darkBgColor,
        surface: _surfaceColor,
        error: _accentColor, // 使用强调色作为错误色
        onBackground: _lightTextColor,
        onSurface: _lightTextColor,
        onError: Colors.white,
      ),

      // 2. 字体与排版 (保持不变)
      fontFamily: 'Montserrat',
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold, color: _lightTextColor),
        headlineSmall: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: _lightTextColor),
        bodyLarge: TextStyle(fontSize: 16.0, height: 1.5, color: _lightTextColor),
        bodyMedium: TextStyle(fontSize: 14.0, color: _lightTextColor.withOpacity(0.8), height: 1.5),
        labelLarge: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white),
      ),

      // 3. 组件主题
      // AppBar主题
      appBarTheme: AppBarTheme(
        backgroundColor: _surfaceColor, // 背景色与表面色一致
        elevation: 0, // 移除默认阴影
        scrolledUnderElevation: 0.8, // 滚动时出现一个细微的阴影
        shadowColor: Colors.black,
        iconTheme: IconThemeData(color: _primaryColor),
        titleTextStyle: TextStyle(
          color: _lightTextColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Montserrat',
        ),
      ),

      // 卡片主题
      cardTheme: CardThemeData(
        color: _surfaceColor, // 卡片背景色
        elevation: 2.0,
        shadowColor: Colors.black.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      ),

      // 底部导航栏主题
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _surfaceColor,
        selectedItemColor: _primaryColor, // 选中项使用主色调
        unselectedItemColor: _lightTextColor.withOpacity(0.6), // 未选中项使用浅灰色
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed, // 固定模式，适合4个标签
        elevation: 5.0,
      ),

      // 浮动操作按钮主题
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _accentColor, // FAB 使用亮眼的强调色
        foregroundColor: Colors.white,
      ),

      // 按钮主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0), // 更圆润的按钮
          ),
          elevation: 2,
        ),
      ),

      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceColor, // 使用表面色填充
        contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none, // 移除边框，更现代
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: _primaryColor, width: 2.0),
        ),
      ),

      // TabBar主题
      tabBarTheme: TabBarThemeData(
        dividerHeight: 0,
        indicatorSize: TabBarIndicatorSize.tab, // 指示器与标签同宽
        labelColor: _primaryColor, // 选中的标签颜色更突出
        unselectedLabelColor: _lightTextColor.withOpacity(0.6),
        labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
        indicatorAnimation: TabIndicatorAnimation.linear
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey[800],
        thickness: 1,
      )
    );
  }
}
