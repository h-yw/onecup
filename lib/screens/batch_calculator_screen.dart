import 'dart:ffi';

import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:onecup/models/batch_ingredient.dart';
import 'package:onecup/models/receip.dart';

class BatchCalculatorScreen extends StatefulWidget {
  final Recipe? recipe;

  const BatchCalculatorScreen({super.key, this.recipe});

  @override
  State<BatchCalculatorScreen> createState() => _BatchCalculatorScreenState();
}

class _BatchCalculatorScreenState extends State<BatchCalculatorScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  List<BatchIngredient> _ingredients = [];
  double _servings = 10;
  double _dilutionPercentage = 20.0;
  Map<String, dynamic>? _batchResult;

  late AnimationController _controller;
  late Animation<double> _animation;

  // 智能用量解析函数
  /// 将配方中的各种用量描述（数字、"少量"、"dash"等）统一解析为毫升(ml)
  double _parseVolume(String? amountStr, String? unit) {
    if (amountStr == null || amountStr.isEmpty) return 0.0;

    final unitLower = unit?.toLowerCase() ?? '';
    double amount = double.tryParse(amountStr.replaceAll(',', '.')) ?? 0;

    // 优先处理描述性词语
    if (amountStr.contains('少量') || amountStr.contains('少许')) {
      return 5.0; // 假设“少量/少许”约等于 5ml
    }
    if (amountStr.contains('滴')) {
      return 0.8; // 假设“1滴”约等于 0.8ml (1 dash)
    }

    // 处理单位转换
    if (unitLower == 'oz' || unitLower == '盎司') {
      amount *= 30; // 1 oz ≈ 30 ml
    } else if (unitLower.contains('dash')) {
      amount *= 0.8; // 1 dash ≈ 0.8 ml
    } else if (unitLower.contains('tsp') || unitLower.contains('茶匙')) {
      amount *= 5; // 1 tsp ≈ 5 ml
    } else if (unitLower.contains('bar spoon') || unitLower.contains('吧勺')) {
      amount *= 5; // 1 bar spoon ≈ 5 ml
    }
    // 'ml' 单位不需要转换，直接返回 amount
    return amount;
  }

  @override
  void initState() {
    super.initState();
    if ( widget.recipe?.ingredients != null && widget.recipe!.ingredients!.isNotEmpty) {
      _ingredients = widget.recipe!.ingredients!.map((ingredient) {
        // [核心修改] 使用新的解析函数来处理用量
        final double volume = _parseVolume(
          ingredient['amount']?.toString(),
          ingredient['unit']?.toString(),
        );
        // 安全地将酒精度（abv）从 num? 转换为 double，并提供默认值
        final double abv = (ingredient['abv'] as num?)?.toDouble() ?? 0.0;

        return BatchIngredient(
          name: ingredient['name'] ?? '未知配料', // 使用 'name' 别名
          volume: volume,
          abv: abv,
        );
      }).toList();
    } else {
      _ingredients = [BatchIngredient(), BatchIngredient()];
    }
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(BatchIngredient());
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      if (_ingredients.length > 1) {
        _ingredients.removeAt(index);
      }
    });
  }

  void _calculateBatch() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      double totalVolumePerServing = 0;
      double totalAlcoholVolumePerServing = 0;
      Map<String, double> ingredientTotals = {};

      for (var ingredient in _ingredients) {
        totalVolumePerServing += ingredient.volume;
        totalAlcoholVolumePerServing +=
            ingredient.volume * (ingredient.abv / 100);
        ingredientTotals[ingredient.name] =
            (ingredientTotals[ingredient.name] ?? 0) + ingredient.volume;
      }

      final double waterForDilution =
          totalVolumePerServing * (_dilutionPercentage / 100);
      final double totalVolumeWithDilutionPerServing =
          totalVolumePerServing + waterForDilution;

      final double finalAbv = totalVolumeWithDilutionPerServing > 0
          ? (totalAlcoholVolumePerServing / totalVolumeWithDilutionPerServing) *
                100
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
      });
      _controller.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '批量计算器',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Text(
                  'Step 1: 输入单杯配方',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildIngredientInputCard(index, theme),
                childCount: _ingredients.length,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: OutlinedButton.icon(
                  onPressed: _addIngredient,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('添加成分'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: theme.colorScheme.primary),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
                child: Text(
                  'Step 2: 设置参数',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildServingsCard(theme)),
            SliverToBoxAdapter(child: _buildDilutionCard(theme)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: _calculateBatch,
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('生成批量配方'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: theme.textTheme.labelLarge,
                  ),
                ),
              ),
            ),
            if (_batchResult != null)
              SliverToBoxAdapter(child: _buildResultPanel(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientInputCard(int index, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('成分 ${index + 1}', style: theme.textTheme.titleLarge),
                if (_ingredients.length > 1)
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _removeIngredient(index),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _ingredients[index].name,
              decoration: const InputDecoration(labelText: '成分名称 (例如: 金酒)'),
              validator: (value) =>
                  (value == null || value.isEmpty) ? '请输入名称' : null,
              onSaved: (value) => _ingredients[index].name = value!,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
            initialValue: _ingredients[index].volume == 0.0
            ? ''
                    : _ingredients[index].volume.toString(),
                    decoration: const InputDecoration(labelText: '体积 (ml)'),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        (value == null || value.isEmpty) ? '请输入体积' : null,
                    onSaved: (value) =>
                        _ingredients[index].volume = double.parse(value!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _ingredients[index].abv == 0.0
                        ? '0'
                        : _ingredients[index].abv.toString(),
                    decoration: const InputDecoration(labelText: 'ABV (%)'),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        (value == null || value.isEmpty) ? '请输入ABV' : null,
                    onSaved: (value) =>
                        _ingredients[index].abv = double.parse(value!),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServingsCard(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('份数', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people_alt_outlined),
                Expanded(
                  child: Slider(
                    value: _servings,
                    min: 1,
                    max: 100,
                    divisions: 99,
                    label: _servings.round().toString(),
                    onChanged: (double value) {
                      setState(() {
                        _servings = value;
                      });
                    },
                  ),
                ),
                Text(
                  '${_servings.round()} 份',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDilutionCard(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('加水稀释比例', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.opacity_outlined),
                Expanded(
                  child: Slider(
                    value: _dilutionPercentage,
                    min: 0,
                    max: 50,
                    divisions: 50,
                    label: '${_dilutionPercentage.round()}%',
                    onChanged: (double value) {
                      setState(() {
                        _dilutionPercentage = value;
                      });
                    },
                  ),
                ),
                Text(
                  '${_dilutionPercentage.round()}%',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultPanel(ThemeData theme) {
    final results = _batchResult!;
    final Map<String, double> batchIngredients = results['ingredients'];

    return FadeTransition(
      opacity: _animation,
      child: ScaleTransition(
        scale: _animation,
        child: Card(
          margin: const EdgeInsets.all(16.0),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: theme.colorScheme.primary.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('批量配方生成完毕!', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 16),
                ...batchIngredients.entries.map(
                  (entry) => ListTile(
                    leading: const Icon(Icons.local_bar, color: Colors.brown),
                    title: Text(entry.key),
                    trailing: Text(
                      '${entry.value.toStringAsFixed(1)} ml',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(
                    Icons.water_drop,
                    color: Colors.blueAccent,
                  ),
                  title: const Text('需额外加水'),
                  trailing: Text(
                    '${results['totalWater'].toStringAsFixed(1)} ml',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(
                    Icons.science_outlined,
                    color: Colors.purple,
                  ),
                  title: const Text('最终成品体积'),
                  trailing: Text(
                    '${results['finalVolume'].toStringAsFixed(1)} ml',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.thermostat_outlined,
                    color: Colors.orange,
                  ),
                  title: const Text('最终成品ABV'),
                  trailing: Text(
                    '${results['finalAbv'].toStringAsFixed(2)} %',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '专业建议: 对于柑橘类果汁，可考虑减少15-20%用量，以获得更平衡的口感。',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
