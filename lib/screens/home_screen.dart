// [更新] 导入 'dart:ui' 用于实现毛玻璃效果
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:onecup/database/database_helper.dart';
import 'package:onecup/models/receip.dart';
import 'package:onecup/widgets/cocktail-card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // [修复] 1. 统一数据库实例，避免重复创建
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Recipe> _allRecipes = [];
  List<Recipe> _displayedRecipes = [];
  bool _isLoading = true;
  // [新增] 用于存放加载过程中可能发生的错误
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRecipes();
    _searchController.addListener(() {
      _filterRecipes(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // [修复] 2. 为数据加载增加完整的 try-catch 错误处理
  Future<void> _loadRecipes() async {
    // 确保在重新加载时重置状态
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final recipes = await _dbHelper.getAllRecipes();
      if (mounted) {
        setState(() {
          _allRecipes = recipes;
          _displayedRecipes = recipes;
          _isLoading = false;
        });
      }
    } catch (e) {
      // 如果发生错误，则捕获并更新UI以显示错误信息
      if (mounted) {
        setState(() {
          _error = '加载配方失败，请稍后重试。\n错误: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _filterRecipes(String query) {
    final filteredList = query.isEmpty
        ? _allRecipes
        : _allRecipes.where((recipe) {
      return recipe.name.toLowerCase().contains(query.toLowerCase());
    }).toList();
    if (mounted) {
      setState(() {
        _displayedRecipes = filteredList;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      // [修复] 3. 使用 CustomScrollView 替代 Stack，以获得更好的滚动体验和布局控制
      body: SafeArea(
        bottom: false,
        child: _buildBody(),
      ),
    );
  }

  // [新增] 用于根据页面状态（加载中、错误、成功）构建主体内容
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }
    // 使用 CustomScrollView 构建灵活的滚动视图
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        // 第一个部分：浮动的搜索栏
        SliverAppBar(
          floating: true,
          pinned: false,
          snap: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          titleSpacing: 0,
          title: _buildFloatingSearchBar(),
        ),
        // 第二个部分：鸡尾酒列表
        _buildRecipeList(),
      ],
    );
  }

  // [更新] 搜索栏现在是 SliverAppBar 的一部分
  Widget _buildFloatingSearchBar() {
    return Padding(
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
    );
  }

  // [更新] 配方列表现在是一个 SliverList
  Widget _buildRecipeList() {
    if (_displayedRecipes.isEmpty) {
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
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          return CocktailCard(recipe: _displayedRecipes[index]);
        },
        childCount: _displayedRecipes.length,
      ),
    );
  }
}