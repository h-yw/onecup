// File: lib/models/ingredient.dart
class Ingredient {
  final int? id;
  final String name;
  final String category;

  Ingredient({this.id, required this.name, required this.category});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
    };
  }

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      id: map['id'],
      name: map['name'],
      category: map['category'],
    );
  }
}

