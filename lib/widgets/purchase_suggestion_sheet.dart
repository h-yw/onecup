// lib/widgets/purchase_suggestion_sheet.dart

import 'package:flutter/material.dart';
import 'package:onecup/common/show_top_banner.dart';
import 'package:onecup/database/database_helper.dart';

class PurchaseSuggestionSheet extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> recommendationsFuture;

  const PurchaseSuggestionSheet({super.key, required this.recommendationsFuture});

  DatabaseHelper get _dbHelper => DatabaseHelper();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // [核心修复] 使用一个固定的、安全的最大高度，确保面板不会过高。
    // 我们取屏幕高度的60%和600像素中的较小值。
    final double maxHeight = MediaQuery.of(context).size.height * 0.6;
    const double safeMaxHeight = 600.0;

    return Container(
      // [核心修复] 给整个面板设置一个最大高度约束
      constraints: BoxConstraints(
        maxHeight: maxHeight < safeMaxHeight ? maxHeight : safeMaxHeight,
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min, // 依然让Column包裹内容
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题部分 (保持不变)
          Row(
            children: [
              Icon(Icons.auto_awesome, color: theme.primaryColor),
              const SizedBox(width: 8),
              Text(
                '最佳购买建议',
                style: theme.textTheme.headlineSmall,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4.0, bottom: 16.0),
            child: Text(
              '根据您的库存，购买以下配料能最高效地解锁新配方。',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          // [核心修复] 将 FutureBuilder 包裹在 Expanded 中，让列表占用剩余空间并滚动
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: recommendationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ));
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
                          SizedBox(height: 16),
                          Text('恭喜，您的酒柜已非常全面！', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  );
                }
                final recommendations = snapshot.data!;

                // ListView 不再需要 shrinkWrap 和 physics，因为它现在有了确定的高度
                return ListView.separated(
                  itemCount: recommendations.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = recommendations[index];
                    final String name = item['name'];
                    final int unlocks = item['unlocks'];

                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: theme.primaryColor.withOpacity(index == 0 ? 1.0 : 0.2),
                        foregroundColor: index == 0 ? Colors.white : theme.primaryColor,
                        child: Text('#${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      title: Text('购买 $name', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      subtitle: Row(
                        children: [
                          Icon(Icons.key, size: 16, color: Colors.amber[800]),
                          const SizedBox(width: 4),
                          Text(
                            '解锁 $unlocks 款新配方',
                            style: TextStyle(
                              color: Colors.amber[900],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_shopping_cart_outlined),
                        color: theme.primaryColor,
                        tooltip: '加入购物清单',
                        onPressed: () {
                          _dbHelper.addToShoppingList(name);
                          showTopBanner(context, '“$name”已添加到购物清单！');
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}