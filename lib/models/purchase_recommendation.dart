
// lib/models/purchase_recommendation.dart

/// Represents a single purchase recommendation item.
///
/// This class provides a type-safe way to handle the data returned from the
/// `get_purchase_recommendations` database function, preventing common errors
/// associated with using dynamic maps.
class PurchaseRecommendation {
  final int ingredientId;
  final String ingredientName;
  final int unlockableRecipesCount;

  PurchaseRecommendation({
    required this.ingredientId,
    required this.ingredientName,
    required this.unlockableRecipesCount,
  });

  /// Creates a [PurchaseRecommendation] instance from a JSON map.
  ///
  /// This factory constructor is crucial for parsing the response from Supabase
  /// and converting it into a type-safe Dart object.
  factory PurchaseRecommendation.fromJson(Map<String, dynamic> json) {
    return PurchaseRecommendation(
      ingredientId: json['ingredient_id'] as int? ?? 0,
      ingredientName: json['ingredient_name'] as String? ?? '未知配料',
      unlockableRecipesCount: json['unlockable_recipes_count'] as int? ?? 0,
    );
  }
}
