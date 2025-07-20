// lib/database/database_helper.dart

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
    // 开发时可以取消注释下面这行来强制刷新数据库
    // await deleteDatabase(path);
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    final batch = db.batch();
    batch.execute('DROP TABLE IF EXISTS User_Favorites');
    batch.execute('DROP TABLE IF EXISTS Recipe_Tags');
    batch.execute('DROP TABLE IF EXISTS Tags');
    batch.execute('DROP TABLE IF EXISTS ShoppingList');
    batch.execute('DROP TABLE IF EXISTS User_Inventory');
    batch.execute('DROP TABLE IF EXISTS Users');
    batch.execute('DROP TABLE IF EXISTS Recipe_Ingredients');
    batch.execute('DROP TABLE IF EXISTS Recipes');
    batch.execute('DROP TABLE IF EXISTS Ingredients');
    batch.execute('DROP TABLE IF EXISTS IngredientCategories');
    batch.execute('DROP TABLE IF EXISTS Glassware');
    batch.execute('DROP TABLE IF EXISTS Sources');
    await batch.commit();
    await _onCreate(db, newVersion);
  }

  Future<void> _onCreate(Database db, int version) async {
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
      CREATE TABLE IngredientCategories (
        category_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      );
    ''');
    batch.execute('''
      CREATE TABLE Ingredients (
          ingredient_id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          category_id INTEGER,
          abv REAL,
          FOREIGN KEY (category_id) REFERENCES IngredientCategories (category_id)
      );
    ''');
    batch.execute('''
      CREATE TABLE Users (
          user_id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL UNIQUE
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
          user_id INTEGER, 
          FOREIGN KEY (glass_id) REFERENCES Glassware (glass_id),
          FOREIGN KEY (source_id) REFERENCES Sources (source_id),
          FOREIGN KEY (user_id) REFERENCES Users(user_id)
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
      CREATE TABLE User_Inventory (
          user_id INTEGER NOT NULL,
          ingredient_id INTEGER NOT NULL,
          PRIMARY KEY (user_id, ingredient_id),
          FOREIGN KEY (user_id) REFERENCES Users (user_id),
          FOREIGN KEY (ingredient_id) REFERENCES Ingredients (ingredient_id)
      );
    ''');
    batch.execute('''
      CREATE TABLE ShoppingList (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          checked INTEGER NOT NULL DEFAULT 0
      );
    ''');
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

    batch.execute('''
      CREATE TABLE User_Recipe_Notes (
        user_id INTEGER NOT NULL,
        recipe_id INTEGER NOT NULL,
        notes TEXT NOT NULL,
        PRIMARY KEY (user_id, recipe_id),
        FOREIGN KEY (user_id) REFERENCES Users (user_id),
        FOREIGN KEY (recipe_id) REFERENCES Recipes (recipe_id)
      );
    ''');
    await batch.commit(noResult: true);
    await db.insert('Users', {'user_id': 1, 'username': 'default_user'});
    await _populateDataFromAsset(db);
  }

  Future<List<Recipe>> getFlavorBasedRecommendations({int userId = 1, int limit = 10}) async {
    final db = await database;

    final List<Map<String, dynamic>> tasteProfileData = await db.rawQuery('''
      SELECT RT.tag_id, COUNT(RT.tag_id) as tag_weight
      FROM User_Favorites UF
      JOIN Recipe_Tags RT ON UF.recipe_id = RT.recipe_id
      WHERE UF.user_id = ?
      GROUP BY RT.tag_id
    ''', [userId]);

    // [核心修复] 如果用户没有任何收藏，直接返回一个空列表。
    // 不再调用 getPopularRecipes 作为备选方案。
    if (tasteProfileData.isEmpty) {
      return [];
    }

    // 后续的推荐逻辑保持不变...
    final tasteProfile = {for (var map in tasteProfileData) map['tag_id'] as int: map['tag_weight'] as int};
    final favoriteTagIds = tasteProfile.keys.toList();

    // 检查tasteProfile是否为空，避免SQL语法错误
    if (tasteProfile.isEmpty) {
      return [];
    }

    final List<Map<String, dynamic>> recommendedRecipesData = await db.rawQuery('''
      SELECT 
        R.*, 
        G.name as glass, 
        SUM(CASE WHEN RT.tag_id IN (${favoriteTagIds.map((_) => '?').join(',')}) THEN TASTE_PROFILE.tag_weight ELSE 0 END) as match_score
      FROM Recipes R
      JOIN Recipe_Tags RT ON R.recipe_id = RT.recipe_id
      LEFT JOIN Glassware G ON R.glass_id = G.glass_id
      JOIN (
        SELECT ? as tag_id, ? as tag_weight
        ${'UNION ALL SELECT ?, ?' * (tasteProfile.length - 1)}
      ) AS TASTE_PROFILE ON RT.tag_id = TASTE_PROFILE.tag_id
      WHERE R.recipe_id NOT IN (SELECT recipe_id FROM User_Favorites WHERE user_id = ?)
      GROUP BY R.recipe_id
      ORDER BY match_score DESC
      LIMIT ?
    ''', [
      ...favoriteTagIds,
      ...tasteProfile.entries.expand((e) => [e.key, e.value]).toList(),
      userId,
      limit
    ]);

    return recommendedRecipesData.map((map) => Recipe.fromMap(map)).toList();
  }

  Future<void> _populateDataFromAsset(Database db) async {
    await db.transaction((txn) async {
      final cocktailsResponse = await rootBundle.loadString('assets/json/cocktails-cn.json');
      // [核心升级] 确保加载包含ABV数据的新JSON文件
      final ingredientsCnResponse = await rootBundle.loadString('assets/json/ingredients-cn-with-abv.json');
      final glassesCnResponse = await rootBundle.loadString('assets/json/glasses-cn.json');

      final List<dynamic> cocktailsData = json.decode(cocktailsResponse);
      final Map<String, dynamic> ingredientsCnData = json.decode(ingredientsCnResponse);
      final Map<String, dynamic> glassesCnData = json.decode(glassesCnResponse);

      final categoryMap = <String, int>{};
      final ingredientMap = <String, int>{};
      final ingredientToTasteMap = <int, String?>{};
      final tasteSet = <String>{};
      final glassMap = <String, int>{};
      final tagMap = <String, int>{};

      final categorySet = ingredientsCnData.values.map((v) => v['category'] ?? '未分类').toSet();
      for (var catName in categorySet) {
        final result = await txn.query('IngredientCategories', where: 'name = ?', whereArgs: [catName]);
        if (result.isEmpty) {
          final id = await txn.insert('IngredientCategories', {'name': catName});
          categoryMap[catName] = id;
        } else {
          categoryMap[catName] = result.first['category_id'] as int;
        }
      }

      for (var entry in ingredientsCnData.entries) {
        final String ingredientName = entry.value['ingredient'];
        final String categoryName = entry.value['category'] ?? '未分类';
        final String? taste = entry.value['taste'];
        // [核心升级] 读取ABV值
        final num? abv = entry.value['abv'];
        if (taste != null) tasteSet.add(taste);

        final result = await txn.query('Ingredients', where: 'name = ?', whereArgs: [ingredientName]);
        if (result.isEmpty) {
          final categoryId = categoryMap[categoryName];
          // [核心升级] 插入时包含ABV
          final id = await txn.insert('Ingredients', {'name': ingredientName, 'category_id': categoryId, 'abv': abv});
          ingredientMap[ingredientName] = id;
          ingredientToTasteMap[id] = taste;
        } else {
          final id = result.first['ingredient_id'] as int;
          ingredientMap[ingredientName] = id;
          ingredientToTasteMap[id] = taste;
        }
      }

      for (var entry in glassesCnData.values) {
        final name = entry['name'];
        final result = await txn.query('Glassware', where: 'name = ?', whereArgs: [name]);
        if (result.isEmpty) {
          final id = await txn.insert('Glassware', {'name': name});
          glassMap[name] = id;
        } else {
          glassMap[name] = result.first['glass_id'] as int;
        }
      }

      for (var tasteName in tasteSet) {
        final result = await txn.query('Tags', where: 'name = ?', whereArgs: [tasteName]);
        if (result.isEmpty) {
          final id = await txn.insert('Tags', {'name': tasteName});
          tagMap[tasteName] = id;
        } else {
          tagMap[tasteName] = result.first['tag_id'] as int;
        }
      }

      final sourceResult = await txn.query('Sources', where: 'name = ?', whereArgs: ['IBA官方']);
      int sourceId = sourceResult.isNotEmpty
          ? sourceResult.first['source_id'] as int
          : await txn.insert('Sources', {'name': 'IBA官方'});

      for (var cocktail in cocktailsData) {
        final detail = cocktail['detail'];
        final recipeId = await txn.insert('Recipes', {
          'name': cocktail['title'],
          'instructions': (detail['preparation'] as List<dynamic>).join('\n'),
          'category': cocktail['category'],
          'glass_id': glassMap[detail['receptacle']],
          'source_id': sourceId,
          'description': (detail['decorated'] as List<dynamic>).join('\n'),
          'image_path': detail['img'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        final recipeTags = <String>{};
        for (var ingredientData in detail['ingredients']) {
          final String rawIngredientName = ingredientData['ingredient'];

          String? matchedKey = ingredientMap.keys.firstWhere(
                (k) => rawIngredientName.toLowerCase().contains(k.toLowerCase()),
            orElse: () => '',
          );

          if (matchedKey.isNotEmpty) {
            final ingredientId = ingredientMap[matchedKey];
            if (ingredientId != null) {
              await txn.insert('Recipe_Ingredients', {
                'recipe_id': recipeId,
                'ingredient_id': ingredientId,
                'amount': ingredientData['count']?.toString(),
                'unit': ingredientData['unit'],
              }, conflictAlgorithm: ConflictAlgorithm.replace);

              final taste = ingredientToTasteMap[ingredientId];
              if (taste != null) recipeTags.add(taste);
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

  Future<List<Recipe>> getAllRecipes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        r.recipe_id, r.name, r.description, r.instructions, 
        r.image_path, r.category, g.name as glass, r.user_id
      FROM Recipes r
      LEFT JOIN Glassware g ON r.glass_id = g.glass_id
      ORDER BY r.name
    ''');
    return List.generate(maps.length, (i) => Recipe.fromMap(maps[i]));
  }

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

  Future<List<Map<String, dynamic>>> getShoppingList() async {
    final db = await database;
    return await db.query('ShoppingList', orderBy: 'id DESC');
  }

  Future<void> addToShoppingList(String name) async {
    final db = await database;
    await db.insert(
      'ShoppingList',
      {'name': name, 'checked': 0},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> updateShoppingListItem(int id, bool isChecked) async {
    final db = await database;
    await db.update(
      'ShoppingList',
      {'checked': isChecked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> removeFromShoppingList(int id) async {
    final db = await database;
    await db.delete(
      'ShoppingList',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // [新功能] 清除所有已完成的购物清单项目
  Future<void> clearCompletedShoppingItems() async {
    final db = await database;
    await db.delete(
      'ShoppingList',
      where: 'checked = ?',
      whereArgs: [1], // 删除所有 'checked' 字段为 1 的记录
    );
  }

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

  Future<List<Map<String, dynamic>>> getPurchaseRecommendations() async {
    final db = await database;
    final userInventoryIds = await getUserInventoryIds();

    // 如果用户库存为空，则提前返回，避免不必要的计算
    if (userInventoryIds.isEmpty) {
      return [];
    }

    final List<Map<String, dynamic>> allRecipeIngredients = await db.query('Recipe_Ingredients');

    final Map<int, List<int>> recipesWithIngredients = {};
    for (var row in allRecipeIngredients) {
      final recipeId = row['recipe_id'] as int;
      final ingredientId = row['ingredient_id'] as int;
      if (!recipesWithIngredients.containsKey(recipeId)) {
        recipesWithIngredients[recipeId] = [];
      }
      recipesWithIngredients[recipeId]!.add(ingredientId);
    }

    final Map<int, double> missingIngredientsScore = {};
    recipesWithIngredients.forEach((recipeId, requiredIds) {
      final needed = requiredIds.toSet();
      final missing = needed.difference(userInventoryIds);

      // 仅在缺少1或2种配料时才计算得分
      if (missing.length == 1) {
        final ingredientToBuy = missing.first;
        missingIngredientsScore[ingredientToBuy] = (missingIngredientsScore[ingredientToBuy] ?? 0) + 1.0;
      } else if (missing.length == 2) {
        for (var ingredientToBuy in missing) {
          missingIngredientsScore[ingredientToBuy] = (missingIngredientsScore[ingredientToBuy] ?? 0) + 0.4;
        }
      }
    });

    if (missingIngredientsScore.isEmpty) {
      return [];
    }

    // 初步排序保持不变，用于选出最相关的候选项
    final sortedScores = missingIngredientsScore.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topRecommendations = sortedScores.take(10).toList();

    final List<Map<String, dynamic>> results = [];
    for (var entry in topRecommendations) {
      final ingredientId = entry.key;

      final List<Map<String, dynamic>> ingredientInfo = await db.query(
        'Ingredients',
        columns: ['name'],
        where: 'ingredient_id = ?',
        whereArgs: [ingredientId],
      );

      if (ingredientInfo.isNotEmpty) {
        int unlockedCount = 0;
        recipesWithIngredients.forEach((recipeId, requiredIds) {
          final needed = requiredIds.toSet();
          final missing = needed.difference(userInventoryIds);
          if (missing.length == 1 && missing.first == ingredientId) {
            unlockedCount++;
          }
        });

        if (unlockedCount > 0) {
          results.add({
            'name': ingredientInfo.first['name'],
            'unlocks': unlockedCount,
          });
        }
      }
    }

    // [核心优化] 在返回结果前，根据“解锁配方数”进行最终排序
    results.sort((a, b) => (b['unlocks'] as int).compareTo(a['unlocks'] as int));

    return results;
  }

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
  Future<void> addCustomRecipe(Recipe recipe, {int userId = 1}) async {
    final db = await database;
    await db.insert(
      'Recipes',
      {
        'name': recipe.name,
        'description': recipe.description,
        'instructions': recipe.instructions,
        'category': recipe.category,
        'glass': recipe.glass,
        'user_id': userId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Recipe>> getPopularRecipes({int limit = 10, int userId = 1}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT
        R.*,
        G.name as glass,
        (SELECT COUNT(*) FROM User_Favorites WHERE recipe_id = R.recipe_id) as favorite_count
      FROM Recipes R
      LEFT JOIN Glassware G ON R.glass_id = G.glass_id
      WHERE R.recipe_id NOT IN (SELECT recipe_id FROM User_Favorites WHERE user_id = ?)
      ORDER BY favorite_count DESC
      LIMIT ?
    ''', [userId, limit]);

    return maps.map((map) => Recipe.fromMap(map)).toList();
  }

  // 获取所有用户自己创建的配方
  Future<List<Recipe>> getUserCreatedRecipes({int userId = 1}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT R.*, G.name as glass FROM Recipes R
      LEFT JOIN Glassware G ON R.glass_id = G.glass_id
      WHERE R.user_id = ?
      ORDER BY R.recipe_id DESC
    ''', [userId]);
    return maps.map((map) => Recipe.fromMap(map)).toList();
  }

  // 重写“即刻可调”的查询逻辑
  Future<List<Recipe>> getMakeableRecipes({int userId = 1}) async {
    final db = await database;

    // 1. 首先检查用户库存是否为空
    final inventoryCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM User_Inventory WHERE user_id = ?', [userId]));
    if (inventoryCount == 0) {
      return []; // 如果库存为空，直接返回空列表
    }

    // 2. 只有在库存不为空时，才执行原来的查询
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT R.*, G.name as glass FROM Recipes R
      LEFT JOIN Glassware G ON R.glass_id = G.glass_id
      WHERE NOT EXISTS (
        SELECT 1 FROM Recipe_Ingredients RI
        WHERE RI.recipe_id = R.recipe_id
        AND RI.ingredient_id NOT IN (
          SELECT UI.ingredient_id FROM User_Inventory UI WHERE UI.user_id = ?
        )
      ) AND R.user_id IS NULL
    ''', [userId]);
    return maps.map((map) => Recipe.fromMap(map)).toList();
  }

  // 重写“仅差一种”的查询逻辑
  Future<List<Map<String, dynamic>>> getMissingOneRecipes({int userId = 1}) async {
    final db = await database;

    // 1. 首先检查用户库存是否为空
    final inventoryCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM User_Inventory WHERE user_id = ?', [userId]));
    if (inventoryCount == 0) {
      return []; // 如果库存为空，直接返回空列表
    }

    // 2. 只有在库存不为空时，才执行原来的查询
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        R.*, 
        G.name as glass,
        (
          SELECT I.name 
          FROM Recipe_Ingredients RI
          JOIN Ingredients I ON RI.ingredient_id = I.ingredient_id
          WHERE RI.recipe_id = R.recipe_id 
          AND RI.ingredient_id NOT IN (SELECT UI.ingredient_id FROM User_Inventory UI WHERE UI.user_id = ?)
        ) as missing_ingredient
      FROM Recipes R
      LEFT JOIN Glassware G ON R.glass_id = G.glass_id
      WHERE R.user_id IS NULL AND (
        SELECT COUNT(*) 
        FROM Recipe_Ingredients RI
        WHERE RI.recipe_id = R.recipe_id 
        AND RI.ingredient_id NOT IN (SELECT UI.ingredient_id FROM User_Inventory UI WHERE UI.user_id = ?)
      ) = 1
    ''', [userId, userId]);

    return maps.map((map) {
      return {
        'recipe': Recipe.fromMap(map),
        'missing_ingredient': map['missing_ingredient'],
      };
    }).toList();
  }
  // [新] 获取用户库存中的所有配料，并按类别分组
  Future<Map<String, List<String>>> getInventoryByCategory({int userId = 1}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        IC.name as category_name,
        I.name as ingredient_name
      FROM User_Inventory UI
      JOIN Ingredients I ON UI.ingredient_id = I.ingredient_id
      JOIN IngredientCategories IC ON I.category_id = IC.category_id
      WHERE UI.user_id = ?
      ORDER BY IC.name, I.name
    ''', [userId]);

    final Map<String, List<String>> groupedInventory = {};
    for (var row in maps) {
      final category = row['category_name'] as String;
      final ingredient = row['ingredient_name'] as String;
      if (groupedInventory[category] == null) {
        groupedInventory[category] = [];
      }
      groupedInventory[category]!.add(ingredient);
    }
    return groupedInventory;
  }
  // 根据配料名称获取其ID，为直接删除功能提供支持
  Future<int?> getIngredientIdByName(String name) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'Ingredients',
      columns: ['ingredient_id'],
      where: 'name = ?',
      whereArgs: [name],
    );
    if (maps.isNotEmpty) {
      return maps.first['ingredient_id'] as int?;
    }
    return null;
  }

  // [核心升级] 新增“探索更多”的数据查询方法
  Future<List<Map<String, dynamic>>> getExplorableRecipes({int userId = 1}) async {
    final db = await database;

    final inventoryCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM User_Inventory WHERE user_id = ?', [userId]));
    if (inventoryCount == 0) {
      // 如果库存为空，理论上所有配方都是可探索的，但为了体验，返回一个空列表或有限的热门列表可能更佳。
      // 为保持逻辑一致性，此处返回空列表。
      return [];
    }

    // 查询所有缺少2种或以上配料的配方，并计算缺少的数量
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        R.*, 
        G.name as glass,
        (
          SELECT COUNT(*) 
          FROM Recipe_Ingredients RI
          WHERE RI.recipe_id = R.recipe_id 
          AND RI.ingredient_id NOT IN (SELECT UI.ingredient_id FROM User_Inventory UI WHERE UI.user_id = ?)
        ) as missing_count
      FROM Recipes R
      LEFT JOIN Glassware G ON R.glass_id = G.glass_id
      WHERE R.user_id IS NULL AND missing_count >= 2
      ORDER BY missing_count ASC, R.name ASC
    ''', [userId]);

    return maps.map((map) {
      return {
        'recipe': Recipe.fromMap(map),
        'missing_count': map['missing_count'],
      };
    }).toList();
  }
  // [核心升级] 在文件末尾添加全新的ABV计算器方法
  Future<double?> getRecipeABV(int recipeId) async {
    final db = await database;
    final List<Map<String, dynamic>> ingredients = await db.rawQuery('''
      SELECT
        ri.amount,
        ri.unit,
        i.abv
      FROM Recipe_Ingredients ri
      JOIN Ingredients i ON ri.ingredient_id = i.ingredient_id
      WHERE ri.recipe_id = ?
    ''', [recipeId]);

    if (ingredients.isEmpty) return null;

    double totalPureAlcohol = 0;
    double totalLiquidVolume = 0;
    bool hasAlcohol = false;

    for (var ing in ingredients) {
      final amountStr = ing['amount'] as String?;
      final unit = ing['unit'] as String?;
      final abv = ing['abv'] as double?;

      if (amountStr == null || amountStr.isEmpty) continue;

      double amount = double.tryParse(amountStr.replaceAll(',', '.')) ?? 0;

      // 单位标准化为 'ml'
      final unitLower = unit?.toLowerCase() ?? '';
      if (unitLower == 'oz' || unitLower == '盎司') {
        amount *= 30; // 简化转换: 1 oz ≈ 30 ml
      } else if (unitLower.contains('dash') || unitLower.contains('滴')) {
        amount *= 0.8; // 1 dash ≈ 0.8 ml
      } else if (unitLower.contains('tsp') || unitLower.contains('茶匙')) {
        amount *= 5; // 1 tsp ≈ 5 ml
      } else if (unitLower.contains('bar spoon') || unitLower.contains('吧勺')) {
        amount *= 5; // 1 bar spoon ≈ 5 ml
      }

      // 仅当配料有明确体积时才计入总体积
      if (amount > 0) {
        totalLiquidVolume += amount;

        if (abv != null && abv > 0) {
          hasAlcohol = true;
          totalPureAlcohol += amount * (abv / 100.0);
        }
      }
    }

    if (!hasAlcohol || totalLiquidVolume == 0) return 0.0;

    // 根据蓝图，为摇和/搅拌的饮品增加25%的稀释估算
    final double dilution = totalLiquidVolume * 0.25;
    final double finalVolume = totalLiquidVolume + dilution;

    if (finalVolume == 0) return 0.0;

    // ABV = (纯酒精体积 / 最终总体积) * 100
    final double finalABV = (totalPureAlcohol / finalVolume) * 100;

    return finalABV;
  }

  /// 获取指定配方的私人笔记
  Future<String?> getRecipeNote(int recipeId, {int userId = 1}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'User_Recipe_Notes',
      columns: ['notes'],
      where: 'user_id = ? AND recipe_id = ?',
      whereArgs: [userId, recipeId],
    );
    if (maps.isNotEmpty) {
      return maps.first['notes'] as String?;
    }
    return null;
  }

  /// 保存或更新指定配方的私人笔记
  Future<void> saveRecipeNote(int recipeId, String notes, {int userId = 1}) async {
    final db = await database;
    await db.insert(
      'User_Recipe_Notes',
      {'user_id': userId, 'recipe_id': recipeId, 'notes': notes},
      conflictAlgorithm: ConflictAlgorithm.replace, // 如果已存在则直接替换
    );
  }

  /// 删除指定配方的私人笔记
  Future<void> deleteRecipeNote(int recipeId, {int userId = 1}) async {
    final db = await database;
    await db.delete(
      'User_Recipe_Notes',
      where: 'user_id = ? AND recipe_id = ?',
      whereArgs: [userId, recipeId],
    );
  }

  /// 获取所有带有私人笔记的配方列表
  Future<List<Recipe>> getRecipesWithNotes({int userId = 1}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT R.*, G.name as glass 
      FROM Recipes R
      JOIN User_Recipe_Notes N ON R.recipe_id = N.recipe_id
      LEFT JOIN Glassware G ON R.glass_id = G.glass_id
      WHERE N.user_id = ?
      ORDER BY R.name
    ''', [userId]);
    return maps.map((map) => Recipe.fromMap(map)).toList();
  }
  // [新方法] 获取所有杯具的名称
  Future<List<String>> getAllGlasswareNames() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('Glassware', columns: ['name'], orderBy: 'name');
    if (maps.isEmpty) return [];
    return maps.map((map) => map['name'] as String).toList();
  }
}