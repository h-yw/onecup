// lib/screens/my_bar_screen.dart

import 'package:flutter/material.dart';
import 'package:onecup/common/show_top_banner.dart';
import 'package:onecup/database/database_helper.dart';
import 'package:onecup/database/supabase_service.dart';
import 'package:onecup/models/receip.dart';
import 'package:onecup/screens/add_ingredient_screen.dart';
import 'package:onecup/screens/recipe_detail_screen.dart';
import 'package:onecup/widgets/cocktail-card.dart';
import 'package:onecup/widgets/explorable_cocktail_card.dart'; // [核心升级] 导入新卡片
import 'package:onecup/widgets/inventory_shelf_card.dart';
import 'package:onecup/widgets/missing_one_card.dart';
import 'package:onecup/widgets/purchase_suggestion_sheet.dart';

class MyBarScreen extends StatefulWidget {
  const MyBarScreen({super.key});

  @override
  State<MyBarScreen> createState() => _MyBarScreenState();
}

class _MyBarScreenState extends State<MyBarScreen> with TickerProviderStateMixin {
  final SupabaseService _dbHelper = SupabaseService();

  late Future<Map<String, List<String>>> _inventoryFuture;
  late Future<List<Recipe>> _makeableRecipesFuture;
  late Future<List<Map<String, dynamic>>> _missingOneRecipesFuture;
  late Future<List<Map<String, dynamic>>> _explorableRecipesFuture; // [核心升级] 新增Future

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // [核心升级] Tab数量变为4
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  void _loadAllData() {
    setState(() {
      _inventoryFuture = _dbHelper.getInventoryByCategory();
      _makeableRecipesFuture = _dbHelper.getMakeableRecipes();
      _missingOneRecipesFuture = _dbHelper.getMissingOneRecipes();
      _explorableRecipesFuture = _dbHelper.getExplorableRecipes(); // [核心升级] 加载新数据
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateAndRefresh() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddIngredientScreen()),
    );
    _loadAllData();
  }

  Future<void> _removeIngredient(String name) async {
    final ingredientId = await _dbHelper.getIngredientIdByName(name);
    if (ingredientId != null) {
      await _dbHelper.removeIngredientFromInventory(ingredientId);
      _loadAllData();
      if (mounted) {
        showTopBanner(context, '已将“$name”移出我的酒柜');
      }
    }
  }

  void _showPurchaseSuggestions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return PurchaseSuggestionSheet(
          recommendationsFuture: _dbHelper.getPurchaseRecommendations(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的酒柜'),
        elevation: 1,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0.0),
            child: TabBar(
              controller: _tabController,
              isScrollable: true, // [核心升级] 让TabBar可以滚动
              tabAlignment: TabAlignment.start,
              dividerHeight: 0,
              tabs: const [
                Tab(text: '即刻可调'),
                Tab(text: '仅差一种'),
                Tab(text: '探索更多'), // [核心升级] 新增Tab
                Tab(text: '我的库存'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildAnimatedFab(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMakeableList(),
          _buildMissingOneTab(),
          _buildExplorableList(), // [核心升级] 新增页面
          _buildInventoryList(),
        ],
      ),
    );
  }

  // [核心升级] 构建“探索更多”页面的全新方法
  Widget _buildExplorableList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _explorableRecipesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('加载失败: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                '你的酒柜潜力无限！\n试着再添加一些基础酒吧。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
          );
        }

        final items = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.only(top: 2, bottom: 80),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final recipe = item['recipe'] as Recipe;
            final missingCount = item['missing_count'] as int;
            return ExplorableCocktailCard(
              recipe: recipe,
              missingCount: missingCount,
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipe: recipe)));
                _loadAllData();
              },
            );
          },
        );
      },
    );
  }

  // ... 其余所有 build 方法和 FAB 逻辑保持不变 ...

  Widget _buildAnimatedFab() {
    return AnimatedBuilder(
      animation: _tabController.animation!,
      builder: (context, child) {
        // ... (FAB动画逻辑无需修改, 只需调整索引)
        final int currentIndex = _tabController.index;
        if (currentIndex == 1) return _buildFabForIndex(1); // 仅差一种
        if (currentIndex == 3) return _buildFabForIndex(2); // 我的库存
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildFabForIndex(int index) {
    final theme = Theme.of(context);
    switch (index) {
      case 1: // “仅差一种”页的FAB
        return FloatingActionButton(
          key: const ValueKey('suggestion_fab'),
          onPressed: _showPurchaseSuggestions,
          tooltip: '查看购买建议',
          backgroundColor: Colors.amber[800],
          child: const Icon(Icons.lightbulb_outline, color: Colors.white),
        );
      case 2: // “我的库存”页的FAB
        return FloatingActionButton(
          key: const ValueKey('edit_fab'),
          onPressed: _navigateAndRefresh,
          tooltip: '添加/编辑库存',
          backgroundColor: theme.primaryColor,
          child: const Icon(Icons.edit, color: Colors.white),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // --- 其他未改动的方法保持原样 ---
  Widget _buildInventoryList() {
    return FutureBuilder<Map<String, List<String>>>(
      future: _inventoryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('加载库存失败: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                '你的酒柜还是空的。\n点击右下角的“管理库存”按钮，开始添加吧！',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
          );
        }

        final inventory = snapshot.data!;
        final categories = inventory.keys.toList();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final ingredients = inventory[category]!;

            return InventoryShelfCard(
              category: category,
              ingredients: ingredients,
              onRemove: _removeIngredient,
            );
          },
        );
      },
    );
  }

  Widget _buildMakeableList() {
    return FutureBuilder<List<Recipe>>(
      future: _makeableRecipesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('加载失败: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                '你的酒柜还是空的。\n切换到“我的库存”并点击右下角按钮，添加你拥有的第一瓶酒吧！',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
          );
        }
        final recipes = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.only(top: 2, bottom: 80),
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            return CocktailCard(
              recipe: recipes[index],
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipe: recipes[index])));
                _loadAllData();
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMissingOneTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _missingOneRecipesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('加载失败: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                '你的酒柜非常齐全！\n我们没有找到只差一种配料就能解锁的配方。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
          );
        }

        final missingOneItems = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.only(top: 2, bottom: 80),
          itemCount: missingOneItems.length,
          itemBuilder: (context, index) {
            final item = missingOneItems[index];
            final recipe = item['recipe'] as Recipe;
            final missingIngredient = item['missing_ingredient'] as String;
            return MissingOneCard(
              recipe: recipe,
              missingIngredient: missingIngredient,
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipe: recipe)));
                _loadAllData();
              },
              onAddToList: () {
                // _dbHelper.addToShoppingList(missingIngredient);
                showTopBanner(context, '“$missingIngredient”已添加到购物清单！');
              },
            );
          },
        );
      },
    );
  }
}