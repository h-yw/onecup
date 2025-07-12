import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:onecup/database/database_helper.dart';
import 'package:onecup/models/receip.dart';
import 'package:onecup/screens/recipe_detail_screen.dart';
import 'package:onecup/widgets/cocktail-card.dart';

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
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      _filterRecipes(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    // 重新获取Future，这将触发FutureBuilder重建
    _allRecipesFuture = _dbHelper.getAllRecipes();
    _recommendationsFuture = _dbHelper.getFlavorBasedRecommendations();
    // 更新主列表，用于搜索
    _allRecipesFuture.then((recipes) {
      if (mounted) {
        setState(() {
          _allRecipesMasterList = recipes;
          _filterRecipes(_searchController.text);
        });
      }
    });
  }

  void _filterRecipes(String query) {
    final filteredList = query.isEmpty
        ? _allRecipesMasterList
        : _allRecipesMasterList.where((recipe) {
      return recipe.name.toLowerCase().contains(query.toLowerCase());
    }).toList();
    setState(() {
      _displayedRecipes = filteredList;
    });
  }
// [新增] 统一的导航和刷新逻辑
  void _navigateToDetail(Recipe recipe) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipe: recipe)),
    );
    // 当从详情页返回时，重新加载数据
    if (mounted) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            _buildFloatingSearchBar(),
            _buildSectionHeader('为你推荐'),
            _buildRecommendationsList(),
            _buildSectionHeader('所有配方'),
            _buildAllRecipesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingSearchBar() {
    return SliverAppBar(
      floating: true,
      pinned: false,
      snap: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      titleSpacing: 0,
      title: Padding(
        // ... 搜索栏UI代码 ...
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 16.0, right: 8.0),
                    child: Icon(Icons.search, color: Colors.white, size: 24),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      cursorColor: Colors.white,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '发现你的下一杯...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white, size: 24),
                      onPressed: () => _searchController.clear(),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationsList() {
    return FutureBuilder<List<Recipe>>(
      future: _recommendationsFuture,
      builder: (context, snapshot) {
        // ... (原有的FutureBuilder逻辑) ...
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // ...
        }
        final recommendations = snapshot.data!;
        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              // [更新] 使用新的导航方法
              return CocktailCard(recipe: recommendations[index], onTap: () => _navigateToDetail(recommendations[index]));
            },
            childCount: recommendations.length,
          ),
        );
      },
    );
  }

  Widget _buildAllRecipesList() {
    // ... (处理空列表和错误状态的逻辑) ...
    return FutureBuilder<List<Recipe>>(
      future: _allRecipesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return SliverToBoxAdapter(child: Center(child: Text('加载失败: ${snapshot.error}')));
        }

        final recipes = _searchController.text.isEmpty
            ? snapshot.data ?? []
            : _displayedRecipes;

        if (recipes.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('没有找到匹配的鸡尾酒', style: TextStyle(fontSize: 18, color: Colors.grey)),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              // [更新] 使用新的导航方法
              return CocktailCard(recipe: recipes[index], onTap: () => _navigateToDetail(recipes[index]));
            },
            childCount: recipes.length,
          ),
        );
      },
    );
  }
}