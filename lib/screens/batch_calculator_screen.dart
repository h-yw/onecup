import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onecup/models/batch_ingredient.dart';
import 'package:onecup/models/receip.dart';
import 'package:onecup/widgets/calculator_common_widgets.dart';

// Main Screen Widget
class BatchCalculatorScreen extends StatefulWidget {
  final Recipe? recipe;
  const BatchCalculatorScreen({super.key, this.recipe});

  @override
  State<BatchCalculatorScreen> createState() => _BatchCalculatorScreenState();
}

class _BatchCalculatorScreenState extends State<BatchCalculatorScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  List<BatchIngredient> _ingredients = [];
  double _servings = 10;
  double _dilutionPercentage = 20.0;
  Map<String, dynamic>? _batchResult;

  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _setupInitialIngredients();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _animationController, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (var ingredient in _ingredients) {
      ingredient.dispose();
    }
    super.dispose();
  }

  void _setupInitialIngredients() {
    if (widget.recipe?.ingredients != null && widget.recipe!.ingredients!.isNotEmpty) {
      _ingredients = widget.recipe!.ingredients!.map((ingredient) {
        final double volume = _parseVolume(ingredient['amount']?.toString(), ingredient['unit']?.toString());
        final double abv = (ingredient['abv'] as num?)?.toDouble() ?? 0.0;
        return BatchIngredient(
          name: ingredient['name'] ?? '未知配料',
          volume: volume,
          abv: abv,
        );
      }).toList();
    } else {
      _ingredients = [BatchIngredient(), BatchIngredient()];
    }
  }

  double _parseVolume(String? amountStr, String? unit) {
    if (amountStr == null || amountStr.isEmpty) return 0.0;
    final unitLower = unit?.toLowerCase() ?? '';
    double amount = double.tryParse(amountStr.replaceAll(',', '.')) ?? 0;
    if (amountStr.contains('少量') || amountStr.contains('少许')) return 5.0;
    if (amountStr.contains('滴')) return 0.8;
    if (unitLower == 'oz' || unitLower == '盎司') amount *= 30;
    else if (unitLower.contains('dash')) amount *= 0.8;
    else if (unitLower.contains('tsp') || unitLower.contains('茶匙')) amount *= 5;
    else if (unitLower.contains('bar spoon') || unitLower.contains('吧勺')) amount *= 5;
    return amount;
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(BatchIngredient());
    });
  }

  void _removeIngredient(int index) {
    _ingredients[index].dispose();
    setState(() {
      if (_ingredients.length > 1) {
        _ingredients.removeAt(index);
      }
    });
  }

  void _calculateBatch() {
    if (!_formKey.currentState!.validate()) return;
    
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    _formKey.currentState!.save();

    double totalVolumePerServing = 0;
    double totalAlcoholVolumePerServing = 0;
    Map<String, double> ingredientTotals = {};

    for (var ingredient in _ingredients) {
      totalVolumePerServing += ingredient.volume;
      totalAlcoholVolumePerServing += ingredient.volume * (ingredient.abv / 100);
      ingredientTotals[ingredient.name] = (ingredientTotals[ingredient.name] ?? 0) + ingredient.volume;
    }

    final double waterForDilution = totalVolumePerServing * (_dilutionPercentage / 100);
    final double totalVolumeWithDilutionPerServing = totalVolumePerServing + waterForDilution;
    final double finalAbv = totalVolumeWithDilutionPerServing > 0
        ? (totalAlcoholVolumePerServing / totalVolumeWithDilutionPerServing) * 100
        : 0;

    final Map<String, double> batchIngredients = {};
    ingredientTotals.forEach((name, volume) {
      batchIngredients[name] = volume * _servings;
    });

    setState(() {
      _batchResult = {
        'ingredients': batchIngredients,
        'totalWater': waterForDilution * _servings,
        'finalVolume': totalVolumeWithDilutionPerServing * _servings,
        'finalAbv': finalAbv,
      };
      _animationController.forward(from: 0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('批量计算器', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      ),
      body: Container(
        color: theme.colorScheme.surface,
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + kToolbarHeight + 16, 16, 16), // Unified padding
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _IngredientInputCard(
                      index: index,
                      ingredient: _ingredients[index],
                      onRemove: () => _removeIngredient(index),
                      isRemovable: _ingredients.length > 1,
                    ),
                    childCount: _ingredients.length,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                sliver: SliverToBoxAdapter(child: CalculatorAddButton(onPressed: _addIngredient)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _ParameterModuleCard(
                    servings: _servings,
                    dilutionPercentage: _dilutionPercentage,
                    onServingsChanged: (value) => setState(() => _servings = value),
                    onDilutionChanged: (value) => setState(() => _dilutionPercentage = value),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    children: [
                      CalculatorExecuteButton(
                        onPressed: _calculateBatch,
                        label: '生成批量配方',
                        icon: Icons.play_arrow_rounded,
                      ),
                      if (_batchResult != null) ...[
                        const SizedBox(height: 8),
                        CalculatorResultDisplay(
                          animation: _animation,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  '批量配方生成完毕!',
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold, // Make it bold
                                  ),
                                ),
                              ),
                              Divider(height: 1, color: Theme.of(context).dividerTheme.color?.withOpacity(0.24) ?? Colors.white24),
                              CalculatorResultMetricRow(
                                icon: Icons.science_outlined,
                                label: '最终成品体积',
                                value: _batchResult!['finalVolume'].toStringAsFixed(1),
                                unit: 'ml',
                              ),
                              Divider(height: 1, indent: 16, endIndent: 16, color: Theme.of(context).dividerTheme.color?.withOpacity(0.12) ?? Colors.white12),
                              CalculatorResultMetricRow(
                                icon: Icons.thermostat_outlined,
                                label: '最终成品 ABV',
                                value: _batchResult!['finalAbv'].toStringAsFixed(2),
                                unit: '%',
                              ),
                              Divider(height: 1, color: Theme.of(context).dividerTheme.color?.withOpacity(0.24) ?? Colors.white24),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  '所需原料总量',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.bold, // Make it bold
                                  ),
                                ),
                              ),
                              ...(_batchResult!['ingredients'] as Map<String, dynamic>).entries.map(
                                (entry) => CalculatorResultMetricRow(
                                  icon: Icons.local_bar,
                                  label: entry.key,
                                  value: entry.value.toStringAsFixed(1),
                                  unit: 'ml',
                                  isSubtle: true,
                                ),
                              ),
                              const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white12),
                              CalculatorResultMetricRow(
                                icon: Icons.water_drop,
                                label: '需额外加水',
                                value: _batchResult!['totalWater'].toStringAsFixed(1),
                                unit: 'ml',
                              ),
                            ],
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IngredientInputCard extends StatelessWidget {
  final int index;
  final BatchIngredient ingredient;
  final VoidCallback onRemove;
  final bool isRemovable;

  const _IngredientInputCard({
    required this.index,
    required this.ingredient,
    required this.onRemove,
    required this.isRemovable,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CalculatorCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '成分单元 #${index + 1}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isRemovable)
                GestureDetector(
                  onTap: onRemove,
                  child: Icon(Icons.close_rounded, color: theme.colorScheme.error, size: theme.iconTheme.size ?? 20),
                ),
            ],
          ),
          const SizedBox(height: 12),
          CalculatorTextField(
            controller: ingredient.nameController,
            labelText: '成分名称',
            icon: Icons.local_bar,
            validator: (value) => (value == null || value.isEmpty) ? '请输入名称' : null,
            onSaved: (value) => ingredient.name = value!,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CalculatorTextField(
                  controller: ingredient.volumeController,
                  labelText: '体积 (ml)',
                  icon: Icons.local_drink_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) => (value == null || value.isEmpty) ? '请输入体积' : null,
                  onSaved: (value) => ingredient.volume = double.parse(value!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CalculatorTextField(
                  controller: ingredient.abvController,
                  labelText: 'ABV (%)',
                  icon: Icons.show_chart_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) => (value == null || value.isEmpty) ? '请输入ABV' : null,
                  onSaved: (value) => ingredient.abv = double.parse(value!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParameterModuleCard extends StatelessWidget {
  final double servings;
  final double dilutionPercentage;
  final ValueChanged<double> onServingsChanged;
  final ValueChanged<double> onDilutionChanged;

  const _ParameterModuleCard({
    required this.servings,
    required this.dilutionPercentage,
    required this.onServingsChanged,
    required this.onDilutionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CalculatorCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '参数设定',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          CalculatorSlider(
            label: '份数',
            icon: Icons.people_alt_outlined,
            value: servings,
            min: 1,
            max: 100,
            divisions: 99,
            displayValue: '${servings.round()} 份',
            onChanged: onServingsChanged,
          ),
          const SizedBox(height: 16),
          CalculatorSlider(
            label: '加水稀释比例',
            icon: Icons.opacity_outlined,
            value: dilutionPercentage,
            min: 0,
            max: 50,
            divisions: 50,
            displayValue: '${dilutionPercentage.round()}%',
            onChanged: onDilutionChanged,
          ),
        ],
      ),
    );
  }
}