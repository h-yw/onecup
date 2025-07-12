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
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. 创建所有表结构
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

    // FIX: 添加了 Users 表的创建语句
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

    await batch.commit(noResult: true);

    // FIX: 插入一个默认用户，以确保外键约束有效
    await db.insert('Users', {'user_id': 1, 'username': 'default_user'});

    // 2. 表结构创建完毕后，立即填充初始数据
    await _populateDataFromAsset(db);
  }

  // 新增：从asset JSON文件填充数据的方法
  Future<void> _populateDataFromAsset(Database db) async {
    await db.transaction((txn) async {
      final String response = await rootBundle.loadString('assets/json/cocktails-cn.json');
      final List<dynamic> data = json.decode(response);

      final sourceId = await txn.insert('Sources', {'name': 'IBA官方'});

      final glassSet = <String>{};
      for (var cocktail in data) {
        if (cocktail['glass'] != null) {
          glassSet.add(cocktail['glass']);
        }
      }

      final glassMap = <String, int>{};
      for (var name in glassSet) {
        final id = await txn.insert('Glassware', {'name': name});
        glassMap[name] = id;
      }

      final ingredientMap = <String, int>{};

      for (var cocktail in data) {
        for (var ingredient in cocktail['ingredients']) {
          final uniqueName = ingredient['label'] ?? ingredient['ingredient'];
          if (uniqueName != null && !ingredientMap.containsKey(uniqueName)) {
            final id = await txn.insert('Ingredients', {'name': uniqueName});
            ingredientMap[uniqueName] = id;
          }
        }
      }

      for (var cocktail in data) {
        final recipeId = await txn.insert('Recipes', {
          'name': cocktail['name'],
          'instructions': cocktail['preparation'],
          'category': cocktail['category'],
          'glass_id': glassMap[cocktail['glass']],
          'source_id': sourceId,
          'description': cocktail['garnish'] != null ? '装饰: ${cocktail['garnish']}' : null,
        });

        for (var ingredient in cocktail['ingredients']) {
          final uniqueName = ingredient['label'] ?? ingredient['ingredient'];
          if (uniqueName != null) {
            await txn.insert('Recipe_Ingredients', {
              'recipe_id': recipeId,
              'ingredient_id': ingredientMap[uniqueName],
              'amount': ingredient['amount']?.toString(),
              'unit': ingredient['unit'],
            });
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
        r.image_path, r.category, g.name as glass
      FROM Recipes r
      LEFT JOIN Glassware g ON r.glass_id = g.glass_id
      ORDER BY r.name
    ''');

    return List.generate(maps.length, (i) {
      return Recipe.fromMap(maps[i]);
    });
  }


// 获取用户酒柜中所有配料的ID
  Future<Set<int>> getUserInventoryIds() async {
    final db = await database;
    // 假设用户ID为1
    final List<Map<String, dynamic>> maps = await db.query(
      'User_Inventory',
      columns: ['ingredient_id'],
      where: 'user_id = ?',
      whereArgs: [1],
    );
    return maps.map((e) => e['ingredient_id'] as int).toSet();
  }

// 获取酒柜管理所需的所有配料（包括是否已在库存中）
  Future<List<Map<String, dynamic>>> getIngredientsForBarManagement() async {
    final db = await database;
    final inventoryIds = await getUserInventoryIds();

    final allIngredients = await db.query('Ingredients', orderBy: 'name');

    return allIngredients.map((ingredient) {
      return {
        'id': ingredient['ingredient_id'],
        'name': ingredient['name'],
        'in_inventory': inventoryIds.contains(ingredient['ingredient_id']),
      };
    }).toList();
  }

// 将配料添加到用户酒柜
  Future<void> addIngredientToInventory(int ingredientId) async {
    final db = await database;
    await db.insert(
      'User_Inventory',
      {'user_id': 1, 'ingredient_id': ingredientId},
      conflictAlgorithm: ConflictAlgorithm.ignore, // 如果已存在则忽略
    );
  }

// 从用户酒柜移除配料
  Future<void> removeIngredientFromInventory(int ingredientId) async {
    final db = await database;
    await db.delete(
      'User_Inventory',
      where: 'user_id = ? AND ingredient_id = ?',
      whereArgs: [1, ingredientId],
    );
  }

// 获取单个配方的配料ID列表
  Future<List<int>> getIngredientIdsForRecipe(int recipeId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
        'Recipe_Ingredients',
        columns: ['ingredient_id'],
        where: 'recipe_id = ?',
        whereArgs: [recipeId]
    );
    return maps.map((e) => e['ingredient_id'] as int).toList();
  }
}