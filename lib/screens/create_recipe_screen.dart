// lib/screens/create_recipe_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:onecup/database/database_helper.dart';
import 'package:onecup/models/receip.dart';
import 'package:onecup/models/recipe_ingredient.dart';
import '../common/show_top_banner.dart';

class CreateRecipeScreen extends StatefulWidget {
  const CreateRecipeScreen({super.key});

  @override
  State<CreateRecipeScreen> createState() => _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends State<CreateRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructionsController = TextEditingController();

  final List<RecipeIngredient> _ingredients = [];
  String? _selectedGlass;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isSaving = false;

  List<String> _allIngredientNames = [];
  List<String> _allGlassNames = [];

  @override
  void initState() {
    super.initState();
    _loadAutocompleteData();
  }

  Future<void> _loadAutocompleteData() async {
    final ingredientsData = await _dbHelper.getIngredientsForBarManagement();
    final glassesData = await _dbHelper.getAllGlasswareNames();
    if (mounted) {
      setState(() {
        _allIngredientNames = ingredientsData.map((e) => e['name'] as String).toList();
        _allGlassNames = glassesData;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _saveRecipe() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_ingredients.isEmpty) {
        showTopBanner(context, '请至少添加一种配料', isError: true);
        return;
      }

      setState(() { _isSaving = true; });

      final ingredientsJson = jsonEncode(_ingredients.map((e) => e.toMap()).toList());

      final fullInstructions = """
      ---INGREDIENTS---
      $ingredientsJson
      ---INSTRUCTIONS---
      ${_instructionsController.text}
      """;

      final newRecipe = Recipe(
        id: 0,
        name: _nameController.text,
        description: _descriptionController.text,
        instructions: fullInstructions,
        category: '我的创作',
        glass: _selectedGlass,
      );

      try {
        await _dbHelper.addCustomRecipe(newRecipe);
        if (mounted) {
          showTopBanner(context, '配方已成功保存！');
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          showTopBanner(context, '保存失败: $e', isError: true);
        }
      } finally {
        if(mounted) {
          setState(() { _isSaving = false; });
        }
      }
    }
  }

  void _showAddIngredientDialog() {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final unitController = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加配料'),
          content: Form(
            key: dialogFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return _allIngredientNames.where((name) =>
                          name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (String selection) {
                      nameController.text = selection;
                    },
                    fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: (text) => nameController.text = text,
                        decoration: const InputDecoration(labelText: '配料名称*'),
                        validator: (v) => v!.isEmpty ? '名称不能为空' : null,
                      );
                    },
                  ),
                  TextFormField(
                    controller: quantityController,
                    decoration: const InputDecoration(labelText: '用量*', hintText: '例如: 45'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? '用量不能为空' : null,
                  ),
                  TextFormField(
                    controller: unitController,
                    decoration: const InputDecoration(labelText: '单位', hintText: '例如: ml, oz, 滴'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            ElevatedButton(
              onPressed: () {
                if (dialogFormKey.currentState?.validate() ?? false) {
                  setState(() {
                    _ingredients.add(RecipeIngredient(
                      name: nameController.text,
                      quantity: double.tryParse(quantityController.text) ?? 0,
                      unit: unitController.text,
                    ));
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('添加'),
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
        title: const Text('创建新配方'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _isSaving
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : IconButton(icon: const Icon(Icons.save_outlined), onPressed: _saveRecipe),
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionCard(
              title: '基本信息',
              children: [
                _buildTextFormField(controller: _nameController, labelText: '配方名称*'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedGlass,
                  decoration: const InputDecoration(labelText: '杯具类型'),
                  items: _allGlassNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                  onChanged: (value) => setState(() => _selectedGlass = value),
                ),
                const SizedBox(height: 16),
                _buildTextFormField(controller: _descriptionController, labelText: '描述或故事', maxLines: 3),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              title: '配料清单*',
              action: IconButton(icon: const Icon(Icons.add), onPressed: _showAddIngredientDialog),
              children: [
                if (_ingredients.isEmpty)
                  const Padding(padding: EdgeInsets.all(16.0), child: Center(child: Text('点击右上角“+”添加配料'))),
                ..._ingredients.map((ing) => ListTile(
                  leading: const Icon(Icons.liquor_outlined),
                  title: Text(ing.name),
                  subtitle: Text('${ing.quantity} ${ing.unit}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                    onPressed: () => setState(() => _ingredients.remove(ing)),
                  ),
                )),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              title: '调制步骤*',
              children: [
                _buildTextFormField(controller: _instructionsController, hintText: '详细说明如何制作...', maxLines: 8, labelText: '调制步骤'),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveRecipe,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(_isSaving ? '正在保存...' : '完成并保存'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, List<Widget> children = const [], Widget? action}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontSize: 18)),
                if (action != null) action,
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    int? maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        alignLabelWithHint: true,
      ),
      maxLines: maxLines,
      validator: (value) {
        if (labelText.endsWith('*') && (value == null || value.isEmpty)) {
          return '此项不能为空';
        }
        return null;
      },
    );
  }
}