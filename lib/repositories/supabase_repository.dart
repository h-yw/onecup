// lib/repositories/supabase_repository.dart

import 'package:flutter/foundation.dart';
import 'package:onecup/models/explorable_recipe.dart';
import 'package:onecup/models/missing_one_recipe.dart';
import 'package:onecup/models/purchase_recommendation.dart';
import 'package:onecup/models/receip.dart';
import 'package:onecup/models/recipe_ingredient.dart';
import 'package:onecup/repositories/cocktail_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Concrete implementation of the [CocktailRepository] using Supabase.
///
/// This class handles all the data fetching logic related to cocktails,
/// inventory, and recommendations by communicating with the Supabase backend.
class SupabaseRepository implements CocktailRepository {
  final SupabaseClient _client;

  SupabaseRepository(this._client);

  String? get _currentUserId => _client.auth.currentUser?.id;

  @override
  Future<List<Recipe>> getMakeableRecipes() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client.rpc('get_makeable_recipes', params: {'p_user_id': userId});
      return (response as List).map((map) => Recipe.fromMap(map)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('获取“即可调制”配方失败: $e');
      }
      return [];
    }
  }

  @override
  Future<List<MissingOneRecipe>> getMissingOneRecipes() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client.rpc('get_missing_one_recipes', params: {'p_user_id': userId});
      return (response as List)
          .map((item) => MissingOneRecipe.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) print('获取“仅差一种”配方失败: $e');
      return [];
    }
  }

  @override
  Future<List<ExplorableRecipe>> getExplorableRecipes() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client.rpc('get_explorable_recipes', params: {'p_user_id': userId});
      return (response as List)
          .map((item) => ExplorableRecipe.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) print('获取“探索更多”配方失败: $e');
      return [];
    }
  }

  @override
  Future<Map<String, List<String>>> getInventoryByCategory() async {
    final userId = _currentUserId;
    if (userId == null) return {};
    try {
      final inventoryResponse = await _client.from('onecup_user_inventory').select('ingredient_id').eq('user_id', userId);
      if (inventoryResponse.isEmpty) return {};
      final ingredientIds = inventoryResponse.map((row) => row['ingredient_id']).toList();

      final ingredientsResponse = await _client.from('onecup_ingredients').select('name, category_id').inFilter('id', ingredientIds);
      final categoryIds = ingredientsResponse.map((row) => row['category_id']).toSet().toList();
      final categoriesResponse = await _client.from('onecup_ingredient_categories').select('id, name').inFilter('id', categoryIds);
      final categoryMap = { for (var cat in categoriesResponse) cat['id']: cat['name'] };

      final groupedInventory = <String, List<String>>{};
      for (var ingredient in ingredientsResponse) {
        final categoryName = categoryMap[ingredient['category_id']] ?? '未分类';
        final ingredientName = ingredient['name'] as String;
        if (groupedInventory[categoryName] == null) {
          groupedInventory[categoryName] = [];
        }
        groupedInventory[categoryName]!.add(ingredientName);
      }
      return groupedInventory;
    } catch (e) {
      if (kDebugMode) print('按类别获取库存失败: $e');
      return {};
    }
  }

  @override
  Future<List<PurchaseRecommendation>> getPurchaseRecommendations() async {
    final userId = _currentUserId;
    if (userId == null) {
      if (kDebugMode) print('用户未登录，无法获取购买建议。');
      return [];
    }

    try {
      final response = await _client.rpc(
        'get_purchase_recommendations',
        params: {'p_user_id': userId},
      );
      return (response as List)
          .map((item) => PurchaseRecommendation.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('调用 RPC get_purchase_recommendations 失败: $e');
      }
      return [];
    }
  }

  @override
  Future<int?> getIngredientIdByName(String name) async {
    try {
      debugPrint('SupabaseRepository: Querying ingredient ID for name: $name');
      // 1. 尝试通过主名称精确匹配
      final response = await _client
          .from('onecup_ingredients')
          .select('id, aliases') // 同时获取别名
          .eq('name', name)
          .maybeSingle();

      if (response != null && response['id'] != null) {
        debugPrint('SupabaseRepository: Found ID by primary name: ${response['id']}');
        return response['id'] as int;
      }

      // 2. 如果未找到，则尝试通过别名匹配
      // 获取所有配料的名称和别名
      final allIngredients = await _client
          .from('onecup_ingredients')
          .select('id, name, aliases');

      for (var ingredient in allIngredients) {
        final List<dynamic>? aliases = ingredient['aliases'] as List<dynamic>?;
        if (aliases != null && aliases.contains(name)) {
          debugPrint('SupabaseRepository: Found ID by alias: ${ingredient['id']}');
          return ingredient['id'] as int;
        }
      }

      debugPrint('SupabaseRepository: Ingredient not found by name or alias: $name');
      return null;
    } catch(e) {
      if (kDebugMode) debugPrint('SupabaseRepository: 按名称获取配料ID失败: $e');
      return null;
    }
  }

  @override
  Future<void> removeIngredientFromInventory(int ingredientId) async {
    final userId = _currentUserId;
    if (userId == null) return;
    await _client
        .from('onecup_user_inventory')
        .delete()
        .match({'user_id': userId, 'ingredient_id': ingredientId});
  }

  @override
  Future<void> addIngredientToShoppingList(int ingredientId, String ingredientName) async {
    final userId = _currentUserId;
    if (userId == null) {
      if (kDebugMode) print('用户未登录，无法添加到购物清单。');
      return;
    }
    try {
      await _client.rpc(
        'add_to_shopping_list_if_not_exists',
        params: {
          'p_user_id': userId,
          'p_ingredient_id': ingredientId,
          'p_name': ingredientName,
        },
      );
    } catch (e) {
      if (kDebugMode) print('添加到购物清单时出错 for "$ingredientName": $e');
      // Optionally rethrow or handle the error in the UI
    }
  }

  @override
  Future<List<Recipe>> getAllRecipes() async {
    try {
      // [修正] 新增 .filter() 来只获取 user_id 为 null 的官方配方
      final response = await _client
          .from('v_recipes_with_details')
          .select()
          .filter('user_id', 'is', null)
          .order('name', ascending: true); // 按名称升序排序
      return (response as List).map((map) => Recipe.fromMap(map)).toList();
    } catch (e) {
      if (kDebugMode) print('获取所有配方失败: $e');
      return [];
    }
  }

  @override
  Future<List<Recipe>> getFlavorBasedRecommendations() async {
    final userId = _currentUserId;
    if (userId == null) return [];
    try {
      final response = await _client.rpc('get_flavor_based_recommendations', params: {'p_user_id': userId, 'p_limit': 10});
      return (response as List).map((map) => Recipe.fromMap(map)).toList();
    } catch (e) {
      if (kDebugMode) print('获取口味推荐失败: $e');
      return [];
    }
  }

  @override
  Future<List<Recipe>> getFavoriteRecipes() async {
    final userId = _currentUserId;
    if (userId == null) return [];
    try {
      final favResponse = await _client.from('onecup_user_favorites').select('recipe_id').eq('user_id', userId);
      if (favResponse.isEmpty) return [];
      final recipeIds = favResponse.map((fav) => fav['recipe_id']).toList();
      final response = await _client.from('v_recipes_with_details').select().inFilter('id', recipeIds);
      return response.map((map) => Recipe.fromMap(map)).toList();
    } catch (e) {
      if (kDebugMode) print('获取收藏配方失败: $e');
      return [];
    }
  }

  @override
  Future<List<Recipe>> getUserCreatedRecipes() async {
    final userId = _currentUserId;
    if (userId == null) return [];
    try {
      final response = await _client.from('v_recipes_with_details').select().eq('user_id', userId);
      return response.map((map) => Recipe.fromMap(map)).toList();
    } catch (e) {
      if (kDebugMode) print('获取用户创作配方失败: $e');
      return [];
    }
  }
  
  @override
  Future<List<Recipe>> getRecipesWithNotes() async {
    final userId = _currentUserId;
    if (userId == null) return [];
    try {
      final notesResponse = await _client.from('onecup_user_recipe_notes').select('recipe_id').eq('user_id', userId);
      if (notesResponse.isEmpty) return [];
      final recipeIds = notesResponse.map((map) => map['recipe_id']).toList();
      final response = await _client.from('v_recipes_with_details').select().inFilter('id', recipeIds).order('name', ascending: true);
      return response.map((map) => Recipe.fromMap(map)).toList();
    } catch(e) {
      if (kDebugMode) print('获取带笔记的配方失败: $e');
      return [];
    }
  }

  @override
  Future<int> getFavoritesCount() async {
    final userId = _currentUserId;
    if (userId == null) return 0;
    try {
      final response = await _client.from('onecup_user_favorites').select().eq('user_id', userId).count();
      return response.count;
    } catch(e) {
      if (kDebugMode) print('获取收藏数量失败: $e');
      return 0;
    }
  }

  @override
  Future<int> getCreationsCount() async {
    final userId = _currentUserId;
    if (userId == null) return 0;
    try {
      final response = await _client.from('onecup_recipes').select().eq('user_id', userId).count();
      return response.count;
    } catch(e) {
      if (kDebugMode) print('获取创作数量失败: $e');
      return 0;
    }
  }

  @override
  Future<int> getNotesCount() async {
    final userId = _currentUserId;
    if (userId == null) return 0;
    try {
      final response = await _client.from('onecup_user_recipe_notes').select().eq('user_id', userId).count();
      return response.count;
    } catch(e) {
      if (kDebugMode) print('获取笔记数量失败: $e');
      return 0;
    }
  }

  @override
  Future<void> addRecipeToFavorites(int recipeId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('用户未登录，无法收藏配方。');
    }
    try {
      await _client.from('onecup_user_favorites').insert({
        'user_id': userId,
        'recipe_id': recipeId,
      });
    } catch (e) {
      if (kDebugMode) print('收藏配方失败: $e');
      throw Exception('收藏配方失败: $e');
    }
  }

  @override
  Future<void> removeRecipeFromFavorites(int recipeId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('用户未登录，无法取消收藏配方。');
    }
    try {
      await _client.from('onecup_user_favorites').delete().match({
        'user_id': userId,
        'recipe_id': recipeId,
      });
    } catch (e) {
      if (kDebugMode) print('取消收藏配方失败: $e');
      throw Exception('取消收藏配方失败: $e');
    }
  }

  @override
  Future<bool> isRecipeFavorite(int recipeId) async {
    final userId = _currentUserId;
    if (userId == null) return false;
    try {
      final response = await _client
          .from('onecup_user_favorites')
          .select('id')
          .eq('user_id', userId)
          .eq('recipe_id', recipeId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      if (kDebugMode) print('检查收藏状态失败: $e');
      return false;
    }
  }

  @override
  Future<void> saveRecipeNote(int recipeId, String notesJson) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('用户未登录，无法保存笔记。');
    }
    try {
      await _client.from('onecup_user_recipe_notes').upsert({
        'user_id': userId,
        'recipe_id': recipeId,
        'notes': notesJson,
      },  onConflict: 'user_id,recipe_id');
    } catch (e) {
      if (kDebugMode) {
        print('保存/更新笔记时出错 for recipe $recipeId: $e');
      }
      throw Exception('保存笔记失败: $e');
    }
  }

  @override
  Future<String?> getRecipeNote(int recipeId) async {
    final userId = _currentUserId;
    if (userId == null) return null;
    try {
      final response = await _client
          .from('onecup_user_recipe_notes')
          .select('notes')
          .eq('user_id', userId)
          .eq('recipe_id', recipeId)
          .maybeSingle();
      return response?['notes'] as String?;
    } catch (e) {
      if (kDebugMode) print('获取笔记失败: $e');
      return null;
    }
  }

  @override
  Future<void> deleteRecipeNote(int recipeId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('用户未登录，无法删除笔记。');
    }
    try {
      await _client
          .from('onecup_user_recipe_notes')
          .delete()
          .match({'user_id': userId, 'recipe_id': recipeId});
    } catch (e) {
      if (kDebugMode) {
        print('删除笔记时出错 for recipe $recipeId: $e');
      }
      throw Exception('删除笔记失败: $e');
    }
  }

  @override
  Future<void> addIngredientToInventory(int ingredientId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('用户未登录，无法添加配料到库存。');
    }
    try {
      await _client.from('onecup_user_inventory').upsert({
        'user_id': userId,
        'ingredient_id': ingredientId,
      }, onConflict: ['user_id', 'ingredient_id'].join(','));
    } catch (e) {
      if (kDebugMode) print('添加配料到库存失败: $e');
      throw Exception('添加配料到库存失败: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getIngredientsForBarManagement() async {
    try {
      final inventoryIds = await _client
          .from('onecup_user_inventory')
          .select('ingredient_id')
          .eq('user_id', _currentUserId!)
          .then((response) => response.map((e) => e['ingredient_id'] as int).toSet());

      final allIngredientsResponse = await _client
          .from('onecup_ingredients')
          .select('id, name, category_id');

      final categoryIds = allIngredientsResponse.map((row) => row['category_id']).where((id) => id != null).toSet().toList();
      final categoriesResponse = await _client.from('onecup_ingredient_categories').select('id, name').inFilter('id', categoryIds);
      final categoryMap = { for (var cat in categoriesResponse) cat['id']: cat['name'] };

      return allIngredientsResponse.map((ingredient) {
        final categoryName = categoryMap[ingredient['category_id']] ?? '未分类';
        return {
          'id': ingredient['id'],
          'name': ingredient['name'],
          'category': categoryName,
          'in_inventory': inventoryIds.contains(ingredient['id']),
        };
      }).toList()..sort((a, b) => (a['category'] as String).compareTo(b['category'] as String));
    } catch (e) {
      if (kDebugMode) print('获取库存管理配料失败: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getShoppingList() async {
    final userId = _currentUserId;
    if (userId == null) return [];
    try {
      final response = await _client
          .from('onecup_shopping_list')
          .select('id, name, ingredient_id, checked')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      if (kDebugMode) debugPrint('SupabaseRepository: getShoppingList response: $response');
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) debugPrint('SupabaseRepository: 获取购物清单失败: $e');
      return [];
    }
  }

  @override
  Future<void> addToShoppingList(String name, int ingredientId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('用户未登录，无法添加到购物清单。');
    }
    try {
      await _client.from('onecup_shopping_list').insert({
        'user_id': userId,
        'name': name,
        'ingredient_id': ingredientId,
        'checked': false,
      });
    } catch (e) {
      if (kDebugMode) print('添加到购物清单失败: $e');
      throw Exception('添加到购物清单失败: $e');
    }
  }

  @override
  Future<void> updateShoppingListItem(int id, bool isChecked) async {
    try {
      await _client.from('onecup_shopping_list').update({
        'checked': isChecked,
      }).eq('id', id);
    } catch (e) {
      if (kDebugMode) print('更新购物清单项失败: $e');
      throw Exception('更新购物清单项失败: $e');
    }
  }

  @override
  Future<void> removeFromShoppingList(int id) async {
    try {
      await _client.from('onecup_shopping_list').delete().eq('id', id);
    } catch (e) {
      if (kDebugMode) print('从购物清单删除失败: $e');
      throw Exception('从购物清单删除失败: $e');
    }
  }

  @override
  Future<void> clearCompletedShoppingItems() async {
    final userId = _currentUserId;
    if (userId == null) return;
    try {
      await _client
          .from('onecup_shopping_list')
          .delete()
          .eq('user_id', userId)
          .eq('checked', true);
    } catch (e) {
      if (kDebugMode) print('清除已完成购物项失败: $e');
      throw Exception('清除已完成购物项失败: $e');
    }
  }

  @override
  Future<void> addRecipeIngredientsToShoppingList(int recipeId) async {
    final userId = _currentUserId;
    if (userId == null) {
      if (kDebugMode) print('用户未登录，无法将配料添加到购物清单。');
      return;
    }
    final ingredients = await getIngredientsForRecipe(recipeId);
    if (ingredients.isEmpty) {
      if (kDebugMode) print('没有配料可以添加到购物清单 for recipe $recipeId');
      return;
    }
    for (var ingredient in ingredients) {
      final name = ingredient['name'];
      final ingredientId= ingredient['ingredient_id'];
      try {
        await addIngredientToShoppingList(ingredientId, name);
      } catch (e) {
        if (kDebugMode) {
          print('将配料 "$name" (ID: $ingredientId) 添加到购物清单失败: $e');
        }
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getIngredientsForRecipe(int recipeId) async {
    try {
      final recipeIngredientsResponse =  await _client
          .from('onecup_recipe_ingredients')
          .select('name:display_name, amount, unit,ingredient_id')
          .eq('recipe_id', recipeId);
      if (recipeIngredientsResponse.isEmpty) return [];
      final ingredientIds = recipeIngredientsResponse.map((row) => row['ingredient_id'] as int).toSet().toList();
      if(ingredientIds.isEmpty) return [];

      final abvResponse = await _client
          .from('onecup_ingredients')
          .select('id, abv')
          .inFilter('id', ingredientIds);
      final abvMap = { for (var item in abvResponse) item['id']: item['abv'] };

      final list = recipeIngredientsResponse.map((ingredient) {
        final ingredientId = ingredient['ingredient_id'];
        return {
          'name': ingredient['name'], // 使用 'name' 作为别名，方便下游使用
          'amount': ingredient['amount'],
          'unit': ingredient['unit'],
          'abv': abvMap[ingredientId] ?? 0.0, // 合并ABV，如果不存在则默认为0.0
          ...ingredient
        };
      }).toList();
      print(';list====>$list');
      return list;
    } catch (e) {
      if (kDebugMode) print('获取配方配料失败: $e');
      return [];
    }
  }

  @override
  Future<List<String>> getRecipeTags(int recipeId) async {
    try {
      // 1. 从关联表获取该配方的所有 tag_id
      final recipeTagsResponse = await _client
          .from('onecup_recipe_tags')
          .select('tag_id')
          .eq('recipe_id', recipeId);

      if (recipeTagsResponse.isEmpty) return [];

      final tagIds = recipeTagsResponse.map((row) => row['tag_id'] as int).toList();

      // 2. 使用 tag_id 列表去 tags 表中查询所有对应的名称
      final tagsResponse = await _client
          .from('onecup_tags')
          .select('name')
          .inFilter('id', tagIds);

      return tagsResponse.map((map) => map['name'] as String).toList();
    } catch (e) {
      if (kDebugMode) print('获取配方标签失败: $e');
      return [];
    }
  }

  @override
  Future<double?> getRecipeABV(int recipeId) async {
    try {
      // 手动 JOIN，不再使用资源嵌入
      // 1. 获取配方的所有配料信息（amount, unit, ingredient_id）
      final recipeIngredients = await _client
          .from('onecup_recipe_ingredients')
          .select('amount, unit, ingredient_id')
          .eq('recipe_id', recipeId);
      if (recipeIngredients.isEmpty) return null;

      final ingredientIds = recipeIngredients.map((row) => row['ingredient_id'] as int).toList();

      // 2. 获取这些配料的 abv 值
      final abvResponse = await _client
          .from('onecup_ingredients')
          .select('id, abv')
          .inFilter('id', ingredientIds);
      final abvMap = {for (var item in abvResponse) item['id']: item['abv']};

      // 3. 开始计算，逻辑与之前相同
      double totalPureAlcohol = 0;
      double totalLiquidVolume = 0;
      bool hasAlcohol = false;

      for (var ing in recipeIngredients) {
        final amountStr = ing['amount'] as String?;
        final unit = ing['unit'] as String?;
        final abvValue = abvMap[ing['ingredient_id']];
        final double? abv = (abvValue is num) ? abvValue.toDouble() : null;

        if (amountStr == null || amountStr.isEmpty) continue;

        double amount = double.tryParse(amountStr.replaceAll(',', '.')) ?? 0;

        final unitLower = unit?.toLowerCase() ?? '';
        if (unitLower == 'oz' || unitLower == '盎司') amount *= 30;
        else if (unitLower.contains('dash') || unitLower.contains('滴')) amount *= 0.8;
        else if (unitLower.contains('tsp') || unitLower.contains('茶匙')) amount *= 5;
        else if (unitLower.contains('bar spoon') || unitLower.contains('吧勺')) amount *= 5;

        if (amount > 0) {
          totalLiquidVolume += amount;
          if (abv != null && abv > 0) {
            hasAlcohol = true;
            totalPureAlcohol += amount * (abv / 100.0);
          }
        }
      }
      if (!hasAlcohol || totalLiquidVolume == 0) return 0.0;

      final double dilution = totalLiquidVolume * 0.25;
      final double finalVolume = totalLiquidVolume + dilution;
      if (finalVolume == 0) return 0.0;

      return (totalPureAlcohol / finalVolume) * 100;

    } catch (e) {
      if (kDebugMode) print('计算 ABV 失败: $e');
      return null;
    }
  }

  @override
  Future<int?> addCustomRecipe(Recipe recipe, List<RecipeIngredient> ingredients) async {
    final userId = _currentUserId;
    if (userId == null) {
      if (kDebugMode) print('错误: 用户未登录，无法添加自定义配方。');
      return null;
    }

    try {
      final ingredientNames = ingredients.map((i) => i.name).toList();
      final ingredientsResponse = await _client
          .from('onecup_ingredients')
          .select('id, name')
          .inFilter('name', ingredientNames);

      final ingredientIdMap = {for (var ing in ingredientsResponse) ing['name']: ing['id']};

      for (var ing in ingredients) {
        if (!ingredientIdMap.containsKey(ing.name)) {
          throw Exception('数据库中找不到配料: "${ing.name}"。请确保所有配料都存在。');
        }
      }

      final categoryResponse = await _client.from('onecup_recipe_categories').select('id').eq('name', '我的创作').single();
      final categoryId = categoryResponse['id'];

      final glassResponse = await _client.from('onecup_glassware').select('id').eq('name', recipe.glass!).single();
      final glassId = glassResponse['id'];

      final newRecipeResponse = await _client.rpc('add_recipe_with_ingredients', params: {
        'p_name': recipe.name,
        'p_description': recipe.description,
        'p_instructions': recipe.instructions,
        'p_image': recipe.imageUrl,
        'p_category_id': categoryId,
        'p_glass_id': glassId,
        'p_user_id': userId,
        'p_notes': recipe.notes,
        'p_video_url': recipe.videoUrl,
        'p_ingredients': ingredients.map((ing) => {
          'ingredient_id': ingredientIdMap[ing.name],
          'display_name': ing.name,
          'amount': ing.quantity.toString(),
          'unit': ing.unit,
          'is_optional': ing.isOptional,
        }).toList(),
      });

      final newRecipeId = newRecipeResponse as int?;
      if (newRecipeId != null) {
        if (kDebugMode) print('✅ 成功添加新配方及其关联数据，ID: $newRecipeId');
        return newRecipeId;
      } else {
        throw Exception('在数据库事务中创建配方失败。');
      }

    } catch (e) {
      if (kDebugMode) print('添加自定义配方时发生严重错误: $e');
      throw Exception('保存配方失败，请检查数据或稍后再试。错误: $e');
    }
  }

  @override
  Future<List<String>> getAllGlasswareNames() async {
    try {
      final response = await _client.from('onecup_glassware').select('name').order('name');
      return response.map((map) => map['name'] as String).toList();
    } catch (e) {
      if (kDebugMode) print('获取所有杯具名称失败: $e');
      return [];
    }
  }

  @override
  Future<Recipe?> getRecipeById(int recipeId) async {
    try {
      final response = await _client
          .from('v_recipes_with_details')
          .select()
          .eq('id', recipeId)
          .single();
      return Recipe.fromMap(response);
    } catch (e) {
      if (kDebugMode) print('Error fetching recipe by id: $e');
      return null;
    }
  }
}