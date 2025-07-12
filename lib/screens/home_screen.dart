import 'dart:ui'; // 引入ImageFilter
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
  List<Recipe> _allRecipes = [];
  List<Recipe> _displayedRecipes = [];
  bool _isLoading = true;
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

  Future<void> _loadRecipes() async {
    final recipes = await DatabaseHelper().getAllRecipes();
    if (mounted) {
      setState(() {
        _allRecipes = recipes;
        _displayedRecipes = recipes;
        _isLoading = false;
      });
    }
  }

  void _filterRecipes(String query) {
    final filteredList = query.isEmpty
        ? _allRecipes
        : _allRecipes.where((recipe) {
      return recipe.name.toLowerCase().contains(query.toLowerCase());
    }).toList();
    setState(() {
      _displayedRecipes = filteredList;
    });
  }

  // 新增：构建浮动搜索栏的方法
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
            // 使用 Row 手动布局图标和输入框
            child: Row(
              children: [
                // 1. 左侧的搜索图标
                const Padding(
                  padding: EdgeInsets.only(left: 16.0, right: 8.0),
                  child: Icon(Icons.search, color: Colors.white, size: 24),
                ),
                // 2. 中间可伸展的输入区域
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    cursorColor: Colors.white,
                    // 在这个简洁的布局中，此属性可以完美生效
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      // 移除所有外部边框和内边距
                      border: InputBorder.none,
                      hintText: '发现你的下一杯...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
                // 3. 右侧的清除按钮 (条件显示)
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white, size: 24),
                    onPressed: () => _searchController.clear(),
                  )
                else
                // 当没有文本时，用一个空的SizedBox占位，以保持布局稳定
                  const SizedBox(width: 48), // IconButton的默认宽度
              ],
            ),
          ),
        ),
      ),
    );
  }
  // 新增：构建背景列表的方法
  Widget _buildRecipeList() {
    // 为列表顶部增加内边距，防止被搜索栏遮挡
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: _displayedRecipes.isEmpty
          ? const Center(
        child: Text(
          '没有找到匹配的鸡尾酒',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      )
          : ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: _displayedRecipes.length,
        itemBuilder: (context, index) {
          return CocktailCard(recipe: _displayedRecipes[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 设置一个深色背景，以更好地突出玻璃效果
      backgroundColor: Colors.blueGrey[900],
      // 移除AppBar，使用Stack自定义布局
      body: SafeArea(
        bottom: false, // 允许列表内容延伸到底部安全区
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
          children: [
            // 第一层：背景的鸡尾酒列表
            _buildRecipeList(),
            // 第二层：顶部的浮动搜索栏
            _buildFloatingSearchBar(),
          ],
        ),
      ),
    );
  }
}