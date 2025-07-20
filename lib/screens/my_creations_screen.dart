// lib/screens/my_creations_screen.dart

import 'package:flutter/material.dart';
import 'package:onecup/database/database_helper.dart';
import 'package:onecup/models/receip.dart';
import 'package:onecup/screens/create_recipe_screen.dart';
import 'package:onecup/screens/recipe_detail_screen.dart';
import 'package:onecup/widgets/cocktail-card.dart';

class MyCreationsScreen extends StatefulWidget {
  const MyCreationsScreen({super.key});

  @override
  State<MyCreationsScreen> createState() => _MyCreationsScreenState();
}

class _MyCreationsScreenState extends State<MyCreationsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<Recipe>> _creationsFuture;

  @override
  void initState() {
    super.initState();
    _loadCreations();
  }

  void _loadCreations() {
    setState(() {
      _creationsFuture = _dbHelper.getUserCreatedRecipes();
    });
  }

  void _navigateToDetail(Recipe recipe) async {
    // 用户创建的配方也可以查看详情
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipe: recipe)),
    );
    if (mounted) {
      _loadCreations();
    }
  }

  void _navigateToCreateRecipe() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const CreateRecipeScreen()),
    );
    // 如果创建成功，则刷新列表
    if (result == true && mounted) {
      _loadCreations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的创作'),
      ),
      body: FutureBuilder<List<Recipe>>(
        future: _creationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
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

          final creations = snapshot.data!;
          return ListView.builder(
            itemCount: creations.length,
            itemBuilder: (context, index) {
              final recipe = creations[index];
              return CocktailCard(
                recipe: recipe,
                onTap: () => _navigateToDetail(recipe),
              );
            },
          );
        },
      ),
      // 将创建按钮（FAB）放在这里
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateRecipe,
        icon: const Icon(Icons.add),
        label: const Text('创建新配方'),
      ),
    );
  }
}