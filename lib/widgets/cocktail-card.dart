import 'package:flutter/material.dart';
import 'package:onecup/models/receip.dart';
class CocktailCard extends StatelessWidget {
  final Recipe recipe;

  const CocktailCard({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        // 虽然JSON中没有图片，但我们为图片预留了位置，这符合蓝图的设计 [cite: 156]
        leading: CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey[300],
          // 在实际项目中，这里会是一个Image.asset(recipe.imagePath)
          child: const Icon(Icons.local_bar, color: Colors.grey),
        ),
        title: Text(
          recipe.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            '${recipe.category ?? '经典鸡尾酒'} | 使用 ${recipe.glass ?? '鸡尾酒杯'}',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          // TODO: 导航到配方详情页
          // Navigator.push(context, MaterialPageRoute(builder: (context) => RecipeDetailPage(recipe: recipe)));
        },
      ),
    );
  }
}