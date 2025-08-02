// lib/screens/my_favorites_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 1. 导入 riverpod
import 'package:onecup/models/receip.dart';
import 'package:onecup/providers/cocktail_providers.dart'; // 2. 导入 providers
import 'package:onecup/screens/recipe_detail_screen.dart';
import 'package:onecup/widgets/cocktail_card.dart';

// 3. 将 StatefulWidget 修改为 ConsumerWidget
class MyFavoritesScreen extends ConsumerWidget {
  const MyFavoritesScreen({super.key});

  // 导航逻辑现在是普通方法，不再需要 _loadFavorites
  void _navigateToDetail(BuildContext context, WidgetRef ref, Recipe recipe) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipe: recipe)),
    );
    // 如果详情页返回了 true (表示收藏状态有变)，则刷新 provider
    if (result == true && context.mounted) {
      ref.invalidate(favoriteRecipesProvider);
      ref.invalidate(favoritesCountProvider); // 同时刷新数量
    }
  }

  @override
  // 4. build 方法新增 WidgetRef 参数
  Widget build(BuildContext context, WidgetRef ref) {
    // 5. 使用 ref.watch 监听 provider
    final favoritesAsyncValue = ref.watch(favoriteRecipesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
      ),
      // 6. 使用 provider 的 when 方法来处理不同状态
      body: favoritesAsyncValue.when(
        data: (favorites) {
          if (favorites.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  '您还没有收藏任何鸡尾酒。\n去首页看看，点击♥️收藏您喜欢的吧！',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final recipe = favorites[index];
              return CocktailCard(
                recipe: recipe,
                onTap: () => _navigateToDetail(context, ref, recipe), // 传递 context 和 ref
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载收藏列表失败: $err')),
      ),
    );
  }
}