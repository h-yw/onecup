
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onecup/widgets/calculator_common_widgets.dart';

// Main Screen Widget
class AbvCalculatorScreen extends StatefulWidget {
  const AbvCalculatorScreen({super.key});

  @override
  State<AbvCalculatorScreen> createState() => _AbvCalculatorScreenState();
}

class _AbvCalculatorScreenState extends State<AbvCalculatorScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final List<LiquidInput> _liquidInputs = [LiquidInput(), LiquidInput()];
  double? _finalAbv;

  late AnimationController _resultAnimationController;
  late Animation<double> _resultAnimation;

  @override
  void initState() {
    super.initState();
    _resultAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _resultAnimation = CurvedAnimation(
      parent: _resultAnimationController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _resultAnimationController.dispose();
    for (var input in _liquidInputs) {
      input.dispose();
    }
    super.dispose();
  }

  void _addLiquidInput() {
    setState(() {
      _liquidInputs.add(LiquidInput());
    });
  }

  void _removeLiquidInput(int index) {
    _liquidInputs[index].dispose();
    setState(() {
      _liquidInputs.removeAt(index);
    });
  }

  void _calculateAbv() {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    _formKey.currentState!.save();

    double totalAlcoholVolume = 0;
    double totalVolume = 0;
    for (var input in _liquidInputs) {
      totalAlcoholVolume += input.volume! * (input.abv! / 100);
      totalVolume += input.volume!;
    }

    setState(() {
      _finalAbv = (totalVolume > 0) ? (totalAlcoholVolume / totalVolume) * 100 : 0;
      if (_finalAbv != null) {
        _resultAnimationController.forward(from: 0.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('ABV 计算器', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
                    (context, index) => _EnergyUnitCard(
                      index: index,
                      liquidInput: _liquidInputs[index],
                      onRemove: () => _removeLiquidInput(index),
                      isRemovable: _liquidInputs.length > 1,
                    ),
                    childCount: _liquidInputs.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: CalculatorAddButton(onPressed: _addLiquidInput),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CalculatorExecuteButton(
                        onPressed: _calculateAbv,
                        label: '执行计算',
                        icon: Icons.play_arrow_rounded,
                      ),
                      if (_finalAbv != null) ...[
                        const SizedBox(height: 8),
                        CalculatorResultDisplay(
                          animation: _resultAnimation,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  '最终酒精度 (ABV)',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w600, // Slightly less bold
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_finalAbv!.toStringAsFixed(2)}%',
                                style: TextStyle(
                                  color: theme.colorScheme.primary, // Use primary color
                                  fontSize: theme.textTheme.displayLarge?.fontSize ?? 48, // Larger font size
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: theme.textTheme.displayLarge?.letterSpacing ?? 1.5, // Add letter spacing
                                  shadows: [
                                    Shadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 4)),
                                    Shadow(color: theme.colorScheme.primary.withOpacity(0.2), blurRadius: 20, offset: Offset(0, 8)),
                                  ],
                                ),
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

class _EnergyUnitCard extends StatelessWidget {
  final int index;
  final LiquidInput liquidInput;
  final VoidCallback onRemove;
  final bool isRemovable;

  const _EnergyUnitCard({
    required this.index,
    required this.liquidInput,
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
                '成分 #${index + 1}',
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
            controller: liquidInput.volumeController,
            labelText: '液体体积 (ml)',
            icon: Icons.local_drink_outlined,
            keyboardType: TextInputType.number,
            validator: (value) => (value == null || value.isEmpty) ? '请输入体积' : null,
            onSaved: (value) => liquidInput.volume = double.tryParse(value!),
          ),
          const SizedBox(height: 12),
          CalculatorTextField(
            controller: liquidInput.abvController,
            labelText: 'ABV (%)',
            icon: Icons.show_chart_outlined,
            keyboardType: TextInputType.number,
            validator: (value) => (value == null || value.isEmpty) ? '请输入ABV' : null,
            onSaved: (value) => liquidInput.abv = double.tryParse(value!),
          ),
        ],
      ),
    );
  }
}

// Data class for inputs
class LiquidInput {
  final TextEditingController volumeController = TextEditingController();
  final TextEditingController abvController = TextEditingController();
  double? volume;
  double? abv;

  void dispose() {
    volumeController.dispose();
    abvController.dispose();
  }
}
