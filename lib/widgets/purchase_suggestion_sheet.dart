
// lib/widgets/purchase_suggestion_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onecup/common/show_top_banner.dart';
import 'package:onecup/models/purchase_recommendation.dart';
import 'package:onecup/providers/cocktail_providers.dart';

class PurchaseSuggestionSheet extends ConsumerWidget {
  // 1. Update the type to be type-safe
  final Future<List<PurchaseRecommendation>> recommendationsFuture;

  const PurchaseSuggestionSheet({super.key, required this.recommendationsFuture});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final double maxHeight = MediaQuery.of(context).size.height * 0.6;
    const double safeMaxHeight = 600.0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight < safeMaxHeight ? maxHeight : safeMaxHeight,
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Expanded(
            // 2. Update the FutureBuilder's generic type
            child: FutureBuilder<List<PurchaseRecommendation>>(
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

                return ListView.separated(
                  itemCount: recommendations.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    // 3. Access data via properties, not string keys
                    final recommendation = recommendations[index];
                    final String name = recommendation.ingredientName;
                    final int unlocks = recommendation.unlockableRecipesCount;

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
                          final cocktailRepo = ref.read(cocktailRepositoryProvider);
                          cocktailRepo.addIngredientToShoppingList(recommendation.ingredientId, name);
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
