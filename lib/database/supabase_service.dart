// lib/services/supabase_service.dart

import 'dart:io';

import 'package:flutter/foundation.dart'; // 用于 kDebugMode
import 'package:onecup/models/receip.dart'; // 确保 Recipe 模型的路径正确
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/recipe_ingredient.dart';

class SupabaseService {
  // 单例模式，确保应用中只有一个服务实例
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // 获取 Supabase 客户端实例的便捷方式
  final SupabaseClient _client = Supabase.instance.client;


  // --- 认证相关 ---

  /// 获取当前登录用户的便捷 getter
  User? get currentUser => _client.auth.currentUser;

  /// 监听认证状态变化的 Stream
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// 用户注册
  ///
  /// @param email 用户的电子邮箱
  /// @param password 用户的密码
  /// @returns 返回一个 AuthResponse 对象，可以从中判断是否成功
  Future<AuthResponse> signUp({required String email, required String password}) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  /// 用户登录
  ///
  /// @param email 用户的电子邮箱
  /// @param password 用户的密码
  /// @returns 返回一个 AuthResponse 对象
  Future<AuthResponse> signIn({required String email, required String password}) async {
    return await _client.auth.signInWithPassword(password: password, email: email);
  }

  /// 用户登出
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // 获取当前登录用户的 ID
  String? get _currentUserId => _client.auth.currentUser?.id;

  // ---------------用户信息-------------------
  /// 更新用户元数据 (例如昵称、头像URL)
  ///
  /// @param data 一个包含要更新的元数据键值对的 Map。
  ///             例如: {'nickname': '新的昵称', 'avatar_url': '新的头像URL'}
  Future<UserResponse> updateUserMetadata(Map<String, dynamic> data) async {
    final response = await _client.auth.updateUser(
      UserAttributes(data: data),
    );
    // 更新后，Supabase.instance.client.auth.currentUser 可能不会立即刷新，
    // 但 authStateChanges stream 应该会发出新的 User 对象。
    // 手动刷新本地 currentUser (可选，但有时有帮助)
    // await _client.auth.refreshSession(); // 或者 signOut 然后重新 signIn 以强制刷新，但不推荐
    return response;
  }

  /// 上传头像文件到 Supabase Storage 并返回公开 URL
  ///
  /// @param filePath 本地图片文件的路径
  /// @param userId 用于构建存储路径，确保每个用户的文件路径唯一
  /// @returns 上传成功后的公开 URL，失败则抛出异常
  Future<String> uploadAvatar(String filePath, String userId) async {
    final file = File(filePath);
    final fileExtension = filePath.split('.').last.toLowerCase();
    // 使用时间戳确保文件名唯一，防止覆盖同名文件（如果用户快速更换头像）
    final fileName = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    final bucketName = 'onecup'; //

    try {
     await _client.storage.from(bucketName).upload(
        fileName,
        file,
        fileOptions: FileOptions(cacheControl: '3600', upsert: true), // upsert: true 会覆盖同名文件
      );


      // 获取公开 URL
      final publicUrlResponse = _client.storage.from(bucketName).getPublicUrl(fileName);
      return publicUrlResponse;
    } catch (e) {
      if (kDebugMode) {
        print('SupabaseService: Error uploading avatar: $e');
      }
      throw Exception('头像上传失败: $e');
    }
  }

  /// 获取用户昵称，如果存在的话
  String? getUserNickname(User? user) {
    return user?.userMetadata?['nickname'] as String?;
  }

  /// 获取用户头像 URL，如果存在的话
  String? getAvatarUrl(User? user) {
    return user?.userMetadata?['avatar_url'] as String?;
  }


  /// [核心优化] 从新的v_recipes_with_details视图获取数据，避免客户端JOIN
  Future<List<Recipe>> _fetchRecipesFromView({String? filterColumn, dynamic filterValue}) async {
    try {
      var query = _client.from('v_recipes_with_details').select();
      if (filterColumn != null && filterValue != null) {
        query = query.filter(filterColumn, 'is', filterValue);
      }
      final response = await query.order('name', ascending: true);

      // 直接使用 fromMap，因为视图返回的是扁平结构
      return response.map((map) => Recipe.fromMap(map)).toList();
    } catch (e) {
      if (kDebugMode) print('从视图获取配方失败: $e');
      return [];
    }
  }

