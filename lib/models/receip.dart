class Recipe {
  final int id; // ID在创建时可以不提供
  final String name;
  final String? description;
  final String? instructions;
  final String? imagePath;
  final String? category;
  final String? glass;
  final int? userId; // [新增] 关联的用户ID

  Recipe({
    required this.id,
    required this.name,
    this.description,
    this.instructions,
    this.imagePath,
    this.category,
    this.glass,
    this.userId, // [新增]
  });

  // 从Map构建Recipe对象
  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['recipe_id'],
      name: map['name'],
      description: map['description'],
      instructions: map['instructions'],
      imagePath: map['image_path'],
      category: map['category'],
      glass: map['glass'],
      userId: map['user_id'], // [新增]
    );
  }
}