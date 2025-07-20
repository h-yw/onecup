// lib/screens/my_favorites_screen.dart

import 'package:flutter/material.dart';
import 'package:onecup/database/database_helper.dart';
import 'package:onecup/database/supabase_service.dart';
import 'package:onecup/models/receip.dart';
import 'package:onecup/screens/recipe_detail_screen.dart';
import 'package:onecup/widgets/cocktail-card.dart';

class MyFavoritesScreen extends StatefulWidget {
  const MyFavoritesScreen({super.key});

  @override
  State<MyFavoritesScreen> createState() => _MyFavoritesScreenState();
}

class _MyFavoritesScreenState extends State<MyFavoritesScreen> {
  final SupabaseService _dbHelper = SupabaseService();
  late Future<List<Recipe>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  void _loadFavorites() {
    setState(() {
      _favoritesFuture = _dbHelper.getFavoriteRecipes();
    });
  }

  void _navigateToDetail(Recipe recipe) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipe: recipe)),
    );
    if (mounted) {
      _loadFavorites();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
      ),
      body: FutureBuilder<List<Recipe>>(
        future: _favoritesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载收藏列表失败: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
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

          final favorites = snapshot.data!;
          return ListView.builder(
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final recipe = favorites[index];
              return CocktailCard(
                recipe: recipe,
                onTap: () => _navigateToDetail(recipe),
              );
            },
          );
        },
      ),
      // [核心升级] 移除此处的 FloatingActionButton
    );
  }
}