import 'package:flutter/material.dart';
import 'package:onecup/models/receip.dart';
import 'package:onecup/screens/recipe_detail_screen.dart'; // 导入详情页

class CocktailCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap; // [更新] 将导航逻辑改为一个回调函数

  const CocktailCard({super.key, required this.recipe,  this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      // Card的样式现在会由AppTheme自动控制
      // margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      // elevation: 4,
      // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        leading: CircleAvatar(
          radius: 30,
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Icon(Icons.local_bar, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(
          recipe.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 18),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            '${recipe.category ?? '经典鸡尾酒'} | 使用 ${recipe.glass ?? '鸡尾酒杯'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap, // [更新] 使用传入的onTap回调

      ),
    );
  }
}