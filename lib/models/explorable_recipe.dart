
// lib/models/explorable_recipe.dart

import 'package:onecup/models/receip.dart';

/// Represents a recipe in the "Explore More" section.
///
/// This class bundles a [Recipe] object with the count of missing ingredients,
/// providing a type-safe structure for data returned from the
/// `get_explorable_recipes` database function.
class ExplorableRecipe {
  final Recipe recipe;
  final int missingCount;

  ExplorableRecipe({
    required this.recipe,
    required this.missingCount,
  });

  /// Creates an [ExplorableRecipe] instance from a JSON map.
  ///
  /// The map is expected to be the raw response from the Supabase RPC.
  factory ExplorableRecipe.fromJson(Map<String, dynamic> json) {
    return ExplorableRecipe(
      // The recipe data is nested under the same keys as a normal recipe
      recipe: Recipe.fromMap(json),
      // The missing_count is a top-level key in the RPC response
      missingCount: json['missing_count'] as int? ?? 0,
    );
  }
}
