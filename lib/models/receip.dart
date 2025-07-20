// lib/models/recipe.dart

import 'package:flutter/foundation.dart';

/// Recipe 模型类，用于表示一个鸡尾酒配方。
class Recipe {
  final int id;
  final String name;
  final String? description;
  final String? instructions;
  final String? imageUrl;
  final String? category;
  final String? glass;
  final List<String>? notes;
  final String? videoUrl;
  final String? userId;

  Recipe({
    required this.id,
    required this.name,
    this.description,
    this.instructions,
    this.imageUrl,
    this.category,
    this.glass,
    this.notes,
    this.videoUrl,
    this.userId,
  });

  /// [已优化] 构造函数：用于解析来自Supabase标准查询的嵌套数据。
  /// 这个方法现在主要作为备用，新的查询优先使用fromMap。
  factory Recipe.fromSupabaseMap(Map<String, dynamic> map, {Map<String, dynamic>? relations}) {
    String? glassName = '未知杯具';
    if (relations?['glassware'] != null) {
      glassName = relations!['glassware']['name'];
    }

    return Recipe(
      id: map['id'],
      name: map['name'] ?? '无标题',
      description: map['description'],
      instructions: map['instructions'],
      imageUrl: map['image'],
      category: relations?['category']?['name'] ?? '未分类',
      glass: glassName,
      notes: map['notes'] != null ? List<String>.from(map['notes']) : null,
      videoUrl: map['video_url'],
      userId: map['user_id'],
    );
  }

  /// [已优化] 构造函数：用于解析扁平化的 Map 数据。
  ///
  /// 适用于数据库函数 (RPC) 或我们新创建的视图 (v_recipes_with_details) 的返回结果。
  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'] ?? map['recipe_id'] ?? 0,
      name: map['name'] ?? '无标题',
      description: map['description'],
      instructions: map['instructions'],
      imageUrl: map['image'] ?? map['image_path'],
      // [核心修正] 读取来自视图的别名 (aliased) 字段
      category: map['category_name'] ?? map['category'],
      glass: map['glass_name'] ?? map['glass'],
      notes: map['notes'] != null ? List<String>.from(map['notes']) : null,
      videoUrl: map['video_url'],
      userId: map['user_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'instructions': instructions,
      'image': imageUrl,
      'notes': notes,
      'video_url': videoUrl,
      'user_id': userId,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Recipe && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Recipe{id: $id, name: $name, category: $category}';
  }
}