  // --- 配方查询 (Recipe Queries) ---
  /// 获取所有公开的配方
  Future<List<Recipe>> getAllRecipes() async {
    return _fetchRecipesFromView(filterColumn: 'user_id', filterValue: null);
  }


  /// 获取用户收藏的配方列表
  Future<List<Recipe>> getFavoriteRecipes() async {
    final userId = _currentUserId;
    if (userId == null) return [];
    try {
      final favResponse = await _client
          .from('onecup_user_favorites')
          .select('recipe_id')
          .eq('user_id', userId);

      if (favResponse.isEmpty) return [];

      final recipeIds = favResponse.map((fav) => fav['recipe_id']).toList();

      // [核心修正] 将 .in_() 替换为 .inFilter()
      final response = await _client
          .from('v_recipes_with_details')
          .select()
          .inFilter('id', recipeIds); // <-- 此处已修正

      return response.map((map) => Recipe.fromMap(map)).toList();
    } catch (e) {
      if (kDebugMode) print('获取收藏配方失败: $e');
      return [];
    }
  }

  /// 获取用户自己创建的配方
  Future<List<Recipe>> getUserCreatedRecipes() async {
    final userId = _currentUserId;
    if (userId == null) return [];
    return _fetchRecipesFromView(filterColumn: 'user_id', filterValue: userId);
  }

  // --- 高效统计计数 (Count Queries) ---

  /// 高效获取收藏数量
  Future<int> getFavoritesCount() async {
    final userId = _currentUserId;
    if (userId == null) return 0;
    try {
      // [核心修正] 调用 .count() 方法，并且 select() 中不带参数
      final response = await _client
          .from('onecup_user_favorites')
          .select()
          .eq('user_id', userId)
          .count();
      return response.count;
    } catch(e) {
      if (kDebugMode) print('获取收藏数量失败: $e');
      return 0;
    }
  }

  /// 高效获取创作数量
  Future<int> getCreationsCount() async {
    final userId = _currentUserId;
    if (userId == null) return 0;
    try {
      // [核心修正] 调用 .count() 方法
      final response = await _client
          .from('onecup_recipes')
          .select()
          .eq('user_id', userId)
          .count();
      return response.count;
    } catch(e) {
      if (kDebugMode) print('获取创作数量失败: $e');
      return 0;
    }
  }

  /// 高效获取笔记数量
  Future<int> getNotesCount() async {
    final userId = _currentUserId;
    if (userId == null) return 0;
    try {
      // [核心修正] 调用 .count() 方法
      final response = await _client
          .from('onecup_user_recipe_notes')
          .select()
          .eq('user_id', userId)
          .count();
      return response.count;
    } catch(e) {
      if (kDebugMode) print('获取笔记数量失败: $e');
      return 0;
    }
  }

