import 'package:flutter/material.dart';
import 'package:onecup/database/database_helper.dart';
import 'package:onecup/models/receip.dart';
import 'package:onecup/screens/recipe_detail_screen.dart';
import 'package:onecup/widgets/cocktail-card.dart';
import 'package:onecup/widgets/custom_search_bar.dart';
import 'package:onecup/widgets/recommendation_card.dart';
import 'package:sliver_tools/sliver_tools.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  late Future<List<Recipe>> _allRecipesFuture;
  late Future<List<Recipe>> _recommendationsFuture;

  List<Recipe> _allRecipesMasterList = [];
  List<Recipe> _displayedRecipes = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeFutures();
    _searchController.addListener(() {
      _filterRecipes(_searchController.text);
    });
  }

  void _initializeFutures() {
    _allRecipesFuture = _dbHelper.getAllRecipes();
    _recommendationsFuture = _dbHelper.getFlavorBasedRecommendations();

    _allRecipesFuture.then((recipes) {
      if (mounted) {
        setState(() {
          _allRecipesMasterList = recipes;
          _displayedRecipes = _allRecipesMasterList;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterRecipes(String query) {
    // ... 过滤逻辑保持不变 ...
    final filteredList = query.isEmpty
        ? _allRecipesMasterList
        : _allRecipesMasterList.where((recipe) {
      return recipe.name.toLowerCase().contains(query.toLowerCase());
    }).toList();
    if (mounted) {
      setState(() {
        _displayedRecipes = filteredList;
      });
    }
  }

  void _navigateToDetail(Recipe recipe) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipe: recipe)),
    );
    if (mounted) {
      setState(() {
        _initializeFutures();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            CustomSearchBar(
              controller: _searchController,
              onSearchChanged: _filterRecipes,
            ),
            if (_searchController.text.isEmpty) ...[
              _buildForYouSection(),
              _buildSectionHeader('所有配方'),
              _buildAllRecipesList(),
            ] else ...[
              _buildSectionHeader('搜索结果'),
              _buildSearchResultsList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildForYouSection() {
    return FutureBuilder<List<Recipe>>(
      future: _recommendationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: Container(height: 250, child: const Center(child: CircularProgressIndicator())),
          );
        }

        // [核心升级] 优化“空状态”的UI/UX
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverToBoxAdapter(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              elevation: 0,
              color: Theme.of(context).primaryColor.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(Icons.auto_awesome, color: Theme.of(context).primaryColor, size: 40),
                    const SizedBox(height: 16),
                    const Text(
                      '你的专属推荐官已就位！',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '给喜欢的鸡尾酒点亮❤️，我们会在这里为你发现更多惊喜。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    /*const SizedBox(height: 20),
                    // [新] 添加一个明确的行动号召按钮
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: 可以考虑让页面滚动到“所有配方”区域
                        // 这是一个高级交互，暂时先不做
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('先去逛逛'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
                        foregroundColor: Colors.white,
                      ),
                    )*/
                  ],
                ),
              ),
            ),
          );
        }

        final recipes = snapshot.data!;
        return MultiSliver(
          children: [
            _buildSectionHeader('为你推荐'),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 180, // [调整] 调整高度以适应新的卡片设计
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 16), // [新] 确保最后一个卡片有右边距
                  itemCount: recipes.length,
                  itemBuilder: (context, index) {
                    return RecommendationCard(
                      recipe: recipes[index],
                      onTap: () => _navigateToDetail(recipes[index]),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ... 其他 build 辅助方法保持不变 ...
  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }

  Widget _buildAllRecipesList() {
    return FutureBuilder<List<Recipe>>(
      future: _allRecipesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return SliverToBoxAdapter(child: Center(child: Text('无法加载配方: ${snapshot.error}')));
        }
        final recipes = snapshot.data ?? [];
        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) => CocktailCard(recipe: recipes[index], onTap: () => _navigateToDetail(recipes[index])),
            childCount: recipes.length,
          ),
        );
      },
    );
  }

  Widget _buildSearchResultsList() {
    if (_displayedRecipes.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40.0),
            child: Text('没有找到匹配的鸡尾酒...', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) => CocktailCard(recipe: _displayedRecipes[index], onTap: () => _navigateToDetail(_displayedRecipes[index])),
        childCount: _displayedRecipes.length,
      ),
    );
  }
}