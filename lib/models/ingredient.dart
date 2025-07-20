// lib/models/ingredient.dart

class Ingredient {
  final int? id;
  final String name;
  final String category;
  final double? abv; // [核心升级] 新增酒精度(ABV)字段

  Ingredient({
    this.id,
    required this.name,
    required this.category,
    this.abv, // [核心升级]
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'abv': abv, // [核心升级]
    };
  }

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      abv: map['abv'], // [核心升级]
    );
  }
}