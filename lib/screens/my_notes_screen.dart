// lib/screens/my_notes_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onecup/models/receip.dart';
import 'package:onecup/providers/cocktail_providers.dart';
import 'package:onecup/screens/recipe_detail_screen.dart';
import 'package:onecup/widgets/cocktail_card.dart';

// 3. 修改为 ConsumerWidget
class MyNotesScreen extends ConsumerWidget {
  const MyNotesScreen({super.key});

  void _navigateToDetail(BuildContext context, WidgetRef ref, Recipe recipe) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipe: recipe)),
    );
    // 从详情页返回后，刷新列表以同步可能发生的笔记变更
    ref.invalidate(recipesWithNotesProvider);
    ref.invalidate(notesCountProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsyncValue = ref.watch(recipesWithNotesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的笔记'),
      ),
      body: notesAsyncValue.when(
        data: (recipesWithNotes) {
          if (recipesWithNotes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  '您还没有为任何配方添加笔记。\n在配方详情页找到并添加您的第一条笔记吧！',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: recipesWithNotes.length,
            itemBuilder: (context, index) {
              final recipe = recipesWithNotes[index];
              return CocktailCard(
                recipe: recipe,
                onTap: () => _navigateToDetail(context, ref, recipe),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载笔记列表失败: $err')),
      ),
    );
  }
}
