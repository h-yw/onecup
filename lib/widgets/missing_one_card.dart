// lib/widgets/missing_one_card.dart

import 'package:flutter/material.dart';
import 'package:onecup/models/receip.dart';

class MissingOneCard extends StatelessWidget {
  final Recipe recipe;
  final String missingIngredient;
  final VoidCallback onAddToList;
  final VoidCallback onTap;

  const MissingOneCard({
    Key? key,
    required this.recipe,
    required this.missingIngredient,
    required this.onAddToList,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      // [UI优化] Card的样式现在会由AppTheme自动控制
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0), // 匹配Card的圆角
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              // 左侧信息区
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: theme.textTheme.headlineSmall?.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 8),
                    // [UI优化] 重新设计的“缺少项”提示
                    Row(
                      children: [
                        Icon(Icons.vpn_key_outlined, size: 16, color: Colors.amber[800]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '只差：$missingIngredient',
                            style: TextStyle(
                              color: Colors.amber[900],
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // [核心改造] 右侧轻量化按钮
              // 使用一个更轻的 IconButton 来替代笨重的 ElevatedButton
              IconButton(
                onPressed: onAddToList,
                icon: const Icon(Icons.add_shopping_cart_outlined),
                tooltip: '加入购物清单',
                style: IconButton.styleFrom(
                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                    foregroundColor: theme.primaryColor,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    )
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}