// lib/screens/my_bar_screen.dart
import 'package:flutter/material.dart';
import 'package:onecup/database/database_helper.dart';
import 'package:onecup/screens/add_ingredient_screen.dart';
class MyBarScreen extends StatefulWidget {
  const MyBarScreen({super.key});

  @override
  State<MyBarScreen> createState() => _MyBarScreenState();
}

class _MyBarScreenState extends State<MyBarScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _myIngredients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyBar();
  }

  // 加载或刷新我的酒柜列表
  Future<void> _loadMyBar() async {
    setState(() => _isLoading = true);
    final allIngredients = await _dbHelper.getIngredientsForBarManagement();
    setState(() {
      _myIngredients = allIngredients.where((ing) => ing['in_inventory']).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的酒柜'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              // 导航到添加页面，并在返回后刷新列表
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddIngredientScreen()),
              );
              _loadMyBar();
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myIngredients.isEmpty
          ? const Center(child: Text('你的酒柜是空的，点击右上角添加配料吧！'))
          : ListView.builder(
        itemCount: _myIngredients.length,
        itemBuilder: (context, index) {
          final ingredient = _myIngredients[index];
          return ListTile(
            title: Text(ingredient['name']),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                await _dbHelper.removeIngredientFromInventory(ingredient['id']);
                _loadMyBar(); // 移除后刷新
              },
            ),
          );
        },
      ),
    );
  }
}