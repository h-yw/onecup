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
  String? _error; // 新增：用于存储错误信息

  @override
  void initState() {
    super.initState();
    _loadMyBar();
  }

  Future<void> _loadMyBar() async {
    setState(() {
      _isLoading = true;
      _error = null; // 重置错误状态
    });
    try {
      final allIngredients = await _dbHelper.getIngredientsForBarManagement();
      setState(() {
        _myIngredients = allIngredients.where((ing) => ing['in_inventory']).toList();
        _isLoading = false;
      });
    } catch (e) {
      // FIX: 捕获任何可能发生的错误
      setState(() {
        _isLoading = false;
        _error = '加载您的酒柜失败，请稍后重试。\n错误详情: $e';
      });
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_myIngredients.isEmpty) {
      return const Center(child: Text('你的酒柜是空的，点击右上角添加配料吧！'));
    }
    return ListView.builder(
      itemCount: _myIngredients.length,
      itemBuilder: (context, index) {
        final ingredient = _myIngredients[index];
        return ListTile(
          title: Text(ingredient['name']),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              await _dbHelper.removeIngredientFromInventory(ingredient['id']);
              _loadMyBar();
            },
          ),
        );
      },
    );
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
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddIngredientScreen()),
              );
              _loadMyBar();
            },
          )
        ],
      ),
      // FIX: 使用一个构建方法来处理不同的UI状态
      body: _buildBody(),
    );
  }
}