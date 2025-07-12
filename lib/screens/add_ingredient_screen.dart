import 'package:flutter/material.dart';
import 'package:onecup/database/database_helper.dart';

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
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadIngredients();
    _searchController.addListener(() {
      _filterIngredients(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadIngredients() async {
    final data = await _dbHelper.getIngredientsForBarManagement();
    if (mounted) {
      setState(() {
        _allIngredients = data;
        _groupIngredients(data);
        _isLoading = false;
      });
    }
  }

  void _filterIngredients(String query) {
    final filtered = query.isEmpty
        ? _allIngredients
        : _allIngredients.where((ing) => ing['name'].toLowerCase().contains(query.toLowerCase())).toList();
    setState(() {
      _groupIngredients(filtered);
    });
  }

  void _groupIngredients(List<Map<String, dynamic>> ingredients) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (var ingredient in ingredients) {
      final category = ingredient['category'];
      if (groups[category] == null) {
        groups[category] = [];
      }
      groups[category]!.add(ingredient);
    }
    _groupedIngredients = groups;
  }

  @override
  Widget build(BuildContext context) {
    var categoryKeys = _groupedIngredients.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('添加配料到酒柜')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索配料...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
              ),
            ),
          ),
          Expanded(
            child: _groupedIngredients.isEmpty
                ? const Center(child: Text("没有找到匹配的配料"))
                : ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: _groupedIngredients.length,
              itemBuilder: (context, index) {
                String category = categoryKeys[index];
                var ingredients = _groupedIngredients[category]!;
                return ExpansionTile(
                  title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  initiallyExpanded: true,
                  children: ingredients.map((ingredient) {
                    return CheckboxListTile(
                      title: Text(ingredient['name']),
                      value: ingredient['in_inventory'],
                      onChanged: (bool? value) async {
                        if (value == true) {
                          await _dbHelper.addIngredientToInventory(ingredient['id']);
                        } else {
                          await _dbHelper.removeIngredientFromInventory(ingredient['id']);
                        }
                        // 更新UI状态
                        setState(() {
                          final originalIndex = _allIngredients.indexWhere((el) => el['id'] == ingredient['id']);
                          if(originalIndex != -1) {
                            _allIngredients[originalIndex]['in_inventory'] = value;
                            // No need to call filter again, just update the model
                            ingredient['in_inventory'] = value;
                          }
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}