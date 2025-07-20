// lib/screens/my_notes_screen.dart

import 'package:flutter/material.dart';
import 'package:onecup/database/database_helper.dart';
import 'package:onecup/models/receip.dart';
import 'package:onecup/screens/recipe_detail_screen.dart';
import 'package:onecup/widgets/cocktail-card.dart';

class MyNotesScreen extends StatefulWidget {
  const MyNotesScreen({super.key});

  @override
  State<MyNotesScreen> createState() => _MyNotesScreenState();
}

class _MyNotesScreenState extends State<MyNotesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<Recipe>> _notesFuture;

  @override
  void initState() {
    super.initState();
    _loadRecipesWithNotes();
  }

  void _loadRecipesWithNotes() {
    setState(() {
      _notesFuture = _dbHelper.getRecipesWithNotes();
    });
  }

  void _navigateToDetail(Recipe recipe) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipe: recipe)),
    );
    // 从详情页返回后，刷新列表以同步可能发生的笔记变更
    if (mounted) {
      _loadRecipesWithNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的笔记'),
      ),
      body: FutureBuilder<List<Recipe>>(
        future: _notesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载笔记列表失败: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
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

          final recipesWithNotes = snapshot.data!;
          return ListView.builder(
            itemCount: recipesWithNotes.length,
            itemBuilder: (context, index) {
              final recipe = recipesWithNotes[index];
              return CocktailCard(
                recipe: recipe,
                onTap: () => _navigateToDetail(recipe),
              );
            },
          );
        },
      ),
    );
  }
}