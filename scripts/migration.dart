// file: scripts/migration_script.dart

import 'dart:convert';
import 'dart:io';
import 'package:supabase/supabase.dart';

// --- 配置您的 SUPABASE 项目信息 ---
const String SUPABASE_URL = 'https://hwclphuicumabcijhtve.supabase.co'; // 替换为您的 Supabase URL
const String SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3Y2xwaHVpY3VtYWJjaWpodHZlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI5NzM3NjUsImV4cCI6MjA2ODU0OTc2NX0.VsajfU3TA52CJ4r8mwAKZUm5rr89CdKTEVAHYdeGzw4'; // 替换为您的 Supabase Anon Key
const String SUPABASE_SERVICE_KEY= 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3Y2xwaHVpY3VtYWJjaWpodHZlIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1Mjk3Mzc2NSwiZXhwIjoyMDY4NTQ5NzY1fQ.MFe_oasMxzGLTseQfWWWZjpFHJF2w9esM1hi9Q4aH_8';

Future<void> main() async {
  if (SUPABASE_URL.contains('YOUR_') || SUPABASE_SERVICE_KEY.contains('YOUR_')) {
    print('错误：请先在脚本中配置您的 SUPABASE_URL 和 SUPABASE_SERVICE_KEY。');
    exit(1);
  }

  final supabase = SupabaseClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
  print('✅ Supabase 初始化成功 (使用管理员权限)！准备开始数据迁移...');

  try {
    await migrateData(supabase);
    print('\n🎉🎉🎉 数据迁移成功完成！ 🎉🎉🎉');
  } catch (e, s) {
    print('\n❌ 数据迁移过程中发生错误:');
    print(e);
    print('Stack trace:\n$s');
    exit(1);
  }
}

