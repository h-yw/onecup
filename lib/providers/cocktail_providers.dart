
// lib/providers/cocktail_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onecup/models/explorable_recipe.dart';
import 'package:onecup/models/missing_one_recipe.dart';
import 'package:onecup/models/receip.dart';
import 'package:onecup/repositories/cocktail_repository.dart';
import 'package:onecup/repositories/supabase_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for the CocktailRepository interface.
///
/// This is the single source of truth for cocktail-related data fetching.
/// By depending on the abstraction ([CocktailRepository]), our UI and business logic
/// are decoupled from the concrete implementation (Supabase).
/// If we ever wanted to switch to a different backend, we would only need to
/// change this one provider.
final cocktailRepositoryProvider = Provider<CocktailRepository>((ref) {
  // It returns the Supabase implementation.
  return SupabaseRepository(Supabase.instance.client);
});

/// FutureProvider for fetching all recipes.
final allRecipesProvider = FutureProvider<List<Recipe>>((ref) {
  final cocktailRepository = ref.watch(cocktailRepositoryProvider);
  return cocktailRepository.getAllRecipes();
});

/// FutureProvider for fetching the list of makeable recipes.
final makeableRecipesProvider = FutureProvider<List<Recipe>>((ref) {
  // Depends on the repository abstraction, not the concrete implementation.
  final cocktailRepository = ref.watch(cocktailRepositoryProvider);
  return cocktailRepository.getMakeableRecipes();
});

/// FutureProvider for fetching recipes that are missing just one ingredient.
final missingOneRecipesProvider = FutureProvider<List<MissingOneRecipe>>((ref) {
  final cocktailRepository = ref.watch(cocktailRepositoryProvider);
  return cocktailRepository.getMissingOneRecipes();
});

/// StateNotifier for managing the user's inventory with optimistic updates.
///
/// It holds an [AsyncValue] to represent loading/data/error states,
/// similar to a FutureProvider, but allows for direct state manipulation.
class InventoryNotifier extends StateNotifier<AsyncValue<Map<String, List<String>>>> {
  final CocktailRepository _repository;

  InventoryNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadInventory();
  }

  /// Fetches the initial inventory from the repository.
  Future<void> loadInventory() async {
    state = const AsyncValue.loading();
    try {
      final inventory = await _repository.getInventoryByCategory();
      state = AsyncValue.data(inventory);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  /// Removes an ingredient from the inventory with an optimistic update.
  ///
  /// The UI is updated instantly, and the change is then sent to the server.
  /// If the server call fails, the UI state is rolled back.
  Future<void> removeIngredientOptimistically(String ingredientName) async {
    // Ensure we have data to work with.
    final previousState = state;
    if (previousState is! AsyncData<Map<String, List<String>>>) {
      // Cannot perform removal if there's no data or an error.
      return;
    }

    final originalInventory = Map<String, List<String>>.from(
      previousState.value.map((key, value) => MapEntry(key, List<String>.from(value))),
    );

    // 1. Optimistic UI Update: Immediately remove the ingredient from the local state.
    final newInventory = Map<String, List<String>>.from(originalInventory);
    String? categoryToRemoveFrom;

    for (final entry in newInventory.entries) {
      if (entry.value.contains(ingredientName)) {
        entry.value.remove(ingredientName);
        if (entry.value.isEmpty) {
          categoryToRemoveFrom = entry.key;
        }
        break;
      }
    }

    if (categoryToRemoveFrom != null) {
      newInventory.remove(categoryToRemoveFrom);
    }

    state = AsyncValue.data(newInventory);

    // 2. Attempt to sync with the backend.
    try {
      final ingredientId = await _repository.getIngredientIdByName(ingredientName);
      if (ingredientId == null) {
        throw Exception('Ingredient not found on server.');
      }
      await _repository.removeIngredientFromInventory(ingredientId);
    } catch (e) {
      // 3. Rollback on failure: If the API call fails, revert to the original state.
      state = AsyncValue.data(originalInventory);
      // Rethrow the error so the UI layer can catch it and notify the user.
      rethrow;
    }
  }
}

/// StateNotifierProvider for the user's inventory.
///
/// This replaces the old FutureProvider to allow for state mutations (like optimistic deletes).
final inventoryNotifierProvider = StateNotifierProvider<InventoryNotifier, AsyncValue<Map<String, List<String>>>>((ref) {
  final repository = ref.watch(cocktailRepositoryProvider);
  return InventoryNotifier(repository);
});


/// FutureProvider for fetching the user's inventory, categorized.
@deprecated
final inventoryProvider = FutureProvider<Map<String, List<String>>>((ref) {
  final cocktailRepository = ref.watch(cocktailRepositoryProvider);
  return cocktailRepository.getInventoryByCategory();
});


/// FutureProvider for fetching recipes to explore (missing 2 or more ingredients).
final explorableRecipesProvider = FutureProvider<List<ExplorableRecipe>>((ref) {
  final cocktailRepository = ref.watch(cocktailRepositoryProvider);
  return cocktailRepository.getExplorableRecipes();
});

/// FutureProvider for fetching flavor-based recipe recommendations.
final flavorBasedRecommendationsProvider = FutureProvider<List<Recipe>>((ref) {
  final cocktailRepository = ref.watch(cocktailRepositoryProvider);
  return cocktailRepository.getFlavorBasedRecommendations();
});

/// FutureProvider for fetching the user's favorite recipes.
final favoriteRecipesProvider = FutureProvider<List<Recipe>>((ref) {
  final cocktailRepository = ref.watch(cocktailRepositoryProvider);
  return cocktailRepository.getFavoriteRecipes();
});

/// FutureProvider for fetching user-created recipes.
final userCreatedRecipesProvider = FutureProvider<List<Recipe>>((ref) {
  final cocktailRepository = ref.watch(cocktailRepositoryProvider);
  return cocktailRepository.getUserCreatedRecipes();
});

/// FutureProvider for fetching recipes that have notes.
final recipesWithNotesProvider = FutureProvider<List<Recipe>>((ref) {
  final cocktailRepository = ref.watch(cocktailRepositoryProvider);
  return cocktailRepository.getRecipesWithNotes();
});

// --- Recipe Detail Providers ---
/// Family FutureProvider for fetching ingredients for a specific recipe.
final recipeIngredientsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, recipeId) {
  final cocktailRepository = ref.watch(cocktailRepositoryProvider);
  return cocktailRepository.getIngredientsForRecipe(recipeId);
});

/// Family FutureProvider for fetching tags for a specific recipe.
final recipeTagsProvider = FutureProvider.family<List<String>, int>((ref, recipeId) {
  final cocktailRepository = ref.watch(cocktailRepositoryProvider);
  return cocktailRepository.getRecipeTags(recipeId);
});

/// Family FutureProvider for fetching ABV for a specific recipe.
final recipeAbvProvider = FutureProvider.family<double?, int>((ref, recipeId) {
  final cocktailRepository = ref.watch(cocktailRepositoryProvider);
  return cocktailRepository.getRecipeABV(recipeId);
});

/// Family FutureProvider for fetching notes for a specific recipe.
final recipeNoteProvider = FutureProvider.family<String?, int>((ref, recipeId) {
  final cocktailRepository = ref.watch(cocktailRepositoryProvider);
  return cocktailRepository.getRecipeNote(recipeId);
});

// --- User Stats Providers ---

final favoritesCountProvider = FutureProvider<int>((ref) {
  final cocktailRepository = ref.watch(cocktailRepositoryProvider);
  return cocktailRepository.getFavoritesCount();
});

final creationsCountProvider = FutureProvider<int>((ref) {
  final cocktailRepository = ref.watch(cocktailRepositoryProvider);
  return cocktailRepository.getCreationsCount();
});

final notesCountProvider = FutureProvider<int>((ref) {
  final cocktailRepository = ref.watch(cocktailRepositoryProvider);
  return cocktailRepository.getNotesCount();
});

/// FutureProvider for fetching the shopping list.
final shoppingListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  final cocktailRepository = ref.watch(cocktailRepositoryProvider);
  return cocktailRepository.getShoppingList();
});
