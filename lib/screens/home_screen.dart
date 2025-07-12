// [无需修改] 保留原有导入
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
  // [无需修改] 统一数据库实例
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // [修复] 1. 将数据列表改为用 FutureBuilder 直接驱动，不再需要 _isLoading 标志
  late Future<List<Recipe>> _allRecipesFuture;
  // [恢复] 2. 重新添加“为你推荐”的数据模型
  late Future<List<Recipe>> _recommendationsFuture;

  // [保留] 用于搜索功能的状态变量
  List<Recipe> _allRecipesMasterList = [];
  List<Recipe> _displayedRecipes = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData(); // 初始化时加载所有数据
    _searchController.addListener(() {
      _filterRecipes(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // [修复] 3. 重构数据加载逻辑，使其更健壮并能同时处理两个数据源
  void _loadData() {
    // try-catch 块不是绝对必要，因为FutureBuilder会处理错误，
    // 但保留它可以用于调试或在未来添加更复杂的错误处理逻辑。
    try {
      if (mounted) {
        setState(() {
          // 重新获取Future会通知FutureBuilder重建其UI
          _allRecipesFuture = _dbHelper.getAllRecipes();
          _recommendationsFuture = _dbHelper.getFlavorBasedRecommendations();

          // 同时更新用于搜索的本地列表
          _allRecipesFuture.then((recipes) {
            _allRecipesMasterList = recipes;
            _filterRecipes(_searchController.text);
          });
        });
      }
    } catch (e) {
      // 在这里可以处理一些全局性的加载错误
      print("加载数据时发生错误: $e");
    }
  }

  // [无需修改] 搜索过滤逻辑
  void _filterRecipes(String query) {
    final filteredList = query.isEmpty
        ? _allRecipesMasterList
        : _allRecipesMasterList.where((recipe) {
      return recipe.name.toLowerCase().contains(query.toLowerCase());
    }).toList();
    if(mounted) {
      setState(() {
        _displayedRecipes = filteredList;
      });
    }
  }

  // [恢复] 4. 统一的导航逻辑，确保从详情页返回时能刷新数据
  void _navigateToDetail(Recipe recipe) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipe: recipe)),
    );
    // 当从详情页返回时，重新加载所有数据
    if (mounted) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    // [修复] 5. 不再需要 _isLoading 判断，UI完全由 FutureBuilder 驱动
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            _buildFloatingSearchBar(),
            // [恢复] 6. 重新添加“为你推荐”的UI部分
            _buildSectionHeader('为你推荐'),
            _buildRecommendationsList(),
            _buildSectionHeader('所有配方'),
            // [更新] 将原有的 _buildRecipeList 重命名为 _buildAllRecipesList 以区分
            _buildAllRecipesList(),
          ],
        ),
      ),
    );
  }

  // [无需修改] 搜索栏UI
  Widget _buildFloatingSearchBar() {
    return SliverAppBar(
      floating: true,
      pinned: false,
      snap: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      titleSpacing: 0,
      title: Padding(
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

  // [无需修改] 章节标题UI
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

  // [恢复] 7. “为你推荐”列表的完整 FutureBuilder 实现
  Widget _buildRecommendationsList() {
    return FutureBuilder<List<Recipe>>(
      future: _recommendationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text('无法加载推荐内容: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: const Text(
                '收藏一些你喜欢的鸡尾酒，我们就能在这里为你推荐更多！',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final recommendations = snapshot.data!;
        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              return CocktailCard(recipe: recommendations[index], onTap: () => _navigateToDetail(recommendations[index]));
            },
            childCount: recommendations.length,
          ),
        );
      },
    );
  }

  // [更新] 8. “所有配方”列表的UI逻辑，现在也由FutureBuilder驱动
  Widget _buildAllRecipesList() {
    // 搜索功能现在是基于 _displayedRecipes 列表，它会在 Future 完成后被填充
    // 并且在用户输入时被过滤。
    if (_searchController.text.isNotEmpty && _displayedRecipes.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              '没有找到匹配的鸡尾酒',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    // 主列表依然由 FutureBuilder 驱动，以处理初次加载和错误状态
    return FutureBuilder<List<Recipe>>(
        future: _allRecipesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // 在上面推荐列表加载时已经有了一个加载指示器，这里可以显示一个小的或者什么都不显示
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }
          if (snapshot.hasError) {
            return SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text('无法加载所有配方: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
                ),
              ),
            );
          }

          // 使用 _displayedRecipes 来显示，它会响应搜索过滤
          return SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                return CocktailCard(recipe: _displayedRecipes[index], onTap: () => _navigateToDetail(_displayedRecipes[index]));
              },
              childCount: _displayedRecipes.length,
            ),
          );
        }
    );
  }
}