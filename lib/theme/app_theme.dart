import 'package:flutter/material.dart';

/// [更新版] 应用程序的UI主题配置。
///
/// 根据用户反馈调整，旨在创建更明亮、更有活力的视觉体验，
/// 同时保持战略蓝图中“现代、精致、以插画为中心”的核心设计原则 。
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      // 1. 核心颜色与亮度
      // [调整] 整体保持浅色主题，但将主色调调整为更温暖、更有活力的琥珀色。
      brightness: Brightness.light,
      primaryColor: const Color(0xFFF59E0B), // [新] 明亮的琥珀/橙色，作为主色调，更有活力。
      scaffoldBackgroundColor: const Color(0xFFF9FAFB), // 使用非常浅的灰色，比纯白更柔和。
      colorScheme: const ColorScheme.light(
        primary: Color(0xFFF59E0B), // 主要交互元素，如按钮背景，现在是明亮的琥珀色。
        secondary: Color(0xFF003D5B), // [新角色] 深沉的蓝色现在作为辅助色，用于需要稳重感的地方。
        onPrimary: Colors.white, // 在琥珀色主色上方的文本/图标颜色。
        onSecondary: Colors.white,
        background: Color(0xFFF9FAFB),
        surface: Colors.white, // 卡片、对话框等组件的表面颜色。
        error: Color(0xFFD32F2F),
        onBackground: Color(0xFF1F2937), // [调整] 正文文本颜色，比之前稍柔和。
        onSurface: Color(0xFF1F2937),
        onError: Colors.white,
      ),

      // 2. 字体与排版
      // 保持“干净、易读的布局” 。字体设置不变。
      fontFamily: 'Montserrat', // 假设您已添加此字体
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
        headlineSmall: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
        bodyLarge: TextStyle(fontSize: 16.0, height: 1.5, color: Color(0xFF374151)),
        bodyMedium: TextStyle(fontSize: 14.0, color: Color(0xFF6B7280), height: 1.5),
        labelLarge: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white),
      ),

      // 3. 组件主题
      // [调整] 为组件增加细微的阴影和效果，以增加层次感，避免“平淡”。

      // AppBar主题
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white, // AppBar 使用纯白背景，与内容区域形成对比。
        elevation: 0.5, // [调整] 增加轻微的阴影，创造层次感。
        shadowColor: Color(0xFFE5E7EB),
        iconTheme: IconThemeData(color: Color(0xFF003D5B)), // 图标使用稳重的蓝色。
        titleTextStyle: TextStyle(
          color: Color(0xFF003D5B),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Montserrat',
        ),
      ),

      // 卡片主题
      cardTheme: CardThemeData(
        elevation: 2.0,
        shadowColor: const Color(0xFFE5E7EB), // 使用更柔和的阴影色。
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      ),

      // 按钮主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF59E0B), // 使用新的主色调。
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          elevation: 2, // [调整] 为按钮增加轻微阴影，使其更突出。
        ),
      ),

      // 输入框主题 (保持不变)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 2.0),
        ),
      ),

      // TabBar主题
      tabBarTheme: const TabBarThemeData(
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(width: 3.0, color: Color(0xFFF59E0B)), // 指示器使用新的主色调。
        ),
        labelColor: Color(0xFF003D5B), // 选中标签使用稳重的蓝色，形成对比。
        unselectedLabelColor: Color(0xFF6B7280),
        labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}