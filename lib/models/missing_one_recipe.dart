
// lib/models/missing_one_recipe.dart

import 'package:onecup/models/receip.dart';

/// Represents a recipe that is missing exactly one ingredient.
///
/// This class provides a type-safe structure for the data returned from the
/// `get_missing_one_recipes` database function.
class MissingOneRecipe {
  final Recipe recipe;
  final String missingIngredientName;

  MissingOneRecipe({
    required this.recipe,
    required this.missingIngredientName,
  });

  /// Creates a [MissingOneRecipe] instance from a JSON map.
  factory MissingOneRecipe.fromJson(Map<String, dynamic> json) {
    return MissingOneRecipe(
      // The recipe data is nested under the same keys as a normal recipe
      recipe: Recipe.fromMap(json),
      // The missing ingredient name is a top-level key
      missingIngredientName: json['missing_ingredient_name'] as String? ?? '未知配料',
    );
  }
}
