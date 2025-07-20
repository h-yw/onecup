// lib/models/recipe_ingredient.dart

class RecipeIngredient {
  final String name;
  final double quantity;
  final String unit;

  RecipeIngredient({required this.name, required this.quantity, required this.unit});

  // [新方法] 添加 toMap 方法用于序列化
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
    };
  }
}