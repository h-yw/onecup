// lib/common/show_top_banner.dart

import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

/// 显示一个从顶部滑出的、与App主题深度融合的浮层通知。
///
/// 使用`toastification`包来实现，它不会推开页面内容。
///
/// [context] - 当前的构建上下文。
/// [message] - 要显示的消息文本。
/// [isError] - 是否为错误消息。true会显示错误样式，false会显示成功/信息样式。
void showTopBanner(BuildContext context, String message, {bool isError = false}) {
  final theme = Theme.of(context);

  // 根据是否为错误，选择对应的颜色和图标
  final Color primaryColor = isError ? theme.colorScheme.error : theme.primaryColor;
  final IconData iconData = isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;

  toastification.show(
    context: context,
    // [核心改造] 我们不再使用预设类型，而是完全自定义样式
    style: ToastificationStyle.flat, // 使用一个更简洁的扁平样式作为基础

    // -- 内容 --
    title: Text(
      message,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 15,
        color: theme.textTheme.bodyLarge?.color, // 使用主题定义的正文颜色
      ),
    ),

    // -- 外观和行为 --
    alignment: Alignment.topCenter,
    autoCloseDuration: const Duration(seconds: 3), // 持续3秒

    // [核心改造] 定制一个全新的卡片外观
    backgroundColor: theme.cardColor, // 使用主题定义的卡片颜色
    borderRadius: BorderRadius.circular(12.0),
    // borderSide: Border.all(color: Colors.grey.withOpacity(0.1)), // 一个非常细微的边框
    boxShadow: const [
      BoxShadow(
        color: Color(0x0D000000), // 一个更柔和的阴影
        blurRadius: 12,
        offset: Offset(0, 4),
        spreadRadius: 0,
      )
    ],

    // [核心改造] 定制左侧的图标和装饰
    icon: Icon(iconData, color: primaryColor),
    primaryColor: primaryColor, // 左侧竖线的颜色

    // -- 其他细节 --
    showProgressBar: false, // 移除进度条，让设计更干净
    dragToClose: true,
    pauseOnHover: true,
    showIcon: false
  );
}