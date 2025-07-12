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
  Future<List<Map<String, dynamic>>>? _ingredientsFuture;

  @override
  void initState() {
    super.initState();
    _ingredientsFuture = _dbHelper.getIngredientsForRecipe(widget.recipe.id);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe.name),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 鸡尾酒图片/插画区域 (符合蓝图设计)
              Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  // 在这里可以添加图片
                  // image: DecorationImage(
                  //   image: AssetImage('path_to_image'),
                  //   fit: BoxFit.cover,
                  // ),
                ),
                child: Icon(
                  Icons.local_bar,
                  size: 100,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 24),

              // 2. 配方描述或故事
              if (widget.recipe.description != null && widget.recipe.description!.isNotEmpty) ...[
                Text('关于', style: textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(widget.recipe.description!, style: textTheme.bodyLarge),
                const SizedBox(height: 24),
              ],

              // 3. 所需配料列表
              Text('配料', style: textTheme.headlineSmall),
              const SizedBox(height: 8),
              _buildIngredientsList(),
              const SizedBox(height: 24),

              // 4. 调制步骤
              Text('调制步骤', style: textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                widget.recipe.instructions ?? '暂无详细步骤。',
                style: textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
            ],
          ),
        ),
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
}