Future<void> migrateData(SupabaseClient supabase) async {
  // --- 数据加载 ---
  // 确保您的 JSON 文件位于项目根目录下的 'assets/json/' 文件夹中
  final List<dynamic> cocktailsData = await _loadJsonData('assets/json/cocktails-new.json');
  final Map<String, dynamic> glassesData = await _loadJsonData('assets/json/glasses-cn.json');
  final Map<String, dynamic> ingredientsData = await _loadJsonData('assets/json/ingredients-cn-with-abv.json');

  // --- 2. 基础数据迁移 (Lookup Tables) ---
  print('\n--- 正在迁移基础数据... ---');

  // 迁移配方分类 (Recipe Categories)
  final categories = cocktailsData.map((c) => c['category'] as String).toSet().toList();
  final recipeCategoriesToUpsert = categories.map((name) => {'name': name}).toList();
  await manualUpsert(supabase, tableName: 'onecup_recipe_categories', data: recipeCategoriesToUpsert, conflictColumns: ['name']);
  final allRecipeCategories = await supabase.from('onecup_recipe_categories').select('id, name');
  final recipeCategoryMap = {for (var cat in allRecipeCategories) cat['name']: cat['id']};
  print('✅ 配方分类已准备好 ID 映射。');

  // 迁移杯具 (Glassware)
  final glassesToUpsert = glassesData.values.map((g) => {'name': g['name'] as String}).toList();
  await manualUpsert(supabase, tableName: 'onecup_glassware', data: glassesToUpsert, conflictColumns: ['name']);
  final allGlasses = await supabase.from('onecup_glassware').select('id, name');
  final glassMap = {for (var g in allGlasses) g['name']: g['id']};
  print('✅ 杯具迁移完成。');

  // 迁移配料分类 (Ingredient Categories)
  final ingredientCategories = ingredientsData.values.map((i) => i['category'] as String).toSet().toList();
  final ingredientCategoriesToUpsert = ingredientCategories.map((name) => {'name': name}).toList();
  await manualUpsert(supabase, tableName: 'onecup_ingredient_categories', data: ingredientCategoriesToUpsert, conflictColumns: ['name']);
  final allIngredientCategories = await supabase.from('onecup_ingredient_categories').select('id, name');
  final ingredientCategoryMap = {for (var cat in allIngredientCategories) cat['name']: cat['id']};
  print('✅ 配料分类迁移完成。');

  // 迁移配料 (Ingredients)
  final ingredientsToUpsert = ingredientsData.values.map((ing) {
    return {
      'name': ing['ingredient'],
      'aliases': List<String>.from(ing['aliases']),
      'category_id': ingredientCategoryMap[ing['category']],
      'abv': (ing['abv'] as num).toDouble(),
      'taste': ing['taste'],
    };
  }).toList();
  await manualUpsert(supabase, tableName: 'onecup_ingredients', data: ingredientsToUpsert, conflictColumns: ['name']);
  final allIngredients = await supabase.from('onecup_ingredients').select('id, name, aliases');
  final ingredientMap = <String, int>{};
  for (var ing in allIngredients) {
    ingredientMap[ing['name']] = ing['id'];
    for (var alias in List<String>.from(ing['aliases'] ?? [])) {
      ingredientMap[alias] = ing['id'];
    }
  }
  print('✅ 配料迁移完成。');

  // 迁移来源 (Sources)
  await manualUpsert(supabase, tableName: 'onecup_sources', data: [{'name': 'IBA官方'}], conflictColumns: ['name']);
  final sourceResult = await supabase.from('onecup_sources').select('id').eq('name', 'IBA官方').single();
  final sourceId = sourceResult['id'];
  print('✅ 来源迁移完成。');

  // --- 3. 核心数据迁移 (Recipes & Relations) ---
  print('\n--- 正在迁移配方 (Recipes) 及其关联数据... ---');
  int count = 0;
  for (final cocktail in cocktailsData) {
    count++;
    stdout.write('\r  处理中: $count / ${cocktailsData.length} -> ${cocktail['title']}');

    final detail = cocktail['detail'];

    final recipeData = {
      'name': cocktail['title'],
      'description': (detail['decorated'] as List<dynamic>).join('\n'),
      'instructions': (detail['preparation'] as List<dynamic>).join('\n'),
      'image': detail['img'],
      'source_id': sourceId,
      'category_id': recipeCategoryMap[cocktail['category']],
      'notes': List<String>.from(detail['notes'] ?? []),
      'video_url': detail['video'],
    };

    await manualUpsert(supabase, tableName: 'onecup_recipes', data: [recipeData], conflictColumns: ['name']);
    final recipeResult = await supabase.from('onecup_recipes').select('id').eq('name', cocktail['title']).single();
    final recipeId = recipeResult['id'];

    // a) 处理配方与杯具的关联
    final recipeGlasswareToUpsert = <Map<String, dynamic>>[];
    final uniqueGlassIds = <int>{};
    for (final glassName in List<String>.from(detail['receptacle'])) {
      final glassId = glassMap[glassName.trim()];
      if (glassId != null && uniqueGlassIds.add(glassId)) {
        recipeGlasswareToUpsert.add({'recipe_id': recipeId, 'glass_id': glassId});
      }
    }
    if (recipeGlasswareToUpsert.isNotEmpty) {
      await manualUpsert(supabase, tableName: 'onecup_recipe_glassware', data: recipeGlasswareToUpsert, conflictColumns: ['recipe_id', 'glass_id']);
    }

    // b) 处理配方与装饰物的关联
    final recipeGarnishesToUpsert = <Map<String, dynamic>>[];
    final uniqueGarnishItems = <String>{};
    for (final garnish in List<Map<String, dynamic>>.from(detail['garnish'] ?? [])) {
      final item = garnish['item'] as String;
      if (uniqueGarnishItems.add(item)) {
        recipeGarnishesToUpsert.add({
          'recipe_id': recipeId, 'item': item, 'is_optional': garnish['is_optional'] ?? false,
        });
      }
    }
    if (recipeGarnishesToUpsert.isNotEmpty) {
      await manualUpsert(supabase, tableName: 'onecup_recipe_garnishes', data: recipeGarnishesToUpsert, conflictColumns: ['recipe_id', 'item']);
    }

    // c) 处理配方与配料的关联
    final recipeIngredientsToUpsert = <Map<String, dynamic>>[];
    final uniqueIngredientDisplayNames = <String>{};
    for (final ing in List<Map<String, dynamic>>.from(detail['ingredients'])) {
      final ingredientId = ingredientMap[ing['ingredient']];
      final displayName = ing['ingredient'] as String;
      if (ingredientId != null && uniqueIngredientDisplayNames.add(displayName)) {
        recipeIngredientsToUpsert.add({
          'recipe_id': recipeId,
          'ingredient_id': ingredientId,
          'amount': ing['count'],
          'unit': ing['unit'],
          'is_optional': ing['is_optional'] == 1 || ing['is_optional'] == true,
          'display_name': displayName,
        });
      } else if (ingredientId == null) {
        print('\n  - 警告: 在配方 "${cocktail['title']}" 中找不到配料: "$displayName"');
      }
    }
    if (recipeIngredientsToUpsert.isNotEmpty) {
      await manualUpsert(supabase, tableName: 'onecup_recipe_ingredients', data: recipeIngredientsToUpsert, conflictColumns: ['recipe_id', 'display_name']);
    }
  }
}

Future<dynamic> _loadJsonData(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    print('错误：找不到JSON文件 at $filePath');
    exit(1);
  }
  final content = await file.readAsString();
  return json.decode(content);
}

Future<void> manualUpsert(SupabaseClient supabase, {
  required String tableName,
  required List<Map<String, dynamic>> data,
  required List<String> conflictColumns,
}) async {
  if (data.isEmpty) return;
  // Dart SDK v2.0.0 或更高版本支持 .upsert()，这是更优选的方法
  try {
    await supabase.from(tableName).upsert(data, onConflict: conflictColumns.join(','));
  } catch (e) {
    print('\n  - Upsert 失败，可能是使用了旧版 Supabase Dart 库。错误: $e');
    print('  - 正在尝试逐条插入/更新作为备用方案...');
    // 如果 upsert 失败（例如在旧版本库中），回退到旧的手动逻辑
    for (final row in data) {
      var query = supabase.from(tableName).select('id');
      for (final col in conflictColumns) {
        query = query.eq(col, row[col]);
      }
      final existing = await query.maybeSingle();

      if (existing != null) {
        // 更新时，确保 row 中没有主键 'id'
        final updateData = Map<String, dynamic>.from(row)..remove('id');
        await supabase.from(tableName).update(updateData).eq('id', existing['id']);
      } else {
        await supabase.from(tableName).insert(row);
      }
    }
  }
}