
import 'package:flutter/material.dart';

class AbvCalculatorScreen extends StatefulWidget {
  const AbvCalculatorScreen({super.key});

  @override
  State<AbvCalculatorScreen> createState() => _AbvCalculatorScreenState();
}

class _AbvCalculatorScreenState extends State<AbvCalculatorScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final List<LiquidInput> _liquidInputs = [LiquidInput(), LiquidInput()];
  double? _finalAbv;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _addLiquidInput() {
    setState(() {
      _liquidInputs.add(LiquidInput());
    });
  }

  void _removeLiquidInput(int index) {
    setState(() {
      _liquidInputs.removeAt(index);
    });
  }

  void _calculateAbv() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      double totalAlcoholVolume = 0;
      double totalVolume = 0;
      for (var input in _liquidInputs) {
        if (input.volume != null && input.abv != null) {
          totalAlcoholVolume += input.volume! * (input.abv! / 100);
          totalVolume += input.volume!;
        }
      }
      setState(() {
        if (totalVolume > 0) {
          _finalAbv = (totalAlcoholVolume / totalVolume) * 100;
          _animationController.forward(from: 0.0);
        } else {
          _finalAbv = 0;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ABV 计算器'),
      ),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _buildLiquidInputCard(index, theme);
                  },
                  childCount: _liquidInputs.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAddButton(theme),
                    const SizedBox(height: 24),
                    _buildCalculateButton(theme),
                    if (_finalAbv != null) ...[
                      const SizedBox(height: 24),
                      _buildResultCard(theme),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiquidInputCard(int index, ThemeData theme) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('成分 ${index + 1}',style: theme.textTheme.headlineSmall,),
              trailing: _liquidInputs.length > 1
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _removeLiquidInput(index),
                    )
                  : null,
            ),
            TextFormField(
              decoration: const InputDecoration(
                labelText: '液体体积 (ml)',
                prefixIcon: Icon(Icons.local_drink_outlined),
              ),
              keyboardType: TextInputType.number,
              validator: (value) => (value == null || value.isEmpty) ? '请输入体积' : null,
              onSaved: (value) => _liquidInputs[index].volume = double.tryParse(value!),
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'ABV (%)',
                prefixIcon: Icon(Icons.show_chart_outlined),
              ),
              keyboardType: TextInputType.number,
              validator: (value) => (value == null || value.isEmpty) ? '请输入ABV' : null,
              onSaved: (value) => _liquidInputs[index].abv = double.tryParse(value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(ThemeData theme) {
    return OutlinedButton.icon(
      onPressed: _addLiquidInput,
      icon: const Icon(Icons.add_circle_outline),
      label: const Text('添加成分'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: theme.colorScheme.primary),
      ),
    );
  }

  Widget _buildCalculateButton(ThemeData theme) {
    return ElevatedButton.icon(
      onPressed: _calculateAbv,
      icon: const Icon(Icons.calculate_outlined),
      label: const Text('计算最终ABV'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: theme.textTheme.labelLarge,
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme) {
    return FadeTransition(
      opacity: _animation,
      child: ScaleTransition(
        scale: _animation,
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: theme.colorScheme.primary.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text('最终 ABV', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 16),
                Text(
                  '${_finalAbv!.toStringAsFixed(2)}%',
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
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

class LiquidInput {
  double? volume;
  double? abv;
}