  /// [RPC] 获取“即可调制”的配方
  // 注意：以下RPC函数的依赖和返回结构需要与你的数据库函数定义保持一致。
  Future<List<Recipe>> getMakeableRecipes() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client.rpc('get_makeable_recipes', params: {'p_user_id': userId});
      return (response as List).map((map) => Recipe.fromMap(map)).toList();
    } catch (e) {
      if (kDebugMode) print('获取“即可调制”配方失败: $e');
      return [];
    }
  }

  /// [RPC] 获取“仅差一种”的配方
  Future<List<Map<String, dynamic>>> getMissingOneRecipes() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client.rpc('get_missing_one_recipes', params: {'p_user_id': userId});
      return (response as List).map((map) {
        return {
          'recipe': Recipe.fromMap(map),
          'missing_ingredient': map['missing_ingredient_name'],
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) print('获取“仅差一种”配方失败: $e');
      return [];
    }
  }

  /// [RPC] 获取“探索更多”的配方 (缺少两种或以上)
  Future<List<Map<String, dynamic>>> getExplorableRecipes() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client.rpc('get_explorable_recipes', params: {'p_user_id': userId});
      return (response as List).map((map) {
        return {
          'recipe': Recipe.fromMap(map),
          'missing_count': map['missing_count'],
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) print('获取“探索更多”配方失败: $e');
      return [];
    }
  }
  // --- 用户库存 (Inventory Management) ---
  Future<Set<int>> getUserInventoryIds() async {
    final userId = _currentUserId;
    if (userId == null) return {};

    try {
      final response = await _client
          .from('onecup_user_inventory')
          .select('ingredient_id')
          .eq('user_id', userId);
      return response.map((e) => e['ingredient_id'] as int).toSet();
    } catch (e) {
      if (kDebugMode) print('获取用户库存ID失败: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getIngredientsForBarManagement() async {
    try {
      final inventoryIds = await getUserInventoryIds();
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

  Future<void> addIngredientToInventory(int ingredientId) async {
    final userId = _currentUserId;
    if (userId == null) return;
    await _client
        .from('onecup_user_inventory')
        .insert({'user_id': userId, 'ingredient_id': ingredientId});
  }

  Future<void> removeIngredientFromInventory(int ingredientId) async {
    final userId = _currentUserId;
    if (userId == null) return;
    await _client
        .from('onecup_user_inventory')
        .delete()
        .match({'user_id': userId, 'ingredient_id': ingredientId});
  }

  // --- 购物清单 (Shopping List) ---

  Future<List<Map<String, dynamic>>> getShoppingList() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      return await _client
          .from('onecup_shopping_list')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
    } catch (e) {
      if (kDebugMode) print('获取购物清单失败: $e');
      return [];
    }
  }

  Future<void> addToShoppingList(String name,int ingredientId) async {
    final userId = _currentUserId;
    if (userId == null) {
      if (kDebugMode) {
        print('用户未登录，无法添加到购物清单。');
      }
      return;
    }
    try {
      await _client.rpc(
        'add_to_shopping_list_if_not_exists', // 数据库中创建的函数名
        params: {
          'p_user_id': userId,         // 匹配函数参数 p_user_id
          'p_ingredient_id': ingredientId, // 匹配函数参数 p_ingredient_id
          'p_name': name,            // 匹配函数参数 p_name
        },
      );
      if (kDebugMode) {
        print('配料 "$name" (ID: $ingredientId) upsert 操作尝试完成。');
      }

    } catch (e) {
      if (kDebugMode) {
        print('添加到购物清单时捕获到异常 for "$name": $e');
      }
      // 根据具体错误类型决定是否重新抛出或如何处理
      if (e is PostgrestException) {
        // 你可以在这里处理特定的 PostgrestException，比如 RLS 错误等
        // 但对于 "violates not-null constraint" 这样的错误，通常是数据准备问题
        throw Exception('添加到购物清单时数据库操作失败: ${e.message}');
      }
      throw Exception('添加到购物清单时发生未知错误。');
    }
  }

  Future<void> updateShoppingListItem(int id, bool isChecked) async {
    await _client
        .from('onecup_shopping_list')
        .update({'checked': isChecked})
        .eq('id', id);
  }

  Future<void> removeFromShoppingList(int id) async {
    await _client
        .from('onecup_shopping_list')
        .delete()
        .eq('id', id);
  }

  Future<void> clearCompletedShoppingItems() async {
    final userId = _currentUserId;
    if (userId == null) return;
    await _client
        .from('onecup_shopping_list')
        .delete()
        .match({'checked': true, 'user_id': userId});
  }

  Future<void> addRecipeIngredientsToShoppingList(int recipeId) async {
    final userId = _currentUserId; // 获取当前用户ID，以便传递或在需要时检查
    if (userId == null) {
      if (kDebugMode) print('用户未登录，无法将配料添加到购物清单。');
      // 可以考虑在这里显示登录提示或直接返回
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
        // 调用修改后的 addToShoppingList
        await addToShoppingList(name, ingredientId);
      } catch (e) {
        // 在循环中捕获单个添加失败的错误，避免中断整个过程
        if (kDebugMode) {
          print('将配料 "$name" (ID: $ingredientId) 添加到购物清单失败: $e');
        }
      }
    }
  }

  // --- 收藏夹 (Favorites) ---
// 清理了此方法，移除了不必要的print语句
  Future<void> addRecipeToFavorites(int recipeId) async {
    final userId = _currentUserId;
    if (userId == null) return;
    // insert 默认不返回任何内容，除非链式调用 .select()。
    // 因此，这里的变量和打印是多余的。
    await _client
        .from('onecup_user_favorites')
        .insert({'user_id': userId, 'recipe_id': recipeId});
  }

  Future<void> removeRecipeFromFavorites(int recipeId) async {
    final userId = _currentUserId;
    if (userId == null) {
      if (kDebugMode) print('用户未登录，无法取消收藏。');
      return;
    }
    try {
      await _client
          .from('onecup_user_favorites')
          .delete()
          .match({'user_id': userId, 'recipe_id': recipeId});
      if (kDebugMode) print('食谱 $recipeId 已从用户 $userId 的收藏中移除 (如果存在)。');
    } catch (e) {
      if (kDebugMode) print('取消收藏食谱 $recipeId 时出错: $e');
      // 可以考虑重新抛出异常，让调用者处理
      throw Exception(e);
    }
  }

  Future<bool> isRecipeFavorite(int recipeId) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    final response = await _client
        .from('onecup_user_favorites')
        .select()
        .match({'user_id': userId, 'recipe_id': recipeId})
        .limit(1);

    return response.isNotEmpty;
  }

  // --- 笔记 (Notes) ---

  /// 获取用户对特定食谱的笔记。
  /// 用于 EditNoteScreen 初始化时加载现有笔记。
  Future<String?> getRecipeNote(int recipeId) async {
    final userId = _currentUserId;
    if (userId == null) {
      if (kDebugMode) print('用户未登录，无法获取笔记。');
      return null;
    }
    try {
      final response = await _client
          .from('onecup_user_recipe_notes')
          .select('notes') // 选择包含笔记内容的列
          .match({'user_id': userId, 'recipe_id': recipeId})
          .maybeSingle(); // 一个用户对一个食谱最多一条笔记

      if (response != null && response['notes'] != null) {
        return response['notes'] as String;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('获取笔记时出错 for recipe $recipeId: $e');
      }
      return null; // 出错时返回null，让 EditNoteScreen 按新笔记处理
    }
  }

  /// 保存或更新用户对特定食谱的笔记。
  Future<void> saveRecipeNote(int recipeId, String notesJson) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('用户未登录，无法保存笔记。');
    }
    try {
      await _client.from('onecup_user_recipe_notes').upsert({
        'user_id': userId,
        'recipe_id': recipeId,
        'notes': notesJson, // 假设存储笔记内容的列名为 'notes'
      },  onConflict: 'user_id,recipe_id'); // 冲突解决依赖于 (user_id, recipe_id) 的唯一性
      if (kDebugMode) {
        print('笔记已为 recipe $recipeId 和 user $userId 保存/更新。');
      }
    } catch (e) {
      if (kDebugMode) {
        print('保存/更新笔记时出错 for recipe $recipeId: $e');
      }
      throw Exception('保存笔记失败: $e'); // 重新抛出，让调用者处理UI提示
    }
  }

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
      if (kDebugMode) {
        print('笔记已为 recipe $recipeId 和 user $userId 删除。');
      }
    } catch (e) {
      if (kDebugMode) {
        print('删除笔记时出错 for recipe $recipeId: $e');
      }
      throw Exception('删除笔记失败: $e'); // 重新抛出
    }
  }

  /// 获取单个配方的详细配料列表
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
        };
      }).toList();
      return list;
    } catch (e) {
      if (kDebugMode) print('获取配方配料失败: $e');
      return [];
    }
  }

  /// 获取配方的所有标签 (基于配料口味)
  Future<List<String>> getRecipeTags(int recipeId) async {
    try {
      // [修复] 手动 JOIN，不再使用资源嵌入
      // 1. 从关联表获取该配方的所有 tag_id
      final recipeTagsResponse = await _client
          .from('onecup_recipe_tags')
          .select('tag_id')
          .eq('recipe_id', recipeId);
      print("recipeTagsResponse======>$recipeTagsResponse");

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
  /// 计算配方的估算酒精度 (ABV)
  Future<double?> getRecipeABV(int recipeId) async {
    try {
      // 手动 JOIN，不再使用资源嵌入
      // 1. 获取配方的所有配料信息（amount, unit, ingredient_id）
      final recipeIngredients = await _client
          .from('onecup_recipe_ingredients')
          .select('amount, unit, ingredient_id')
          .eq('recipe_id', recipeId);
      print(" recipeIngredients====> $recipeIngredients");
      if (recipeIngredients.isEmpty) return null;

      final ingredientIds = recipeIngredients.map((row) => row['ingredient_id'] as int).toList();

      // 2. 获取这些配料的 abv 值
      final abvResponse = await _client
          .from('onecup_ingredients')
          .select('id, abv')
          .inFilter('id', ingredientIds);
      print("abv====>$ingredientIds,$abvResponse");
      final abvMap = {for (var item in abvResponse) item['id']: item['abv']};

      // 3. 开始计算，逻辑与之前相同
      double totalPureAlcohol = 0;
      double totalLiquidVolume = 0;
      bool hasAlcohol = false;

      for (var ing in recipeIngredients) {
        final amountStr = ing['amount'] as String?;
        final unit = ing['unit'] as String?;
        // 从我们手动创建的 abvMap 中查找 abv
        // final abv = abvMap[ing['ingredient_id']] as double?;
        // [修复] 使用安全的方式处理数字类型
        final abvValue = abvMap[ing['ingredient_id']];
        // 将 num? 转换为 double?
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
      print("recipeIngredients=====>$hasAlcohol");
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

  /// 获取所有杯具的名称列表
  Future<List<String>> getAllGlasswareNames() async {
    try {
      final response = await _client.from('onecup_glassware').select('name').order('name');
      return response.map((map) => map['name'] as String).toList();
    } catch (e) {
      if (kDebugMode) print('获取所有杯具名称失败: $e');
      return [];
    }
  }
  /// 添加一个由用户自定义的新配方，严格遵循数据库结构。
  ///
  /// 调用一个数据库事务函数 (RPC: add_recipe_with_ingredients) 来确保所有
  /// 操作（插入配方、插入配料、关联杯具）要么全部成功，要么全部失败。
  ///
  /// @param recipe 包含配方基本信息的 Recipe 对象。
  /// @param ingredients 一个 RecipeIngredient 对象的列表。
  /// @return 返回新创建配方的 ID，如果创建失败则返回 null。
  Future<int?> addCustomRecipe(Recipe recipe, List<RecipeIngredient> ingredients) async {
    final userId = _currentUserId;
    if (userId == null) {
      if (kDebugMode) print('错误: 用户未登录，无法添加自定义配方。');
      return null;
    }

    try {
      // 1. 准备数据：将前端的用户输入（如配料名称、杯具名称）转换为数据库所需的ID

      // 获取所有需要的配料ID
      final ingredientNames = ingredients.map((i) => i.name).toList();
      final ingredientsResponse = await _client
          .from('onecup_ingredients')
          .select('id, name')
          .inFilter('name', ingredientNames);

      final ingredientIdMap = {for (var ing in ingredientsResponse) ing['name']: ing['id']};

      // 检查是否有配料在数据库中不存在
      for (var ing in ingredients) {
        if (!ingredientIdMap.containsKey(ing.name)) {
          throw Exception('数据库中找不到配料: "${ing.name}"。请确保所有配料都存在。');
        }
      }

      // 获取分类ID (假设'我的创作'分类已存在于onecup_recipe_categories表中)
      final categoryResponse = await _client.from('onecup_recipe_categories').select('id').eq('name', '我的创作').single();
      final categoryId = categoryResponse['id'];

      // 获取杯具ID
      final glassResponse = await _client.from('onecup_glassware').select('id').eq('name', recipe.glass!).single();
      final glassId = glassResponse['id'];

      // 2. 调用RPC函数，将所有准备好的数据一次性传给数据库
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
        // 将配料列表转换为数据库函数所需的JSONB数组格式
        'p_ingredients': ingredients.map((ing) => {
          'ingredient_id': ingredientIdMap[ing.name],
          'display_name': ing.name, // 存储原始显示名称
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
      // 向用户返回一个更友好的错误信息
      throw Exception('保存配方失败，请检查数据或稍后再试。错误: $e');
    }
  }
  Future<List<Recipe>> getFlavorBasedRecommendations({int limit = 10}) async {
    final userId = _currentUserId;
    if (userId == null) return [];
    try {
      final response = await _client.rpc('get_flavor_based_recommendations', params: {'p_user_id': userId, 'p_limit': limit});
      return (response as List).map((map) => Recipe.fromMap(map)).toList();
    } catch (e) {
      if (kDebugMode) print('获取口味推荐失败: $e');
      return [];
    }
  }

  Future<Map<String, List<String>>> getInventoryByCategory() async {
    final userId = _currentUserId;
    if (userId == null) return {};
    try {
      // 由于没有外键，我们需要分两步
      // 1. 获取用户库存中所有的 ingredient_id
      final inventoryResponse = await _client.from('onecup_user_inventory').select('ingredient_id').eq('user_id', userId);
      if (inventoryResponse.isEmpty) return {};
      final ingredientIds = inventoryResponse.map((row) => row['ingredient_id']).toList();

      // 2. 获取这些配料的详细信息，并手动 JOIN 分类
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

  Future<int?> getIngredientIdByName(String name) async {
    try {
      final response = await _client
          .from('onecup_ingredients')
          .select('id')
          .eq('name', name)
          .maybeSingle();
      return response?['id'];
    } catch(e) {
      if (kDebugMode) print('按名称获取配料ID失败: $e');
      return null;
    }
  }
  // TODO:
  Future<List<Map<String, dynamic>>> getPurchaseRecommendations() async {
    // 此功能的逻辑在客户端实现会非常低效，因为它需要下载整个配方-配料关系表。
    // 强烈建议也将其创建为一个数据库函数 (RPC)。
    // 这里暂时提供一个简化的客户端实现作为参考。
    final userId = _currentUserId;
    if (userId == null) return [];

    // 这是一个非常耗费资源的查询，仅作演示
    try {
      final inventoryIds = await getUserInventoryIds();
      if (inventoryIds.isEmpty) return [];

      // 理论上应该调用一个 RPC
      // final response = await _client.rpc('get_purchase_recommendations', params: {'p_user_id': userId});
      // return List<Map<String, dynamic>>.from(response);

      // 暂时返回空，以避免客户端性能问题
      if (kDebugMode) print('警告: getPurchaseRecommendations 应该在数据库函数中实现以获得最佳性能。');
      return [];

    } catch (e) {
      if (kDebugMode) print('获取购买建议失败: $e');
      return [];
    }
  }
  Future<List<Recipe>> getRecipesWithNotes() async {
    final userId = _currentUserId;
    if (userId == null) return [];
    try {
      // 先获取带有笔记的 recipe_id
      final notesResponse = await _client
          .from('onecup_user_recipe_notes')
          .select('recipe_id')
          .eq('user_id', userId);

      if (notesResponse.isEmpty) return [];

      final recipeIds = notesResponse.map((map) => map['recipe_id']).toList();

      // 然后使用这些ID去我们高效的视图中查询详情
      // [核心修正] 将 .in_() 替换为 .inFilter()
      final response = await _client
          .from('v_recipes_with_details')
          .select()
          .inFilter('id', recipeIds) // <-- 此处已修正
          .order('name', ascending: true);

      return response.map((map) => Recipe.fromMap(map)).toList();
    } catch(e) {
      if (kDebugMode) print('获取带笔记的配方失败: $e');
      return [];
    }
  }

  Future<Recipe?> getRecipeById(int recipeId) async {
    try {
      final response = await _client
          .from('v_recipes_with_details')
          .select()
          .eq('id', recipeId)
          .single();
      return Recipe.fromMap(response);
    } catch (e) {
      print('Error fetching recipe by id: $e');
      return null;
    }
  }
}