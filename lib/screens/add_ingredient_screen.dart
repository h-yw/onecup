// lib/screens/add_ingredient_screen.dart

import 'package:flutter/material.dart';
import 'package:onecup/database/database_helper.dart';
import 'package:onecup/search/ingredient_search_delegate.dart'; // [新] 导入我们的搜索页面

class AddIngredientScreen extends StatefulWidget {
  const AddIngredientScreen({super.key});

  @override
  State<AddIngredientScreen> createState() => _AddIngredientScreenState();
}

class _AddIngredientScreenState extends State<AddIngredientScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _allIngredients = [];
  Map<String, List<Map<String, dynamic>>> _groupedIngredients = {};

  bool _isLoading = true;
  // [核心改造] 不再需要搜索控制器和状态
  // final TextEditingController _searchController = TextEditingController();
  // bool _isSearching = false;
  // final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  @override
  void dispose() {
    // _searchController.dispose();
    // _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadIngredients() async {
    // 为了确保搜索页能拿到最新数据，我们在这里加载所有配料
    if (!mounted) return;
    final data = await _dbHelper.getIngredientsForBarManagement();
    if (mounted) {
      setState(() {
        _allIngredients = data;
        _groupIngredients(data);
        _isLoading = false;
      });
    }
  }

  // [核心改造] 过滤逻辑已移至搜索页面，此方法不再需要
  // void _filterIngredients(String query) { ... }

  void _groupIngredients(List<Map<String, dynamic>> ingredients) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (var ingredient in ingredients) {
      final category = ingredient['category'];
      if (groups[category] == null) groups[category] = [];
      groups[category]!.add(ingredient);
    }
    final sortedKeys = groups.keys.toList()..sort();
    _groupedIngredients = {for (var k in sortedKeys) k: groups[k]!};
  }

  // [核心改造] 这个方法现在也会被搜索页面回调
  void _toggleIngredient(Map<String, dynamic> ingredient) async {
    bool isInInventory = ingredient['in_inventory'];
    if (isInInventory) {
      await _dbHelper.removeIngredientFromInventory(ingredient['id']);
    } else {
      await _dbHelper.addIngredientToInventory(ingredient['id']);
    }
    // 异步更新UI，不阻塞操作
    _updateLocalIngredientState(ingredient['id'], !isInInventory);
  }

  // [新] 用于在不重新加载整个列表的情况下，更新单个标签的状态
  void _updateLocalIngredientState(int id, bool newInventoryState) {
    if(!mounted) return;
    setState(() {
      final originalIndex = _allIngredients.indexWhere((el) => el['id'] == id);
      if(originalIndex != -1) {
        _allIngredients[originalIndex]['in_inventory'] = newInventoryState;
        _groupIngredients(_allIngredients);
      }
    });
  }

  // [新] 打开搜索页面的方法
  void _showSearch() async {
    final bool? hasChanged = await showSearch<bool>(
      context: context,
      delegate: IngredientSearchDelegate(
        allIngredients: _allIngredients,
        onToggle: _toggleIngredient,
      ),
    );
    // 如果搜索页面返回true（表示有数据更新），则重新加载以确保同步
    if (hasChanged == true && mounted) {
      _loadIngredients();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : DefaultTabController(
      length: _groupedIngredients.keys.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('管理我的酒柜'),
          // [核心改造] actions现在只有一个搜索图标
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _showSearch,
            )
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: _groupedIngredients.keys.map((category) => Tab(text: category)).toList(),
          ),
        ),
        // [核心改造] body不再需要处理搜索逻辑
        body: TabBarView(
          children: _groupedIngredients.values.map((ingredients) {
            return SingleChildScrollView(
              key: PageStorageKey(ingredients.first['category']),
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12.0,
                runSpacing: 12.0,
                children: ingredients.map((ingredient) {
                  return _buildIngredientChip(context, ingredient);
                }).toList(),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // _buildIngredientChip 方法保持不变
  Widget _buildIngredientChip(BuildContext context, Map<String, dynamic> ingredient) {
    final theme = Theme.of(context);
    final bool isInInventory = ingredient['in_inventory'];

    return InkWell(
      onTap: () => _toggleIngredient(ingredient),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isInInventory ? theme.primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isInInventory ? theme.primaryColor.withOpacity(0.8) : Colors.grey.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isInInventory)
              Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: Icon(Icons.check_circle, color: theme.primaryColor, size: 16),
              ),
            Text(
              ingredient['name'],
              style: TextStyle(
                fontWeight: isInInventory ? FontWeight.bold : FontWeight.normal,
                color: isInInventory ? theme.primaryColor : theme.textTheme.bodyLarge?.color,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}