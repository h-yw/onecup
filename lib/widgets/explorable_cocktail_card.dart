// lib/widgets/explorable_cocktail_card.dart

import 'package:flutter/material.dart';
import 'package:onecup/models/receip.dart';

/// 一个专门用于“探索更多”页面的鸡尾酒卡片。
///
/// 它在标准鸡尾酒信息的基础上，额外突显了还缺少多少种配料。
class ExplorableCocktailCard extends StatelessWidget {
  final Recipe recipe;
  final int missingCount;
  final VoidCallback? onTap;

  const ExplorableCocktailCard({
    super.key,
    required this.recipe,
    required this.missingCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      // 卡片样式会由AppTheme自动控制
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0), // 匹配Card的圆角
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 上半部分：基本信息
              Text(
                recipe.name,
                style: theme.textTheme.headlineSmall?.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 6),
              Text(
                '${recipe.category ?? '经典鸡尾酒'} | 使用 ${recipe.glass ?? '鸡尾酒杯'}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              // 下半部分：高亮提示
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min, // 让Row的宽度包裹内容
                  children: [
                    Icon(Icons.explore_outlined, size: 16, color: Colors.blueGrey[700]),
                    const SizedBox(width: 8),
                    Text(
                      '缺少 $missingCount 种配料',
                      style: TextStyle(
                        color: Colors.blueGrey[800],
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}