// lib/screens/my_creations_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 1. 导入
import 'package:onecup/models/receip.dart';
import 'package:onecup/providers/cocktail_providers.dart'; // 2. 导入
import 'package:onecup/screens/create_recipe_screen.dart';
import 'package:onecup/screens/recipe_detail_screen.dart';
import 'package:onecup/widgets/cocktail_card.dart';

// 3. 修改为 ConsumerWidget
class MyCreationsScreen extends ConsumerWidget {
  const MyCreationsScreen({super.key});

  void _navigateToDetail(BuildContext context, WidgetRef ref, Recipe recipe) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipe: recipe)),
    );
    // 从详情页返回后，刷新列表以同步任何可能的更改
    ref.invalidate(userCreatedRecipesProvider);
    ref.invalidate(creationsCountProvider);
  }

  void _navigateToCreateRecipe(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const CreateRecipeScreen()),
    );
    if (result == true) {
      ref.invalidate(userCreatedRecipesProvider);
      ref.invalidate(creationsCountProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creationsAsyncValue = ref.watch(userCreatedRecipesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的创作'),
      ),
      body: creationsAsyncValue.when(
        data: (creations) {
          if (creations.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  '你还没有创作任何配方。\n点击右下角的“+”按钮，开始你的第一杯创作吧！',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: creations.length,
            itemBuilder: (context, index) {
              final recipe = creations[index];
              return CocktailCard(
                recipe: recipe,
                onTap: () => _navigateToDetail(context, ref, recipe),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToCreateRecipe(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('创建新配方'),
      ),
    );
  }
}
