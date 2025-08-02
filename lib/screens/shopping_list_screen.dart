// lib/screens/shopping_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onecup/common/show_top_banner.dart';
import 'package:onecup/providers/auth_provider.dart';
import 'package:onecup/providers/cocktail_providers.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  List<Map<String, dynamic>> _allIngredients = [];
  bool _isLoading = true;

  bool get _hasCompletedItems =>
      _shoppingList.any((item) => item['checked'] as bool);

  @override
  void initState() {
    super.initState();
    _loadAllIngredients();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadAllIngredients() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _allIngredients = await ref
        .read(cocktailRepositoryProvider)
        .getIngredientsForBarManagement();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // _shoppingList 现在通过 Riverpod 监听
  List<Map<String, dynamic>> get _shoppingList {
    final shoppingListAsyncValue = ref.watch(shoppingListProvider);
    debugPrint(
      'ShoppingListScreen: shoppingListAsyncValue: $shoppingListAsyncValue',
    );
    return shoppingListAsyncValue.when(
      data: (list) {
        debugPrint('ShoppingListScreen: Raw shopping list data: $list');
        list.sort((a, b) {
          if (a['checked'] == b['checked']) return 0;
          return a['checked'] ? 1 : -1;
        });
        return list;
      },
      loading: () {
        debugPrint('ShoppingListScreen: Shopping list is loading.');
        return [];
      }, // 加载时返回空列表
      error: (err, stack) {
        debugPrint('ShoppingListScreen: Error loading shopping list: $err');
        return [];
      }, // 错误时返回空列表
    );
  }

  Future<void> _addItem(
    String text, {
    required TextEditingController controller,
    required FocusNode focusNode,
  }) async {
    if (text.trim().isNotEmpty) {
      final ingredientId = await ref
          .read(cocktailRepositoryProvider)
          .getIngredientIdByName(text.trim());
      if (ingredientId != null) {
        await ref
            .read(cocktailRepositoryProvider)
            .addToShoppingList(text.trim(), ingredientId);
        controller.clear();
        focusNode.unfocus();
        ref.invalidate(shoppingListProvider); // 刷新购物清单
      } else {
        if (mounted) showTopBanner(context, '未找到该配料，请检查名称。', isError: true);
      }
    }
  }

  Future<void> _removeItem(int id) async {
    await ref.read(cocktailRepositoryProvider).removeFromShoppingList(id);
    ref.invalidate(shoppingListProvider); // 刷新购物清单
  }

  Future<void> _clearCompletedItems() async {
    await ref.read(cocktailRepositoryProvider).clearCompletedShoppingItems();
    ref.invalidate(shoppingListProvider); // 刷新购物清单
    if (mounted) {
      showTopBanner(context, '已清除所有已完成项目');
    }
  }

  Future<void> _handleItemChecked(int id, String name, bool? value) async {
    if (value == null) return;
    await ref
        .read(cocktailRepositoryProvider)
        .updateShoppingListItem(id, value);
    ref.invalidate(shoppingListProvider); // 刷新购物清单

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
                await ref
                    .read(cocktailRepositoryProvider)
                    .addIngredientToInventory(ingredientId);
                Navigator.of(context).pop();
                if (mounted) {
                  showTopBanner(context, '“$name”已添加到您的酒柜！');
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
    final theme = Theme.of(context);
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
                      ? _buildEmptyState(theme)
                      : _buildShoppingListView(theme),
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
          final currentListNames = _shoppingList
              .map((e) => e['name'] as String)
              .toSet();
          return _allIngredients.where((ingredient) {
            final name = ingredient['name'] as String;
            final isAlreadyInList = currentListNames.contains(name);
            final matchesQuery = name.toLowerCase().contains(
              textEditingValue.text.toLowerCase(),
            );
            return matchesQuery && !isAlreadyInList;
          });
        },
        onSelected: (Map<String, dynamic> selection) {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        displayStringForOption: (Map<String, dynamic> option) =>
            option['name'] as String,

        fieldViewBuilder:
            (context, textEditingController, focusNode, onFieldSubmitted) {
              return Material(
                elevation: 2.0,
                shadowColor: theme.shadowColor,
                borderRadius: BorderRadius.circular(15.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: '搜索配料或手动输入...',
                          prefixIcon: Icon(
                            Icons.search,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15.0),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15.0),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15.0),
                            borderSide: BorderSide.none,
                          ),
                          filled: true, // 确保背景被填充
                          fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? Colors.white, // 使用主题的填充色或默认白色
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16.0,
                            horizontal: 8.0,
                          ),
                        ),
                        onSubmitted: (text) => _addItem(
                          text,
                          controller: textEditingController,
                          focusNode: focusNode,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: () => _addItem(
                        textEditingController.text,
                        controller: textEditingController,
                        focusNode: focusNode,
                      ),
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
                      child: ListTile(title: Text(option['name'] as String)),
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

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_checkout, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(
              '购物清单是空的',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '在“仅差一种”或“探索更多”中发现想喝的鸡尾酒，\n或在这里手动添加需要购买的物品吧！',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShoppingListView(ThemeData theme) {
    final int firstCompletedIndex = _shoppingList.indexWhere(
      (item) => item['checked'] as bool,
    );
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
                child: Text(
                  '已完成',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildListItem(theme,index),
            ],
          );
        }
        return _buildListItem(theme,index);
      },
    );
  }

  Widget _buildListItem(ThemeData theme,int index) {
    final item = _shoppingList[index];
    final int id = item['id'];
    final String name = item['name'];
    final bool isChecked = item['checked'];

    return CheckboxListTile(
      title: Text(
        name,
        style: TextStyle(
          decoration: isChecked ? TextDecoration.lineThrough : null,
          color: isChecked ? theme.colorScheme.onSurface.withOpacity(0.6) : null,
        ),
      ),
      value: isChecked,
      onChanged: (bool? value) => _handleItemChecked(id, name, value),
      secondary: IconButton(
        icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
        tooltip: '删除',
        onPressed: () => _removeItem(id),
      ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
