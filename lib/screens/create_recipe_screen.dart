// lib/screens/create_recipe_screen.dart

import 'package:flutter/material.dart';
import 'package:onecup/database/supabase_service.dart';
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

  final List<_IngredientController> _ingredientControllers = [];
  String? _selectedGlass;

  final SupabaseService _supabaseService = SupabaseService();
  bool _isSaving = false;
  bool _isLoadingAutocomplete = true;

  List<String> _allIngredientNames = [];
  List<String> _allGlassNames = [];

  @override
  void initState() {
    super.initState();
    _loadAutocompleteData();
    // 默认添加一行空的配料输入
    _addIngredientField();
  }

  Future<void> _loadAutocompleteData() async {
    try {
      final ingredientsData = await _supabaseService.getIngredientsForBarManagement();
      final glassesData = await _supabaseService.getAllGlasswareNames();
      if (mounted) {
        setState(() {
          _allIngredientNames = ingredientsData.map((e) => e['name'] as String).toList();
          _allGlassNames = glassesData;
        });
      }
    } catch (e) {
      if(mounted) showTopBanner(context, "加载配料数据失败", isError: true);
    } finally {
      if(mounted) setState(() => _isLoadingAutocomplete = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    for (var controller in _ingredientControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveRecipe() async {
    // 1. 验证主表单
    if (!(_formKey.currentState?.validate() ?? false)) {
      showTopBanner(context, '请检查顶部的必填项', isError: true);
      return;
    }

    // 2. 验证所有激活的配料行
    bool allIngredientsValid = true;
    for (var controller in _ingredientControllers) {
      if (controller.isActive) { // 只验证被用户填写过的行
        if (!(controller.formKey.currentState?.validate() ?? false)) {
          allIngredientsValid = false;
        }
      }
    }

    if (!allIngredientsValid) {
      showTopBanner(context, '请检查配料清单中的红色错误提示', isError: true);
      return;
    }

    // 3. 收集有效的配料数据
    final List<RecipeIngredient> ingredients = [];
    for (var controller in _ingredientControllers) {
      if(controller.isActive) {
        final name = controller.nameKey.currentState?.value as String;
        final quantityStr = controller.quantityController.text.trim();
        ingredients.add(RecipeIngredient(
          name: name,
          quantity: double.parse(quantityStr),
          unit: controller.unitController.text.trim(),
        ));
      }
    }

    if (ingredients.isEmpty) {
      showTopBanner(context, '请至少添加一种有效的配料', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final newRecipe = Recipe(
      id: 0,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
      instructions: _instructionsController.text.trim(),
      category: '我的创作',
      glass: _selectedGlass,
    );

    try {
      final newRecipeId = await _supabaseService.addCustomRecipe(newRecipe, ingredients);
      if (mounted) {
        showTopBanner(context, '配方已成功保存！');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showTopBanner(context, '保存失败: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addIngredientField() {
    setState(() {
      _ingredientControllers.add(_IngredientController());
    });
  }

  void _removeIngredientField(int index) {
    setState(() {
      // 必须先 dispose 控制器，再从列表中移除
      _ingredientControllers[index].dispose();
      _ingredientControllers.removeAt(index);
    });
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
                ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3.0)))
                : IconButton(icon: const Icon(Icons.save_outlined), onPressed: _saveRecipe, tooltip: '保存'),
          )
        ],
      ),
      // [核心修复] 整个页面只使用这一个 ListView
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 100.0),
        children: [
          Form(
            key: _formKey,
            child: _buildSectionCard(
              title: '基本信息',
              child: Column(
                children: [
                  _buildTextFormField(controller: _nameController, labelText: '配方名称*'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedGlass,
                    decoration: const InputDecoration(labelText: '杯具类型*'),
                    items: _allGlassNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                    onChanged: (value) => setState(() => _selectedGlass = value),
                    validator: (value) => value == null ? '请选择杯具' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(controller: _descriptionController, labelText: '描述或故事', maxLines: 3, isRequired: false),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionCard(
            title: '配料清单*',
            // [核心修复] 使用 Column 替代 ListView.separated
            child: Column(
              children: [
                ..._ingredientControllers.asMap().entries.map((entry) {
                  int index = entry.key;
                  _IngredientController controller = entry.value;
                  // [核心修复] 为每个动态行提供一个稳定且唯一的 ValueKey
                  return Padding(
                    key: ValueKey(controller),
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: _buildIngredientInputRow(index: index),
                  );
                }),
                const SizedBox(height: 12),
                if (_isLoadingAutocomplete)
                  const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                else
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('添加更多配料'),
                      onPressed: _addIngredientField,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionCard(
            title: '调制步骤',
            child: _buildTextFormField(
              controller: _instructionsController,
              hintText: '详细说明如何制作...',
              maxLines: 8,
              labelText: '调制步骤',
              isRequired: false,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveRecipe,
        icon: const Icon(Icons.check_circle_outline),
        label: Text(_isSaving ? '正在保存...' : '完成并保存'),
      ),
    );
  }

  Widget _buildIngredientInputRow({required int index}) {
    final controller = _ingredientControllers[index];
    final theme = Theme.of(context);

    return Form(
      key: controller.formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
              return _allIngredientNames.where((name) => name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
            },
            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
              return TextFormField(
                key: controller.nameKey,
                controller: textEditingController,
                focusNode: focusNode,
                decoration: const InputDecoration(labelText: '配料名称*'),
                validator: (value) {
                  // 只在用户开始填写这行时才进行验证
                  if (controller.isActive && (value == null || value.isEmpty)) {
                    return '名称不能为空';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}), // 触发UI更新以检查isActive状态
                onFieldSubmitted: (_) => onFieldSubmitted(),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 200, maxWidth: MediaQuery.of(context).size.width - 64),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final option = options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Padding(padding: const EdgeInsets.all(16.0), child: Text(option)),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
            onSelected: (String selection) {
              controller.nameKey.currentState?.didChange(selection);
              setState(() {}); // 触发UI更新以检查isActive状态
            },
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: controller.quantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '用量*'),
                  onChanged: (_) => setState(() {}), // 触发UI更新以检查isActive状态
                  validator: (value) {
                    if (controller.isActive && (value == null || value.isEmpty)) {
                      return '用量不能为空';
                    }
                    if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                      return '无效数字';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: TextFormField(controller: controller.unitController, decoration: const InputDecoration(labelText: '单位', hintText: 'ml'))),
              IconButton(
                padding: const EdgeInsets.only(top: 8),
                icon: Icon(
                  Icons.delete_outline,
                  color: _ingredientControllers.length > 1 ? theme.colorScheme.error : Colors.grey,
                ),
                onPressed: _ingredientControllers.length > 1 ? () => _removeIngredientField(index) : null,
                tooltip: '移除此配料',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.withOpacity(0.2)), borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontSize: 18)),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({required TextEditingController controller, required String labelText, String? hintText, int? maxLines = 1, bool isRequired = true}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: labelText, hintText: hintText, alignLabelWithHint: true),
      maxLines: maxLines,
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return '此项不能为空';
        }
        return null;
      },
    );
  }
}

class _IngredientController {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final GlobalKey<FormFieldState<String>> nameKey = GlobalKey<FormFieldState<String>>();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController unitController = TextEditingController();

  // 辅助 getter，用于判断用户是否已开始填写该行
  bool get isActive {
    // 检查 nameKey.currentState 是否为 null，因为在 widget 首次构建时它可能还不存在
    final nameValue = nameKey.currentState?.value;
    return (nameValue != null && nameValue.isNotEmpty) || quantityController.text.isNotEmpty;
  }

  void dispose() {
    quantityController.dispose();
    unitController.dispose();
  }
}