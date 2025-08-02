// lib/repositories/cocktail_repository.dart

import 'package:onecup/models/explorable_recipe.dart';
import 'package:onecup/models/missing_one_recipe.dart';
import 'package:onecup/models/purchase_recommendation.dart';
import 'package:onecup/models/receip.dart';
import 'package:onecup/models/recipe_ingredient.dart';

/// Abstract interface for a cocktail data source.
///
/// This defines the contract that any data provider (like Supabase, a mock service,
/// or a local database) must adhere to. The UI will depend on this abstraction,

abstract class CocktailRepository {
  // --- Recipe Lists ---
  Future<List<Recipe>> getAllRecipes();
  Future<List<Recipe>> getFavoriteRecipes();
  Future<List<Recipe>> getUserCreatedRecipes();
  Future<List<Recipe>> getRecipesWithNotes();
  Future<List<Recipe>> getMakeableRecipes();
  Future<List<MissingOneRecipe>> getMissingOneRecipes();
  Future<List<ExplorableRecipe>> getExplorableRecipes();
  Future<List<Recipe>> getFlavorBasedRecommendations();
  Future<Recipe?> getRecipeById(int recipeId); // Added for deep linking

  // --- Recipe Details & Actions ---
  Future<List<Map<String, dynamic>>> getIngredientsForRecipe(int recipeId);
  Future<List<String>> getRecipeTags(int recipeId);
  Future<double?> getRecipeABV(int recipeId);
  Future<void> addRecipeToFavorites(int recipeId);
  Future<void> removeRecipeFromFavorites(int recipeId);
  Future<bool> isRecipeFavorite(int recipeId);
  Future<String?> getRecipeNote(int recipeId);
  Future<void> saveRecipeNote(int recipeId, String notesJson);
  Future<void> deleteRecipeNote(int recipeId);
  Future<void> addRecipeIngredientsToShoppingList(int recipeId);
  Future<int?> addCustomRecipe(Recipe recipe, List<RecipeIngredient> ingredients);
  Future<List<String>> getAllGlasswareNames();


  // --- User Stats ---
  Future<int> getFavoritesCount();
  Future<int> getCreationsCount();
  Future<int> getNotesCount();

  // --- Inventory & Shopping ---
  Future<Map<String, List<String>>> getInventoryByCategory();
  Future<List<PurchaseRecommendation>> getPurchaseRecommendations();
  Future<int?> getIngredientIdByName(String name);
  Future<void> removeIngredientFromInventory(int ingredientId);
  Future<void> addIngredientToShoppingList(int ingredientId, String ingredientName);
  Future<void> addIngredientToInventory(int ingredientId); // Added for AddIngredientScreen
  Future<List<Map<String, dynamic>>> getIngredientsForBarManagement(); // Added for AddIngredientScreen
  Future<List<Map<String, dynamic>>> getShoppingList(); // Added for ShoppingListScreen
  Future<void> addToShoppingList(String name, int ingredientId); // Added for ShoppingListScreen
  Future<void> updateShoppingListItem(int id, bool isChecked); // Added for ShoppingListScreen
  Future<void> removeFromShoppingList(int id); // Added for ShoppingListScreen
  Future<void> clearCompletedShoppingItems(); // Added for ShoppingListScreen
}
