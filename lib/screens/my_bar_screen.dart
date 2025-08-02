

// lib/screens/my_bar_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onecup/common/show_top_banner.dart';

import 'package:onecup/providers/cocktail_providers.dart';
import 'package:onecup/screens/add_ingredient_screen.dart';
import 'package:onecup/screens/recipe_detail_screen.dart';
import 'package:onecup/widgets/cocktail_card.dart';
import 'package:onecup/widgets/explorable_cocktail_card.dart';
import 'package:onecup/widgets/inventory_shelf_card.dart';
import 'package:onecup/widgets/missing_one_card.dart';
import 'package:onecup/widgets/purchase_suggestion_sheet.dart';

// 1. Convert StatefulWidget to ConsumerStatefulWidget
class MyBarScreen extends ConsumerStatefulWidget {
  const MyBarScreen({super.key});

  @override
  ConsumerState<MyBarScreen> createState() => _MyBarScreenState();
}

// 2. Change State to ConsumerState
class _MyBarScreenState extends ConsumerState<MyBarScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshCocktailData() {
    // Use the new notifier to reload inventory, invalidate others as before.
    ref.read(inventoryNotifierProvider.notifier).loadInventory();
    ref.invalidate(makeableRecipesProvider);
    ref.invalidate(missingOneRecipesProvider);
    ref.invalidate(explorableRecipesProvider);
  }

  void _navigateAndRefresh() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddIngredientScreen()),
    );
    _refreshCocktailData();
  }

  /// Handles ingredient removal with optimistic UI updates.
  Future<void> _handleRemoveIngredient(String name) async {
    try {
      // Call the optimistic removal method on the notifier.
      // The UI will update instantly.
      await ref.read(inventoryNotifierProvider.notifier).removeIngredientOptimistically(name);

      if (mounted) {
        // Show success message only after the backend call succeeds.
        showTopBanner(context, '已将“$name”移出我的酒柜');
      }
    } catch (e) {
      if (mounted) {
        // If the notifier throws an error, it means the backend call failed
        // and the UI has been rolled back. Show an error message.
        showTopBanner(context, '删除“$name”失败，请重试', isError: true);
      }
    }
  }

  // 4. Update how the suggestion sheet is shown
  void _showPurchaseSuggestions() {
    // We can now directly use the repository provider's future
    final recommendationsFuture = ref.read(cocktailRepositoryProvider).getPurchaseRecommendations();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return PurchaseSuggestionSheet(
          recommendationsFuture: recommendationsFuture,
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
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerHeight: 0,
              tabs: const [
                Tab(text: '即刻可调'),
                Tab(text: '仅差一种'),
                Tab(text: '探索更多'),
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
          _buildExplorableList(),
          _buildInventoryList(),
        ],
      ),
    );
  }

  Widget _buildAnimatedFab() {
    return AnimatedBuilder(
      animation: _tabController.animation!,
      builder: (context, child) {
        final int currentIndex = _tabController.index;
        if (currentIndex == 1) return _buildFabForIndex(1);
        if (currentIndex == 3) return _buildFabForIndex(2);
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildFabForIndex(int index) {
    final theme = Theme.of(context);
    switch (index) {
      case 1:
        return FloatingActionButton(
          key: const ValueKey('suggestion_fab'),
          onPressed: _showPurchaseSuggestions,
          tooltip: '查看购买建议',
          backgroundColor: Colors.amber[800],
          child: const Icon(Icons.lightbulb_outline, color: Colors.white),
        );
      case 2:
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

  // 5. Rebuild widgets using Consumer and ref.watch
  Widget _buildInventoryList() {
    // Watch the new StateNotifierProvider
    final inventoryAsyncValue = ref.watch(inventoryNotifierProvider);
    return inventoryAsyncValue.when(
      data: (inventory) {
        if (inventory.isEmpty) {
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
              onRemove: _handleRemoveIngredient, // Use the new handler
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('加载库存失败: $err')),
    );
  }

  Widget _buildMakeableList() {
    final makeableRecipesAsyncValue = ref.watch(makeableRecipesProvider);
    return makeableRecipesAsyncValue.when(
      data: (recipes) {
        if (recipes.isEmpty) {
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
        return ListView.builder(
          padding: const EdgeInsets.only(top: 2, bottom: 80),
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            return CocktailCard(
              recipe: recipes[index],
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipe: recipes[index])));
                // No need to call _loadAllData() anymore
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('加载失败: $err')),
    );
  }

  Widget _buildMissingOneTab() {
    final missingOneAsyncValue = ref.watch(missingOneRecipesProvider);
    return missingOneAsyncValue.when(
      data: (missingOneItems) {
        if (missingOneItems.isEmpty) {
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
        return ListView.builder(
          padding: const EdgeInsets.only(top: 2, bottom: 80),
          itemCount: missingOneItems.length,
          itemBuilder: (context, index) {
            final item = missingOneItems[index];
            return MissingOneCard(
              recipe: item.recipe,
              missingIngredient: item.missingIngredientName,
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipe: item.recipe)));
              },
              onAddToList: () {
                // final dbHelper = ref.read(cocktailRepositoryProvider);
                // dbHelper.addToShoppingList(item.missingIngredientName, item.recipe.id); // This needs ingredient ID
                showTopBanner(context, '“${item.missingIngredientName}”已添加到购物清单！');
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('加载失败: $err')),
    );
  }

  Widget _buildExplorableList() {
    final explorableRecipesAsyncValue = ref.watch(explorableRecipesProvider);
    return explorableRecipesAsyncValue.when(
      data: (items) {
        if (items.isEmpty) {
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

        return ListView.builder(
          padding: const EdgeInsets.only(top: 2, bottom: 80),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ExplorableCocktailCard(
              recipe: item.recipe,
              missingCount: item.missingCount,
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipe: item.recipe)));
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('加载失败: $err')),
    );
  }
}