// lib/screens/add_ingredient_screen.dart
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  Future<void> _loadIngredients() async {
    final data = await _dbHelper.getIngredientsForBarManagement();
    setState(() {
      _allIngredients = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加配料到酒柜')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _allIngredients.length,
        itemBuilder: (context, index) {
          final ingredient = _allIngredients[index];
          return CheckboxListTile(
            title: Text(ingredient['name']),
            value: ingredient['in_inventory'],
            onChanged: (bool? value) async {
              if (value == true) {
                await _dbHelper.addIngredientToInventory(ingredient['id']);
              } else {
                await _dbHelper.removeIngredientFromInventory(ingredient['id']);
              }
              setState(() {
                _allIngredients[index]['in_inventory'] = value;
              });
            },
          );
        },
      ),
    );
  }
}