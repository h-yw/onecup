// lib/search/ingredient_search_delegate.dart

import 'package:flutter/material.dart';

class IngredientSearchDelegate extends SearchDelegate<bool> {
  final List<Map<String, dynamic>> allIngredients;
  final Function(Map<String, dynamic>) onToggle;

  // 用于在搜索会话中跟踪状态变化
  final Map<int, bool> _updatedIngredients = {};

  IngredientSearchDelegate({required this.allIngredients, required this.onToggle});

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 1.0,
        iconTheme: theme.iconTheme,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.grey[500]),
        border: InputBorder.none,
      ),
    );
  }

  @override
  String get searchFieldLabel => '搜索配料...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        // 关闭时返回是否有更新
        close(context, _updatedIngredients.isNotEmpty);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final filteredList = query.isEmpty
        ? [] // 初始不显示任何内容
        : allIngredients
        .where((ing) => ing['name'].toLowerCase().contains(query.toLowerCase()))
        .toList();

    if (query.isNotEmpty && filteredList.isEmpty) {
      return const Center(child: Text('没有找到匹配的配料。'));
    }

    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        return ListView.builder(
          itemCount: filteredList.length,
          itemBuilder: (context, index) {
            final ingredient = filteredList[index];
            final int id = ingredient['id'];
            // 优先使用本次搜索会话中更新的状态
            final bool isInInventory = _updatedIngredients[id] ?? ingredient['in_inventory'];

            return CheckboxListTile(
              title: Text(ingredient['name']),
              subtitle: Text(ingredient['category']),
              value: isInInventory,
              onChanged: (bool? value) {
                if (value == null) return;
                setState(() {
                  _updatedIngredients[id] = value;
                  // 立即调用回调来更新数据库
                  final Map<String, dynamic> toggledIngredient = {
                    ...ingredient,
                    'in_inventory': !value, // 注意：onToggle需要的是“之前的”状态
                  };
                  onToggle(toggledIngredient);
                });
              },

            );
          },
        );
      },
    );
  }
}