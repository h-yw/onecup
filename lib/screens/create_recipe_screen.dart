// lib/screens/create_recipe_screen.dart

import 'package:flutter/material.dart';
import 'package:onecup/database/supabase_service.dart';
import 'package:onecup/models/receip.dart';
import 'package:onecup/models/recipe_ingredient.dart';
import 'package:onecup/widgets/searchable_selection_dialog.dart';
import '../common/show_top_banner.dart';
import '../widgets/glass_selection_dialog.dart';

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
  final List<GlobalKey<FormFieldState>> _formFieldKeys = [];
  String? _selectedGlass;
  final GlobalKey<FormFieldState<String>> _glassFormFieldKey = GlobalKey<FormFieldState<String>>();

  final SupabaseService _supabaseService = SupabaseService();
  bool _isSaving = false;
  bool _isLoadingAutocomplete = true;

  List<String> _allIngredientNames = [];
  List<String> _allGlassNames = [];

  _IngredientController? _lastActivatedIngredientForAutoAdd;

  @override
  void initState() {
    super.initState();
    _loadAutocompleteData();
    // 默认添加一行空的配料输入
    _addIngredientField(isInitial: true);
  }

  Future<void> _loadAutocompleteData() async {
    try {
      final ingredientsData = await _supabaseService
          .getIngredientsForBarManagement();
      final glassesData = await _supabaseService.getAllGlasswareNames();
      if (mounted) {
        setState(() {
          _allIngredientNames = ingredientsData
              .map((e) => e['name'] as String)
              .toList();
          _allGlassNames = glassesData;
        });
      }
    } catch (e) {
      if (mounted) showTopBanner(context, "加载配料数据失败", isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingAutocomplete = false);
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

  Future<void> _showGlassSelectionDialog() async {
    if (_allGlassNames.isEmpty && !_isLoadingAutocomplete) {
      showTopBanner(context, '杯具列表为空，无法选择。', isError: true);
      return;
    }
    if (_isLoadingAutocomplete) return; // 正在加载时不允许打开

    final String? result = await showDialog<String>(
      context: context,
      barrierDismissible: false, // 防止点击外部关闭，强制用户通过按钮操作
      builder: (BuildContext dialogContext) { // 使用 dialogContext 避免与外部 context 混淆
        return GlassSelectionDialog(
          allGlassNames: _allGlassNames,
          currentSelectedGlass: _selectedGlass,
        );
      },
    );

    // 用户通过 "确定" 或 "取消" 关闭对话框
    // 如果 result 是 null (用户点了取消或外部关闭，但我们有 barrierDismissible: false)，则不改变 _selectedGlass
    // 如果 result 不是 null (用户点了确定且有选择)，则更新
    if (result != null) {
      setState(() {
        _selectedGlass = result;
        _glassFormFieldKey.currentState?.didChange(_selectedGlass); // 更新 FormField 的状态并触发验证
        _glassFormFieldKey.currentState?.validate(); // 立即验证
      });
    } else {
      // 如果用户取消，并且之前有选择，我们可能希望保持该选择
      // 如果用户取消，并且之前没有选择，_selectedGlass 仍然是 null
      // 这里的逻辑是，如果取消，则不改变当前 _selectedGlass 的值
      // 为了确保验证正确，如果取消后 _selectedGlass 仍然是null，也应该通知FormField
      _glassFormFieldKey.currentState?.didChange(_selectedGlass);
      _glassFormFieldKey.currentState?.validate();
    }
  }

  Future<void> _showIngredientSelectionDialog(_IngredientController controller) async {
    if (_allIngredientNames.isEmpty && !_isLoadingAutocomplete) {
      showTopBanner(context, '配料列表为空，无法选择。', isError: true);
      return;
    }
    if (_isLoadingAutocomplete) return;

    final String? result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return SearchableSelectionDialog(
          allItems: _allIngredientNames,
          currentSelectedItem: controller.selectedIngredientName,
          title: '选择配料',
          searchHintText: '搜索配料名称...',
          noResultsText: '未找到匹配的配料。',
        );
      },
    );

    // No need to check for null here if the dialog's "OK" handles it
    // The dialog's OK button will return the current selection if nothing new is chosen
    controller.setSelectedIngredientName(result);
    if (mounted) {
      setState(() {}); // Update UI to reflect changes in isActive or displayed name
    }
    _handleAutoAddIngredient(controller); // Trigger auto-add if a name was selected

    // Optionally, move focus to the quantity field after selection
    if (result != null && result.isNotEmpty) {
      FocusScope.of(context).requestFocus(controller.quantityFocusNode);
    }
  }

  Future<void> _saveRecipe() async {
    //  验证主表单
    if (!(_formKey.currentState?.validate() ?? false)) {
      showTopBanner(context, '请检查顶部的必填项', isError: true);
      _scrollToFirstError();
      return;
    }

    // 验证所有激活的配料行
    bool allIngredientsValid = true;
    int activeIngredientsCount = 0;
    for (var controller in _ingredientControllers) {
      if (controller.isActive) {
        activeIngredientsCount++;
        if (!(controller.formKey.currentState?.validate() ?? false)) {
          allIngredientsValid = false;
        }
      }
    }

    if (!allIngredientsValid) {
      showTopBanner(context, '请检查配料清单中的红色错误提示', isError: true);
      return;
    }
    if (activeIngredientsCount == 0) {
      showTopBanner(context, '请至少添加一种有效的配料', isError: true);
      return;
    }

    //  收集有效的配料数据
    final List<RecipeIngredient> ingredients = [];
    for (var controller in _ingredientControllers) {
      if (controller.isActive) {
        final name = controller.nameKey.currentState?.value as String;
        final quantityStr = controller.quantityController.text.trim();
        final unit = controller.unitController.text.trim();
        if (name == null || name.isEmpty) {
          if (mounted) showTopBanner(context, '部分配料名称缺失，请检查', isError: true);
          return;
        }
        if (quantityStr.isEmpty) {
          if (mounted) showTopBanner(context, '配料 "$name" 的用量不能为空', isError: true);
          return;
        }
        if (unit.isEmpty) {
          if (mounted) showTopBanner(context, '配料 "$name" 的单位不能为空', isError: true);
          return;
        }
        final quantity = double.tryParse(quantityStr);
        if (quantity == null) {
          if (mounted) showTopBanner(context, '配料 "$name" 的用量 "$quantityStr" 不是有效数字', isError: true);
          return;
        }

        ingredients.add(
          RecipeIngredient(
            name: name,
            quantity: double.parse(quantityStr),
            unit: controller.unitController.text.trim(),
          ),
        );
      }
    }
    if (ingredients.isEmpty && activeIngredientsCount > 0) {
      if (mounted) showTopBanner(context, '未能成功收集配料数据，尽管有激活的行。请重试。', isError: true);
      setState(() => _isSaving = false); // 重置保存状态
      return;
    }
    if (ingredients.isEmpty && activeIngredientsCount == 0) { // 以防万一，虽然上面的检查应该已经捕获
      if (mounted) showTopBanner(context, '没有有效的配料被添加。', isError: true);
      setState(() => _isSaving = false);
      return;
    }
    setState(() => _isSaving = true);

    final newRecipe = Recipe(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      instructions: _instructionsController.text.trim(),
      category: '我的创作',
      glass: _selectedGlass,
    );

    try {
      final newRecipeId = await _supabaseService.addCustomRecipe(
        newRecipe,
        ingredients,
      );
      if (mounted) {
        showTopBanner(context, '配方已成功保存！');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showTopBanner(context, '保存失败: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _scrollToFirstError() async {
    for (var key in _formFieldKeys) {
      // 假设 _formFieldKeys 包含了所有需要检查的字段的key
      if (key.currentState?.hasError ?? false) {
        if (key.currentContext != null) {
          await Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          break;
        }
      }
    }
    // 对于动态配料行，你需要更精细的 Key 管理和遍历逻辑
  }

  void _addIngredientField({bool isInitial = false}) {
    final newController = _IngredientController();
    newController.onNameChangedForAutAdd = () {
      _handleAutoAddIngredient(newController);
    };
    setState(() {
      _ingredientControllers.add(newController);
      if (!isInitial && _ingredientControllers.length > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(context).requestFocus(newController.nameFocusNode);
        });
      }
    });
  }

  void _handleAutoAddIngredient(_IngredientController currentController) {
    // 确保这是列表中的最后一个控制器，并且它之前没有触发过自动添加
    if (currentController == _ingredientControllers.last &&
        _lastActivatedIngredientForAutoAdd != currentController) {
      if (mounted) {
        setState(() {
          _lastActivatedIngredientForAutoAdd = currentController;
          _addIngredientField();
        });
      }
    }
  }

  void _removeIngredientField(int index) {
    print("index=====>$index");
    if (_ingredientControllers.length <= 1 &&
        _ingredientControllers[index].isActive) {
      showTopBanner(context, '至少需要保留一种配料，或清空当前行内容', isError: true);
      return;
    }
    // 如果删除的是正在用于自动添加的行，重置它
    if (_lastActivatedIngredientForAutoAdd == _ingredientControllers[index]) {
      _lastActivatedIngredientForAutoAdd = null;
    }

    setState(() {
      _ingredientControllers[index].dispose();
      _ingredientControllers.removeAt(index);
      // 如果移除后列表为空，则添加一个新行
      if (_ingredientControllers.isEmpty) {
        _addIngredientField(isInitial: true);
      }
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
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3.0,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.save_outlined),
                    onPressed: _saveRecipe,
                    tooltip: '保存配方',
                  ),
          ),
        ],
      ),
      // 整个页面只使用这一个 ListView
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 100.0),
        children: [
          Form(
            key: _formKey,
            child: _buildSectionCard(
              title: '基本信息',
              child: Column(
                children: [
                  _buildTextFormField(
                    controller: _nameController,
                    labelText: '配方名称*',
                  ),
                  const SizedBox(height: 16),
                  FormField<String>(
                    key: _glassFormFieldKey, // 关联 GlobalKey
                    // initialValue: _selectedGlass, // FormField 会自动从 builder 获取初始状态
                    validator: (value) {
                      // 验证器现在检查 _selectedGlass 状态变量
                      if (_selectedGlass == null) {
                        return '请选择杯具类型';
                      }
                      return null;
                    },
                    builder: (FormFieldState<String> field) {
                      // field.value 不需要在这里直接使用，我们依赖 _selectedGlass
                      // field.errorText 会显示验证错误
                      return InkWell(
                        onTap: _isLoadingAutocomplete ? null : _showGlassSelectionDialog,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: '杯具类型*',
                            errorText: field.errorText, // 显示验证错误
                            suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          ),
                          child: Text(
                            _selectedGlass ?? '请选择...', // 显示当前选择或提示
                            style: TextStyle(
                              fontSize: 16.0, // 与 TextFormField 文本大小类似
                              color: _selectedGlass == null && field.hasError
                                  ? Theme.of(context).colorScheme.error // 错误时使用主题错误色
                                  : _selectedGlass == null
                                  ? Theme.of(context).hintColor
                                  : Theme.of(context).textTheme.bodyLarge?.color, // 正常文本颜色
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _descriptionController,
                    labelText: '描述或故事',
                    maxLines: 3,
                    isRequired: false,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildIngredientsSection(),
          const SizedBox(height: 8),
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

  Widget _buildIngredientsSection() {
    return _buildSectionCard(
      title: '配料清单*',
      child: Column(
        children: [
          if (_isLoadingAutocomplete)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_ingredientControllers.isEmpty && !_isLoadingAutocomplete)
            Padding(
              // 初始为空时的提示
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Text(
                '请添加配料来开始创建您的配方。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true, // 重要：在 Column 中使用 ListView 需要这个
              physics: const NeverScrollableScrollPhysics(), // 以及这个来禁止内部滚动
              itemCount: _ingredientControllers.length,
              itemBuilder: (context, index) {
                final controller = _ingredientControllers[index];
                // 为每个动态行提供一个稳定且唯一的 ValueKey
                return Padding(
                  key: ValueKey(controller), // 使用控制器实例作为Key
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: [
                      _buildIngredientInputRow(
                        index: index,
                        controller: controller,
                      ),
                      if (index < _ingredientControllers.length - 1)
                        const Divider(
                          height: 32,
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          if (!_isLoadingAutocomplete)
            Center(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('添加配料行'),
                onPressed: () => _addIngredientField(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIngredientInputRow({required int index, required _IngredientController controller}) {
    return Form(
      key: controller.formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                // --- Replace Autocomplete with FormField and InkWell ---
                child: FormField<String>(
                  key: controller.nameKey, // Use the nameKey from _IngredientController
                  // initialValue: controller.selectedIngredientName, // Handled by builder
                  validator: (value) {
                    // Validation now relies on _selectedIngredientName via controller.isActive or directly
                    if (controller.isActive && (controller.selectedIngredientName == null || controller.selectedIngredientName!.isEmpty)) {
                      return '名称不能为空';
                    }
                    return null;
                  },
                  builder: (FormFieldState<String> field) {
                    // Update field value if controller's selected name changes externally
                    // This can happen if we reset the controller or something.
                    // However, setSelectedIngredientName already calls field.didChange.
                    // if (field.value != controller.selectedIngredientName) {
                    //   WidgetsBinding.instance.addPostFrameCallback((_) {
                    //     field.didChange(controller.selectedIngredientName);
                    //   });
                    // }

                    return InkWell(
                      onTap: _isLoadingAutocomplete ? null : () => _showIngredientSelectionDialog(controller),
                      focusNode: controller.nameFocusNode, // Optional: for accessibility
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: '配料名称*',
                          errorText: field.errorText,
                          // No suffixIcon needed like the dropdown arrow for glasses
                        ),
                        child: Text(
                          controller.selectedIngredientName ?? '请选择配料...',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: controller.selectedIngredientName == null && field.hasError
                                ? Theme.of(context).colorScheme.error
                                : controller.selectedIngredientName == null
                                ? Theme.of(context).hintColor
                                : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // --- End of replacement ---
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 8.0), // 调整 IconButton 位置
                child: IconButton(
                  icon: Icon(Icons.remove_circle_outline, color:index<1? Colors.grey:Colors.redAccent),
                  tooltip: '移除此配料',
                  onPressed: () => _removeIngredientField(index),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: controller.quantityController,
                  focusNode: controller.quantityFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '用量*', hintText: '如: 1.5'),
                  onChanged: (_) => setState(() {}), // 触发UI更新以检查isActive状态
                  validator: (value) {
                    if (controller.isActive && (value == null || value.isEmpty)) return '用量不能为空';
                    if (value != null && value.isNotEmpty && double.tryParse(value) == null) return '请输入有效数字';
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(controller.unitFocusNode),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: controller.unitController,
                  focusNode: controller.unitFocusNode,
                  decoration: const InputDecoration(labelText: '单位*', hintText: '如: ml'),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (controller.isActive && (value == null || value.isEmpty)) return '单位不能为空';
                    return null;
                  },
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    // 如果这是最后一个配料行，并且用户按了 done，可以考虑自动添加新行并聚焦
                    if (index == _ingredientControllers.length - 1) {
                      _addIngredientField(); // 已经包含了聚焦逻辑
                    } else {
                      // 否则，尝试聚焦到下一个控件（比如调制步骤，如果适用）
                      FocusScope.of(context).nextFocus();
                    }
                  },
                ),
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
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(fontSize: 18),
            ),
            const Divider(height: 24),
            child,
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
    bool isRequired = true,
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
  final GlobalKey<FormFieldState<String>> nameKey =
      GlobalKey<FormFieldState<String>>();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController unitController = TextEditingController();

  final FocusNode nameFocusNode = FocusNode();
  final FocusNode quantityFocusNode = FocusNode();
  final FocusNode unitFocusNode = FocusNode();

  String? _selectedIngredientName; // To store the selected ingredient name
  String? get selectedIngredientName => _selectedIngredientName;
  VoidCallback? onNameChangedForAutAdd;

  void setSelectedIngredientName(String? name) {
    bool wasEmpty = _selectedIngredientName == null || _selectedIngredientName!.isEmpty;
    _selectedIngredientName = name;

    // Crucially, update the FormField's state so validation works
    nameKey.currentState?.didChange(_selectedIngredientName);
    nameKey.currentState?.validate(); // Optional: immediate validation

    if (wasEmpty && (_selectedIngredientName != null && _selectedIngredientName!.isNotEmpty) && onNameChangedForAutAdd != null) {
      onNameChangedForAutAdd!();
    } else if ((_selectedIngredientName != null && _selectedIngredientName!.isNotEmpty) && onNameChangedForAutAdd != null) {
      // Also trigger if it was already filled and changed, for auto-add logic
      onNameChangedForAutAdd!();
    }
  }

  // 辅助 getter，用于判断用户是否已开始填写该行
  bool get isActive =>
      nameKey.currentState?.value?.isNotEmpty == true ||
      quantityController.text.isNotEmpty ||
      unitController.text.isNotEmpty;

  _IngredientController() {

  }

  void _handleNameChange() {
    if (nameKey.currentState?.value?.isNotEmpty == true) {
      onNameChangedForAutAdd?.call();
    }
  }

  void dispose() {
    quantityController.dispose();
    unitController.dispose();
    nameFocusNode.dispose();
    quantityFocusNode.dispose();
    unitFocusNode.dispose();
  }
}
