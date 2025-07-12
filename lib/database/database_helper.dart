import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:onecup/models/receip.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'cocktails.db');
    // For development, deleting the database ensures onCreate is called on every launch
    // await deleteDatabase(path);
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // The table creation statements remain the same as before.
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE Sources (
          source_id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE
      );
    ''');
    batch.execute('''
      CREATE TABLE Glassware (
          glass_id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE
      );
    ''');
    batch.execute('''
      CREATE TABLE Ingredients (
          ingredient_id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          category_id INTEGER,
          FOREIGN KEY (category_id) REFERENCES IngredientCategories (category_id)
      );
    ''');
    batch.execute('''
      CREATE TABLE IngredientCategories (
        category_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      );
    ''');
    batch.execute('''
      CREATE TABLE Recipes (
          recipe_id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT,
          instructions TEXT,
          image_path TEXT,
          glass_id INTEGER,
          source_id INTEGER,
          category TEXT,
          FOREIGN KEY (glass_id) REFERENCES Glassware (glass_id),
          FOREIGN KEY (source_id) REFERENCES Sources (source_id)
      );
    ''');
    batch.execute('''
      CREATE TABLE Recipe_Ingredients (
          recipe_id INTEGER NOT NULL,
          ingredient_id INTEGER NOT NULL,
          amount TEXT,
          unit TEXT,
          is_optional BOOLEAN DEFAULT 0,
          PRIMARY KEY (recipe_id, ingredient_id),
          FOREIGN KEY (recipe_id) REFERENCES Recipes (recipe_id),
          FOREIGN KEY (ingredient_id) REFERENCES Ingredients (ingredient_id)
      );
    ''');
    batch.execute('''
      CREATE TABLE Users (
          user_id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL UNIQUE
      );
    ''');
    batch.execute('''
      CREATE TABLE User_Inventory (
          user_id INTEGER NOT NULL,
          ingredient_id INTEGER NOT NULL,
          PRIMARY KEY (user_id, ingredient_id),
          FOREIGN KEY (user_id) REFERENCES Users (user_id),
          FOREIGN KEY (ingredient_id) REFERENCES Ingredients (ingredient_id)
      );
    ''');

    //创建购物清单表
    batch.execute('''
      CREATE TABLE ShoppingList (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          checked INTEGER NOT NULL DEFAULT 0
      );
    ''');

    //  风味标签相关表 (符合蓝图第2章设计)
    batch.execute('''
      CREATE TABLE Tags (
        tag_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      );
    ''');
    batch.execute('''
      CREATE TABLE Recipe_Tags (
        recipe_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY (recipe_id, tag_id),
        FOREIGN KEY (recipe_id) REFERENCES Recipes (recipe_id),
        FOREIGN KEY (tag_id) REFERENCES Tags (tag_id)
      );
    ''');
    batch.execute('''
      CREATE TABLE User_Favorites (
        user_id INTEGER NOT NULL,
        recipe_id INTEGER NOT NULL,
        PRIMARY KEY (user_id, recipe_id),
        FOREIGN KEY (user_id) REFERENCES Users (user_id),
        FOREIGN KEY (recipe_id) REFERENCES Recipes (recipe_id)
      );
    ''');

    await batch.commit(noResult: true);
    await db.insert('Users', {'user_id': 1, 'username': 'default_user'});
    await _populateDataFromAsset(db);
  }

  // FIX: This function is now fully data-driven by the JSON files.
  Future<void> _populateDataFromAsset(Database db) async {
    await db.transaction((txn) async {
      // 1. Load all necessary JSON data
      final cocktailsResponse = await rootBundle.loadString('assets/json/cocktails-cn.json');
      final ingredientsCnResponse = await rootBundle.loadString('assets/json/ingredients-cn.json');
      final glassesCnResponse = await rootBundle.loadString('assets/json/glasses-cn.json');

      final List<dynamic> cocktailsData = json.decode(cocktailsResponse);
      final Map<String, dynamic> ingredientsCnData = json.decode(ingredientsCnResponse);
      final Map<String, dynamic> glassesCnData = json.decode(glassesCnResponse);

      // 2. Dynamically discover and insert categories from ingredients-cn.json
      final categorySet = <String>{};
      for (var entry in ingredientsCnData.entries) {
        if (entry.value['category'] != null) {
          categorySet.add(entry.value['category']);
        } else {
          categorySet.add('未分类'); // Default category
        }
      }

      final categoryMap = <String, int>{};
      for (var catName in categorySet) {
        final id = await txn.insert('IngredientCategories', {'name': catName}, conflictAlgorithm: ConflictAlgorithm.ignore);
        final result = await txn.query('IngredientCategories', where: 'name = ?', whereArgs: [catName]);
        categoryMap[catName] = result.first['category_id'] as int;
      }

      // 3. Insert all ingredients and link them to their categories
      final ingredientMap = <String, int>{};
      final ingredientToTasteMap = <int, String?>{};
      final tasteSet = <String>{};

      for (var entry in ingredientsCnData.entries) {
        final String ingredientName = entry.value['ingredient'];
        final String categoryName = entry.value['category'] ?? '未分类';
        final String? taste = entry.value['taste'];

        if (taste != null) {
          tasteSet.add(taste);
        }

        if (!ingredientMap.containsKey(ingredientName)) {
          final categoryId = categoryMap[categoryName];
          final id = await txn.insert('Ingredients', {'name': ingredientName, 'category_id': categoryId}, conflictAlgorithm: ConflictAlgorithm.ignore);
          final result = await txn.query('Ingredients', where: 'name = ?', whereArgs: [ingredientName]);
          final newId = result.first['ingredient_id'] as int;
          ingredientMap[ingredientName] = newId;
          ingredientToTasteMap[newId] = taste;
        }
      }

      // 4. Insert glassware
      final glassMap = <String, int>{};
      for (var entry in glassesCnData.entries) {
        await txn.insert('Glassware', {'name': entry.value['name']}, conflictAlgorithm: ConflictAlgorithm.ignore);
        final result = await txn.query('Glassware', where: 'name = ?', whereArgs: [entry.value['name']]);
        glassMap[entry.value['name']] = result.first['glass_id'] as int;
      }

      // 填充Tags表
      final tagMap = <String, int>{};
      for (var tasteName in tasteSet) {
        await txn.insert('Tags', {'name': tasteName}, conflictAlgorithm: ConflictAlgorithm.ignore);
        final result = await txn.query('Tags', where: 'name = ?', whereArgs: [tasteName]);
        tagMap[tasteName] = result.first['tag_id'] as int;
      }

      // 5. Insert sources and recipes
      final sourceIdResult = await txn.query('Sources', where: 'name = ?', whereArgs: ['IBA官方']);
      int sourceId;
      if (sourceIdResult.isEmpty) {
        sourceId = await txn.insert('Sources', {'name': 'IBA官方'});
      } else {
        sourceId = sourceIdResult.first['source_id'] as int;
      }
      for (var cocktail in cocktailsData) {
        final recipeId = await txn.insert('Recipes', {
          'name': cocktail['name'],
          'instructions': cocktail['preparation'],
          'category': cocktail['category'],
          'glass_id': glassMap[cocktail['glass']],
          'source_id': sourceId,
          'description': cocktail['garnish'] != null ? '装饰: ${cocktail['garnish']}' : null,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        final recipeTags = <String>{};
        for (var ingredientData in cocktail['ingredients']) {
          final uniqueName = ingredientData['label'] ?? ingredientData['ingredient'];
          final ingredientId = ingredientMap[uniqueName];

          if (uniqueName != null && ingredientId != null) {
            await txn.insert('Recipe_Ingredients', {
              'recipe_id': recipeId,
              'ingredient_id': ingredientId,
              'amount': ingredientData['amount']?.toString(),
              'unit': ingredientData['unit'],
            }, conflictAlgorithm: ConflictAlgorithm.replace);

            // [新增] 关联配方的风味标签
            final taste = ingredientToTasteMap[ingredientId];
            if (taste != null) {
              recipeTags.add(taste);
            }
          }
        }

        for (var tagName in recipeTags) {
          final tagId = tagMap[tagName];
          if (tagId != null) {
            await txn.insert('Recipe_Tags', {
              'recipe_id': recipeId,
              'tag_id': tagId,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
      }
    });
  }

  // The rest of the methods (getAllRecipes, getUserInventoryIds, etc.) remain unchanged.
  Future<List<Recipe>> getAllRecipes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        r.recipe_id, r.name, r.description, r.instructions, 
        r.image_path, r.category, g.name as glass
      FROM Recipes r
      LEFT JOIN Glassware g ON r.glass_id = g.glass_id
      ORDER BY r.name
    ''');
    return List.generate(maps.length, (i) => Recipe.fromMap(maps[i]));
  }

  Future<Set<int>> getUserInventoryIds() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'User_Inventory',
      columns: ['ingredient_id'],
      where: 'user_id = ?',
      whereArgs: [1],
    );
    return maps.map((e) => e['ingredient_id'] as int).toSet();
  }

  Future<List<Map<String, dynamic>>> getIngredientsForBarManagement() async {
    final db = await database;
    final inventoryIds = await getUserInventoryIds();

    final List<Map<String, dynamic>> allIngredients = await db.rawQuery('''
      SELECT 
        i.ingredient_id, i.name, c.name as category_name
      FROM Ingredients i
      LEFT JOIN IngredientCategories c ON i.category_id = c.category_id
      ORDER BY c.name, i.name
    ''');

    return allIngredients.map((ingredient) {
      return {
        'id': ingredient['ingredient_id'],
        'name': ingredient['name'],
        'category': ingredient['category_name'] ?? '未分类',
        'in_inventory': inventoryIds.contains(ingredient['ingredient_id']),
      };
    }).toList();
  }

  Future<void> addIngredientToInventory(int ingredientId) async {
    final db = await database;
    await db.insert(
      'User_Inventory',
      {'user_id': 1, 'ingredient_id': ingredientId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeIngredientFromInventory(int ingredientId) async {
    final db = await database;
    await db.delete(
      'User_Inventory',
      where: 'user_id = ? AND ingredient_id = ?',
      whereArgs: [1, ingredientId],
    );
  }

  Future<List<int>> getIngredientIdsForRecipe(int recipeId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
        'Recipe_Ingredients',
        columns: ['ingredient_id'],
        where: 'recipe_id = ?',
        whereArgs: [recipeId]);
    return maps.map((e) => e['ingredient_id'] as int).toList();
  }
  // -------------------------购物清单--------------------------------//
  //获取购物清单所有项目
  Future<List<Map<String, dynamic>>> getShoppingList() async {
    final db = await database;
    return await db.query('ShoppingList', orderBy: 'id DESC');
  }

  //向购物清单添加一个项目
  Future<void> addToShoppingList(String name) async {
    final db = await database;
    await db.insert(
      'ShoppingList',
      {'name': name, 'checked': 0},
      conflictAlgorithm: ConflictAlgorithm.ignore, // 如果已存在同名项，则忽略
    );
  }

  //更新购物清单项目的勾选状态
  Future<void> updateShoppingListItem(int id, bool isChecked) async {
    final db = await database;
    await db.update(
      'ShoppingList',
      {'checked': isChecked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  //从购物清单移除一个项目
  Future<void> removeFromShoppingList(int id) async {
    final db = await database;
    await db.delete(
      'ShoppingList',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  //根据配方ID获取其所有配料的详细信息
  Future<List<Map<String, dynamic>>> getIngredientsForRecipe(int recipeId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        i.name,
        ri.amount,
        ri.unit
      FROM Recipe_Ingredients ri
      JOIN Ingredients i ON ri.ingredient_id = i.ingredient_id
      WHERE ri.recipe_id = ?
    ''', [recipeId]);
  }

  //"智能调酒师"核心算法
  Future<List<Map<String, dynamic>>> getPurchaseRecommendations() async {
    final db = await database;
    final userInventoryIds = await getUserInventoryIds(); // 用户现有库存

    // 获取所有配方及其所需配料
    final List<Map<String, dynamic>> allRecipeIngredients = await db.query('Recipe_Ingredients');

    // 按 recipe_id 分组
    final Map<int, List<int>> recipesWithIngredients = {};
    for (var row in allRecipeIngredients) {
      final recipeId = row['recipe_id'] as int;
      final ingredientId = row['ingredient_id'] as int;
      if (!recipesWithIngredients.containsKey(recipeId)) {
        recipesWithIngredients[recipeId] = [];
      }
      recipesWithIngredients[recipeId]!.add(ingredientId);
    }

    // 计算每种缺失配料的“解锁”分数 [cite: 313]
    final Map<int, double> missingIngredientsScore = {};
    recipesWithIngredients.forEach((recipeId, requiredIds) {
      final needed = requiredIds.toSet();
      final missing = needed.difference(userInventoryIds); // 计算缺失的配料 [cite: 316]

      if (missing.length == 1) { // 仅缺1种 [cite: 317]
        final ingredientToBuy = missing.first;
        missingIngredientsScore[ingredientToBuy] = (missingIngredientsScore[ingredientToBuy] ?? 0) + 1.0; // 分数+1.0 [cite: 318]
      } else if (missing.length == 2) { // 仅缺2种 [cite: 319]
        for (var ingredientToBuy in missing) {
          missingIngredientsScore[ingredientToBuy] = (missingIngredientsScore[ingredientToBuy] ?? 0) + 0.4; // 分数+0.4 [cite: 320]
        }
      }
    });

    // 获取得分最高配料的详细信息
    if (missingIngredientsScore.isEmpty) {
      return [];
    }

    // 按分数排序
    final sortedScores = missingIngredientsScore.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topRecommendations = sortedScores.take(10).toList(); // 取前10个

    final List<Map<String, dynamic>> results = [];
    for (var entry in topRecommendations) {
      final ingredientId = entry.key;
      final score = entry.value;

      // 获取配料名称
      final List<Map<String, dynamic>> ingredientInfo = await db.query(
        'Ingredients',
        columns: ['name'],
        where: 'ingredient_id = ?',
        whereArgs: [ingredientId],
      );

      if (ingredientInfo.isNotEmpty) {
        // 计算购买此配料后能解锁多少新配方
        int unlockedCount = 0;
        recipesWithIngredients.forEach((recipeId, requiredIds) {
          final needed = requiredIds.toSet();
          final missing = needed.difference(userInventoryIds);
          if (missing.length == 1 && missing.first == ingredientId) {
            unlockedCount++;
          }
        });

        results.add({
          'name': ingredientInfo.first['name'],
          'unlocks': unlockedCount,
        });
      }
    }
    return results;
  }

  // [新增] 收藏夹相关方法
  Future<void> addRecipeToFavorites(int recipeId, {int userId = 1}) async {
    final db = await database;
    await db.insert(
      'User_Favorites',
      {'user_id': userId, 'recipe_id': recipeId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeRecipeFromFavorites(int recipeId, {int userId = 1}) async {
    final db = await database;
    await db.delete(
      'User_Favorites',
      where: 'user_id = ? AND recipe_id = ?',
      whereArgs: [userId, recipeId],
    );
  }

  Future<bool> isRecipeFavorite(int recipeId, {int userId = 1}) async {
    final db = await database;
    final result = await db.query(
      'User_Favorites',
      where: 'user_id = ? AND recipe_id = ?',
      whereArgs: [userId, recipeId],
    );
    return result.isNotEmpty;
  }

  // [新增] 获取配方风味标签
  Future<List<String>> getRecipeTags(int recipeId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
          SELECT T.name FROM Tags T
          JOIN Recipe_Tags RT ON T.tag_id = RT.tag_id
          WHERE RT.recipe_id = ?
      ''', [recipeId]);
    if (maps.isEmpty) return [];
    return maps.map((map) => map['name'] as String).toList();
  }

  // [新增] 获取基于风味的推荐
  Future<List<Recipe>> getFlavorBasedRecommendations({int userId = 1, int limit = 10}) async {
    final db = await database;
    // 1. 获取用户收藏的所有配方及其标签
    final List<Map<String, dynamic>> favoriteTagsData = await db.rawQuery('''
      SELECT DISTINCT RT.tag_id FROM User_Favorites UF
      JOIN Recipe_Tags RT ON UF.recipe_id = RT.recipe_id
      WHERE UF.user_id = ?
    ''', [userId]);

    if (favoriteTagsData.isEmpty) {
      return []; // 如果没有收藏，则无法推荐
    }
    final favoriteTagIds = favoriteTagsData.map((map) => map['tag_id'] as int).toList();

    // 2. 找到与用户喜欢的标签匹配的其他配方，并排除已收藏的
    final List<Map<String, dynamic>> recommendedRecipesData = await db.rawQuery('''
      SELECT R.*, G.name as glass, COUNT(RT.tag_id) as match_score
      FROM Recipes R
      JOIN Recipe_Tags RT ON R.recipe_id = RT.recipe_id
      LEFT JOIN Glassware G ON R.glass_id = G.glass_id
      WHERE RT.tag_id IN (${favoriteTagIds.map((_) => '?').join(',')})
        AND R.recipe_id NOT IN (SELECT recipe_id FROM User_Favorites WHERE user_id = ?)
      GROUP BY R.recipe_id
      ORDER BY match_score DESC
      LIMIT ?
    ''', [...favoriteTagIds, userId, limit]);

    return recommendedRecipesData.map((map) => Recipe.fromMap(map)).toList();
  }
  // [新增] 获取用户收藏的所有配方
  Future<List<Recipe>> getFavoriteRecipes({int userId = 1}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT R.*, G.name as glass FROM Recipes R
      JOIN User_Favorites UF ON R.recipe_id = UF.recipe_id
      LEFT JOIN Glassware G ON R.glass_id = G.glass_id
      WHERE UF.user_id = ?
      ORDER BY R.name
    ''', [userId]);
    return maps.map((map) => Recipe.fromMap(map)).toList();
  }

  // [新增] 将配方的所有配料批量添加到购物清单
  Future<void> addRecipeIngredientsToShoppingList(int recipeId) async {
    final db = await database;
    final ingredients = await getIngredientsForRecipe(recipeId);
    final batch = db.batch();
    for (var ingredient in ingredients) {
      batch.insert(
        'ShoppingList',
        {'name': ingredient['name'], 'checked': 0},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }
}