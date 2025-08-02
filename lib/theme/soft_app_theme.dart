// lib/theme/soft_app_theme.dart

import 'package:flutter/material.dart';

/// 应用程序的柔和UI主题配置。
///
/// 采用柔和的绿色作为主色调，搭配活泼的橙红色作为强调色，
/// 营造出温馨、舒适且现代的视觉体验。
class SoftAppTheme {
  // 定义核心颜色以便复用
  static const Color _primaryColor = Color(0xFF87A644); // 柔和的绿色
  static const Color _accentColor = Color(0xFFE15321);  // 活泼的橙红色
  static const Color _darkTextColor = Color(0xFF413C35); // 深棕灰色，用于标题
  static const Color _bodyTextColor = Color(0xFF5A524A); // 柔和的深灰色，用于正文
  static const Color _lightBgColor = Color(0xFFCAD996); // 极浅的绿黄色背景
  static const Color _darkBgColor = Color(0xFF000000); // 纯黑色，用于深色模式的背景

  static ThemeData get lightTheme {
    return ThemeData(
      // 1. 核心颜色与亮度
      brightness: Brightness.light,
      primaryColor: _primaryColor,
      scaffoldBackgroundColor: _lightBgColor,
      colorScheme: const ColorScheme.light(
        primary: _primaryColor,
        secondary: _accentColor, // 使用亮珊瑚色作为辅助色/强调色
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        background: _lightBgColor,
        surface: Colors.white,
        error: Color(0xFFD32F2F),
        onBackground: _bodyTextColor,
        onSurface: _darkTextColor,
        onError: Colors.white,
      ),

      // 2. 字体与排版 (保持不变)
      fontFamily: 'Montserrat',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold, color: _darkTextColor),
        headlineSmall: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: _darkTextColor),
        bodyLarge: TextStyle(fontSize: 16.0, height: 1.5, color: _bodyTextColor),
        bodyMedium: TextStyle(fontSize: 14.0, color: Color(0xFF6B7280), height: 1.5),
        labelLarge: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white),
      ),

      // 3. 组件主题
      // AppBar主题
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightBgColor, // [优化] 背景色与Scaffold一致
        elevation: 0, // [优化] 移除默认阴影
        scrolledUnderElevation: 0.8, // [优化] 滚动时出现一个细微的阴影
        shadowColor: Color(0xFFE5E7EB),
        iconTheme: IconThemeData(color: _primaryColor),
        titleTextStyle: TextStyle(
          color: _darkTextColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Montserrat',
        ),
      ),

      // 卡片主题
      cardTheme: CardThemeData(
        elevation: 2.0,
        shadowColor: const Color(0xFFE5E7EB).withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        // [UI 优化] 减小卡片的垂直外边距，让列表项更紧凑
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      ),

      // 底部导航栏主题
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: _primaryColor, // 选中项使用主色调
        unselectedItemColor: Color(0xFF6B7280), // 未选中项使用灰色
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
        fillColor: const Color(0xFFF3F4F6), // 使用浅灰色填充，而非纯白
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
          borderSide: const BorderSide(color: _primaryColor, width: 2.0),
        ),
      ),

      // TabBar主题
      tabBarTheme: TabBarThemeData(
        // [核心改造] 使用新的指示器样式
        // indicator: BoxDecoration(
        //   color: _primaryColor.withOpacity(0.1), // 使用一个柔和的背景色
        //   borderRadius: BorderRadius.circular(12), // 圆角
        // ),
        dividerHeight: 0,
        indicatorSize: TabBarIndicatorSize.tab, // 指示器与标签同宽
        labelColor: _primaryColor, // 选中的标签颜色更突出
        unselectedLabelColor: _bodyTextColor,
        labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
        indicatorAnimation: TabIndicatorAnimation.linear
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey[200],
        thickness: 1,
        // space: 12
      )
    );
  }
}
