// lib/screens/shopping_list_screen.dart

import 'package:flutter/material.dart';
import 'package:onecup/common/show_top_banner.dart';
import 'package:onecup/database/database_helper.dart';
import 'package:onecup/database/supabase_service.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  // [最终修复] 移除页面状态中独立的 TextEditingController 和 FocusNode。
  // Autocomplete 组件会自行管理这些状态，我们必须使用它提供的实例。
  // final TextEditingController _textController = TextEditingController();
  // final FocusNode _focusNode = FocusNode();

  final SupabaseService _dbHelper = SupabaseService();

  List<Map<String, dynamic>> _shoppingList = [];
  List<Map<String, dynamic>> _allIngredients = [];
  bool _isLoading = true;

  bool get _hasCompletedItems => _shoppingList.any((item) => item['checked'] as bool);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // dispose 方法现在为空，因为我们不再管理这里的 controller 和 focusNode。
  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadAllIngredients(),
      _loadShoppingList(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAllIngredients() async {
    _allIngredients = await _dbHelper.getIngredientsForBarManagement();
  }

  Future<void> _loadShoppingList() async {
    final data = await _dbHelper.getShoppingList();
    if (mounted) {
      setState(() {
        _shoppingList = data.map((item) {
          return {
            'id': item['id'],
            'name': item['name'],
            'checked': item['checked'] == 1,
          };
        }).toList();
        _shoppingList.sort((a, b) {
          if (a['checked'] == b['checked']) return 0;
          return a['checked'] ? 1 : -1;
        });
      });
    }
  }

  // _addItem 方法现在只接收文本本身，因为它会从 Autocomplete 的控制器中获取
  Future<void> _addItem(String text, {required TextEditingController controller, required FocusNode focusNode}) async {
    if (text.trim().isNotEmpty) {
      // await _dbHelper.addToShoppingList(text.trim());
      // 操作完成后清空控制器并让输入框失去焦点
      controller.clear();
      focusNode.unfocus();
      _loadShoppingList();
    }
  }

  Future<void> _removeItem(int id) async {
    await _dbHelper.removeFromShoppingList(id);
    _loadShoppingList();
  }

  Future<void> _clearCompletedItems() async {
    await _dbHelper.clearCompletedShoppingItems();
    _loadShoppingList();
    if (mounted) {
      showTopBanner(context, '已清除所有已完成项目');
    }
  }

  Future<void> _handleItemChecked(int id, String name, bool? value) async {
    if (value == null) return;
    await _dbHelper.updateShoppingListItem(id, value);
    _loadShoppingList();

    if (value == true) {
      final ingredient = _allIngredients.firstWhere(
            (ing) => ing['name'] == name,
        orElse: () => {},
      );
      if (ingredient.isNotEmpty) {
        _showAddToBarDialog(name, ingredient['id']);
      }
    }
  }

  Future<void> _showAddToBarDialog(String name, int ingredientId) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('添加到酒柜?'),
          content: Text('您已购买“$name”。要现在就将它添加到您的酒柜吗？'),
          actions: [
            TextButton(
              child: const Text('不了，谢谢'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('添加到酒柜'),
              onPressed: () async {
                await _dbHelper.addIngredientToInventory(ingredientId);
                Navigator.of(context).pop();
                if (mounted) {
                  showTopBanner(context,'“$name”已添加到您的酒柜！');
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('购物清单'),
        actions: [
          if (_hasCompletedItems)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.cleaning_services_outlined),
                tooltip: '清除已完成',
                onPressed: _clearCompletedItems,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildAutocompleteInputBar(),
          Expanded(
            child: _shoppingList.isEmpty
                ? _buildEmptyState()
                : _buildShoppingListView(),
          ),
        ],
      ),
    );
  }

  Widget _buildAutocompleteInputBar() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Autocomplete<Map<String, dynamic>>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<Map<String, dynamic>>.empty();
          }
          final currentListNames = _shoppingList.map((e) => e['name'] as String).toSet();
          return _allIngredients.where((ingredient) {
            final name = ingredient['name'] as String;
            final isAlreadyInList = currentListNames.contains(name);
            final matchesQuery = name.toLowerCase().contains(textEditingValue.text.toLowerCase());
            return matchesQuery && !isAlreadyInList;
          });
        },
        onSelected: (Map<String, dynamic> selection) {
          // 当用户从联想列表中选择一项时，Autocomplete会自动填充文本。
          // 我们可以在这里执行添加操作，或者让用户点击按钮确认。
          // 为保持一致性，我们让用户点击按钮添加。
          FocusManager.instance.primaryFocus?.unfocus();
        },
        displayStringForOption: (Map<String, dynamic> option) => option['name'] as String,

        // [最终修复] 这是最关键的部分：
        // `fieldViewBuilder` 会为我们创建并管理 TextField 所需的 controller 和 focusNode。
        // 我们必须使用它通过参数传给我们的实例，而不是自己创建的。
        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
          return Material(
            elevation: 2.0,
            shadowColor: theme.shadowColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(15.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    // 这是关键：使用 builder 提供的 controller 和 focusNode
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: '搜索配料或手动输入...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
                    ),
                    onSubmitted: (text) => _addItem(text, controller: textEditingController, focusNode: focusNode),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: () => _addItem(textEditingController.text, controller: textEditingController, focusNode: focusNode),
                  color: theme.primaryColor,
                  iconSize: 28,
                  tooltip: '添加',
                ),
              ],
            ),
          );
        },

        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4.0,
              borderRadius: BorderRadius.circular(12.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final option = options.elementAt(index);
                    return InkWell(
                      onTap: () => onSelected(option),
                      child: ListTile(
                        title: Text(option['name'] as String),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_checkout, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('购物清单是空的', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              '在“仅差一种”或“探索更多”中发现想喝的鸡尾酒，\n或在这里手动添加需要购买的物品吧！',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShoppingListView() {
    final int firstCompletedIndex = _shoppingList.indexWhere((item) => item['checked'] as bool);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _shoppingList.length,
      itemBuilder: (context, index) {
        if (firstCompletedIndex != -1 && index == firstCompletedIndex) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('已完成', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildListItem(index),
            ],
          );
        }
        return _buildListItem(index);
      },
    );
  }

  Widget _buildListItem(int index) {
    final item = _shoppingList[index];
    final int id = item['id'];
    final String name = item['name'];
    final bool isChecked = item['checked'];

    return CheckboxListTile(
      title: Text(
        name,
        style: TextStyle(
          decoration: isChecked ? TextDecoration.lineThrough : null,
          color: isChecked ? Colors.grey : null,
        ),
      ),
      value: isChecked,
      onChanged: (bool? value) => _handleItemChecked(id, name, value),
      secondary: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
        tooltip: '删除',
        onPressed: () => _removeItem(id),
      ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}