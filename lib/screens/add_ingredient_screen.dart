// lib/screens/add_ingredient_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onecup/providers/cocktail_providers.dart';
import 'package:onecup/search/ingredient_search_delegate.dart';

class AddIngredientScreen extends ConsumerStatefulWidget {
  const AddIngredientScreen({super.key});

  @override
  ConsumerState<AddIngredientScreen> createState() => _AddIngredientScreenState();
}

class _AddIngredientScreenState extends ConsumerState<AddIngredientScreen> {
  List<Map<String, dynamic>> _allIngredients = [];
  Map<String, List<Map<String, dynamic>>> _groupedIngredients = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadIngredients() async {
    if (!mounted) return;
    final data = await ref.read(cocktailRepositoryProvider).getIngredientsForBarManagement();
    if (mounted) {
      setState(() {
        _allIngredients = data;
        _groupIngredients(data);
        _isLoading = false;
      });
    }
  }

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

  void _toggleIngredient(Map<String, dynamic> ingredient) async {
    final cocktailRepository = ref.read(cocktailRepositoryProvider);
    bool isInInventory = ingredient['in_inventory'];
    if (isInInventory) {
      await cocktailRepository.removeIngredientFromInventory(ingredient['id']);
    } else {
      await cocktailRepository.addIngredientToInventory(ingredient['id']);
    }
    _updateLocalIngredientState(ingredient['id'], !isInInventory);
  }

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

  void _showSearch() async {
    final bool? hasChanged = await showSearch<bool>(
      context: context,
      delegate: IngredientSearchDelegate(
        allIngredients: _allIngredients,
        onToggle: _toggleIngredient,
      ),
    );
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