// lib/widgets/inventory_shelf_card.dart

import 'package:flutter/material.dart';

/// 一个用于在“我的库存”中展示单个配料类别的卡片。
///
/// 它将一个类别（如“烈酒”）和该类别下的配料列表，
/// 以一个带有标题和多个“瓶子”图标的“酒架”形式进行可视化呈现。
class InventoryShelfCard extends StatelessWidget {
  /// 酒架的标题，即配料类别名称。
  final String category;

  /// 该类别下所有配料的名称列表。
  final List<String> ingredients;

  /// 当用户点击某个配料的移除按钮时触发的回调。
  final Function(String) onRemove;

  const InventoryShelfCard({
    super.key,
    required this.category,
    required this.ingredients,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      // 使用 Card 是为了提供一个清晰的视觉分组
      elevation: 0,
      color: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[200]!, width: 1.0),
        borderRadius: BorderRadius.circular(12.0),
      ),
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 酒架标题
            Text(
              category,
              style: theme.textTheme.headlineSmall?.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 16),
            // 2. 陈列酒瓶的Wrap容器
            Wrap(
              spacing: 12.0, // 水平间距
              runSpacing: 12.0, // 垂直间距
              children: ingredients.map((name) {
                // 为每个配料创建一个可点击的“瓶子”小组件
                return _buildIngredientBottle(context, name);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建单个“酒瓶”的私有辅助方法。
  Widget _buildIngredientBottle(BuildContext context, String name) {
    final theme = Theme.of(context);
    return Chip(
      // 使用Chip组件可以快速实现我们想要的样式
      avatar: Icon(Icons.liquor_outlined, size: 18, color: theme.primaryColor),
      label: Text(
        name,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: theme.textTheme.bodyLarge?.color,
        ),
      ),
      onDeleted: () => onRemove(name), // 点击删除按钮时触发回调
      deleteIcon: Icon(Icons.close, size: 18),
      backgroundColor: theme.primaryColor.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
        side: BorderSide(color: theme.primaryColor.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
    );
  }
}