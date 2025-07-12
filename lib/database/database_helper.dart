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
        final id = await txn.insert('IngredientCategories', {'name': catName});
        categoryMap[catName] = id;
      }

      // 3. Insert all ingredients and link them to their categories
      final ingredientMap = <String, int>{};
      for (var entry in ingredientsCnData.entries) {
        final String ingredientName = entry.value['ingredient'];
        final String categoryName = entry.value['category'] ?? '未分类';

        if (!ingredientMap.containsKey(ingredientName)) {
          final categoryId = categoryMap[categoryName];
          final id = await txn.insert('Ingredients', {'name': ingredientName, 'category_id': categoryId});
          ingredientMap[ingredientName] = id;
        }
      }

      // 4. Insert glassware
      final glassMap = <String, int>{};
      for (var entry in glassesCnData.entries) {
        final id = await txn.insert('Glassware', {'name': entry.value['name']});
        glassMap[entry.value['name']] = id; // Use Chinese name as key
      }

      // 5. Insert sources and recipes
      final sourceId = await txn.insert('Sources', {'name': 'IBA官方'});
      for (var cocktail in cocktailsData) {
        final recipeId = await txn.insert('Recipes', {
          'name': cocktail['name'],
          'instructions': cocktail['preparation'],
          'category': cocktail['category'],
          'glass_id': glassMap[cocktail['glass']],
          'source_id': sourceId,
          'description': cocktail['garnish'] != null ? '装饰: ${cocktail['garnish']}' : null,
        });

        // 6. Insert recipe-ingredient relationships
        for (var ingredientData in cocktail['ingredients']) {
          final uniqueName = ingredientData['label'] ?? ingredientData['ingredient'];
          final ingredientId = ingredientMap[uniqueName];

          if (uniqueName != null && ingredientId != null) {
            await txn.insert('Recipe_Ingredients', {
              'recipe_id': recipeId,
              'ingredient_id': ingredientId,
              'amount': ingredientData['amount']?.toString(),
              'unit': ingredientData['unit'],
            });
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


}