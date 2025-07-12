import 'package:flutter/material.dart';
import 'package:onecup/models/receip.dart';
import 'package:onecup/database/database_helper.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({Key? key, required this.recipe}) : super(key: key);

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<Map<String, dynamic>>> _ingredientsFuture;
  late Future<List<String>> _tagsFuture;
  bool _isFavorited = false;

  @override
  void initState() {
    super.initState();
    _ingredientsFuture = _dbHelper.getIngredientsForRecipe(widget.recipe.id);
    _tagsFuture = _dbHelper.getRecipeTags(widget.recipe.id);
    _checkIfFavorited();
  }

  void _checkIfFavorited() async {
    final isFav = await _dbHelper.isRecipeFavorite(widget.recipe.id);
    if (mounted) {
      setState(() {
        _isFavorited = isFav;
      });
    }
  }

  void _toggleFavorite() async {
    if (_isFavorited) {
      await _dbHelper.removeRecipeFromFavorites(widget.recipe.id);
    } else {
      await _dbHelper.addRecipeToFavorites(widget.recipe.id);
    }
    setState(() {
      _isFavorited = !_isFavorited;
    });
  }

  // [新增] “一键加购”的实现
  void _addAllIngredientsToShoppingList() async {
    await _dbHelper.addRecipeIngredientsToShoppingList(widget.recipe.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('“${widget.recipe.name}”的全部配料已添加到购物清单！'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe.name),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorited ? Icons.favorite : Icons.favorite_border,
              color: _isFavorited ? Colors.redAccent : null,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ... 其他部分不变 ...
              Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_bar,
                  size: 100,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 24),
              if (widget.recipe.description != null && widget.recipe.description!.isNotEmpty) ...[
                Text('关于', style: textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(widget.recipe.description!, style: textTheme.bodyLarge),
                const SizedBox(height: 24),
              ],
              Text('配料', style: textTheme.headlineSmall),
              const SizedBox(height: 8),
              _buildIngredientsList(),
              const SizedBox(height: 24),
              Text('调制步骤', style: textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                widget.recipe.instructions ?? '暂无详细步骤。',
                style: textTheme.bodyLarge?.copyWith(height: 1.6),
              ),

              // [新增] 风味标签部分
              const SizedBox(height: 24),
              Text('风味标签', style: textTheme.headlineSmall),
              const SizedBox(height: 8),
              _buildTagsList(),
              const SizedBox(height: 80), // 为浮动按钮留出空间
            ],
          ),
        ),
      ),
      // [新增] 添加到购物清单的浮动按钮
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAllIngredientsToShoppingList,
        label: const Text('添加到购物清单'),
        icon: const Icon(Icons.add_shopping_cart),
      ),
    );
  }
  // 构建配料列表的辅助方法
  Widget _buildIngredientsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _ingredientsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Text('加载配料失败。');
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('暂无配料信息。');
        }

        final ingredients = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: ingredients.map((ing) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 8, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${ing['name']} - ${ing['amount']} ${ing['unit'] ?? ''}'.trim(),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
  // [新增] 构建风味标签列表的辅助方法
  Widget _buildTagsList() {
    return FutureBuilder<List<String>>(
      future: _tagsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 30, child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Text('暂无风味信息。', style: Theme.of(context).textTheme.bodyMedium);
        }

        final tags = snapshot.data!;
        return Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: tags.map((tag) => Chip(label: Text(tag))).toList(),
        );
      },
    );
  }
}