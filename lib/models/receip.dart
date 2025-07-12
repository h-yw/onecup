class Recipe {
  final int id;
  final String name;
  final String? description;
  final String? instructions;
  final String? imagePath;
  final String? category;
  final String? glass;

  Recipe({
    required this.id,
    required this.name,
    this.description,
    this.instructions,
    this.imagePath,
    this.category,
    this.glass,
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
    );
  }
}