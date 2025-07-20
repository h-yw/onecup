// lib/models/recipe_ingredient.dart

class RecipeIngredient {
  final String name;
  final double quantity;
  final String? unit;

  // [修复 1] 确保 isOptional 是一个不可空的布-尔类型 (bool)
  // 并为其提供一个默认值 false。
  final bool isOptional;

  RecipeIngredient({
    required this.name,
    required this.quantity,
    this.unit,
    // [修复 2] 在构造函数中将 isOptional 设为可选参数，并赋予默认值
    this.isOptional = false,
  });

  // toMap 方法现在可以安全地访问 isOptional
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'is_optional': isOptional,
    };
  }

  // fromMap 构造函数 (如果存在的话)
  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      name: map['name'],
      quantity: map['quantity'],
      unit: map['unit'],
      // 从 map 中读取时，如果不存在则默认为 false
      isOptional: map['is_optional'] ?? false,
    );
  }
}