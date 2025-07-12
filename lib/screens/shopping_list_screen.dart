import 'package:flutter/material.dart';
import 'package:onecup/database/database_helper.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  // 现在列表直接从数据库加载，包含id, name, checked
  List<Map<String, dynamic>> _shoppingList = [];
  final TextEditingController _textController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _allIngredients = [];

  @override
  void initState() {
    super.initState();
    _loadAllIngredients();
    _loadShoppingList(); // 初始化时从数据库加载列表
  }

  Future<void> _loadAllIngredients() async {
    _allIngredients = await _dbHelper.getIngredientsForBarManagement();
  }

  // 从数据库加载购物清单
  Future<void> _loadShoppingList() async {
    final data = await _dbHelper.getShoppingList();
    if (mounted) {
      setState(() {
        // checked字段在数据库中是INTEGER（0或1），需要转换为bool
        _shoppingList = data.map((item) {
          return {
            'id': item['id'],
            'name': item['name'],
            'checked': item['checked'] == 1,
          };
        }).toList();
      });
    }
  }

  // 添加项目到数据库并刷新
  Future<void> _addItem() async {
    if (_textController.text.isNotEmpty) {
      await _dbHelper.addToShoppingList(_textController.text);
      _textController.clear();
      _loadShoppingList(); // 重新加载列表以显示新项目
    }
  }

  // 从数据库删除项目并刷新
  Future<void> _removeItem(int id) async {
    await _dbHelper.removeFromShoppingList(id);
    _loadShoppingList(); // 重新加载列表
  }

  // 更新数据库中的项目状态并刷新
  Future<void> _handleItemChecked(int id, String name, bool? value) async {
    if (value == null) return;

    await _dbHelper.updateShoppingListItem(id, value);
    _loadShoppingList(); // 重新加载以更新UI

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

  // 显示添加到“我的酒柜”的确认对话框 (此部分逻辑不变)
  Future<void> _showAddToBarDialog(String name, int ingredientId) async {
    // ... 对话框代码和之前一样 ...
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('添加到酒柜?'),
          content: Text('您已购买“$name”。要现在就将它添加到您的酒柜吗？'),
          actions: [
            TextButton(
              child: const Text('不了，谢谢'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('添加到酒柜'),
              onPressed: () async {
                await _dbHelper.addIngredientToInventory(ingredientId);
                Navigator.of(context).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('“$name”已添加到您的酒柜！')),
                  );
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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: '添加物品...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _addItem(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  onPressed: _addItem,
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _shoppingList.isEmpty
                ? const Center(child: Text('您的购物清单是空的。'))
                : ListView.builder(
              itemCount: _shoppingList.length,
              itemBuilder: (context, index) {
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
                  onChanged: (bool? value) {
                    _handleItemChecked(id, name, value);
                  },
                  secondary: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _removeItem(id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}