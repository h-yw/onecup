import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onecup/widgets/calculator_common_widgets.dart';

class SyrupCalculatorScreen extends StatefulWidget {
  const SyrupCalculatorScreen({super.key});

  @override
  State<SyrupCalculatorScreen> createState() => _SyrupCalculatorScreenState();
}

class _SyrupCalculatorScreenState extends State<SyrupCalculatorScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _volumeController = TextEditingController();

  SyrupRatio _selectedRatio = SyrupRatio.oneToOne;
  double? _sugarInGrams;
  double? _waterInMl;

  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _volumeController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;
    
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    final double finalVolume = double.tryParse(_volumeController.text) ?? 0;
    if (finalVolume <= 0) return;

    final double density = _selectedRatio.density;
    final double totalWeight = finalVolume * density;
    double sugarWeight;
    double waterWeight;

    if (_selectedRatio == SyrupRatio.oneToOne) {
      sugarWeight = totalWeight / 2;
      waterWeight = totalWeight / 2;
    } else {
      sugarWeight = (totalWeight * 2) / 3;
      waterWeight = totalWeight / 3;
    }

    setState(() {
      _sugarInGrams = sugarWeight;
      _waterInMl = waterWeight;
      _animationController.forward(from: 0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("糖浆计算器", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  CalculatorCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '参数',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        CalculatorSegmentedButton<SyrupRatio>(
                          selected: {_selectedRatio},
                          onSelectionChanged: (newSelection) => setState(() => _selectedRatio = newSelection.first),
                          segments: const [
                            ButtonSegment<SyrupRatio>(value: SyrupRatio.oneToOne, label: Text('1:1 糖浆'), icon: Icon(Icons.balance)),
                            ButtonSegment<SyrupRatio>(value: SyrupRatio.twoToOne, label: Text('2:1 糖浆'), icon: Icon(Icons.scale)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        CalculatorTextField(
                          controller: _volumeController,
                          labelText: '期望得到的最终体积 (ml)',
                          icon: Icons.local_drink_outlined,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                          validator: (value) {
                            if (value == null || value.isEmpty) return '请输入体积';
                            if (double.tryParse(value) == null || double.parse(value) <= 0) return '请输入有效的正数';
                            return null;
                          },
                          onSaved: (value) {},
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CalculatorExecuteButton(
                      onPressed: _calculate,
                      label: '生成配方',
                      icon: Icons.calculate_outlined,
                    ),
                    if (_sugarInGrams != null && _waterInMl != null) ...[
                      const SizedBox(height: 16),
                      CalculatorResultDisplay(
                        animation: _animation,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Text(
                                '您需要准备',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Divider(height: 1, color: Theme.of(context).dividerTheme.color?.withOpacity(0.24) ?? Colors.white24),
                            Column(
                              children: [
                                Expanded(
                                  child: CalculatorResultMetricRow(
                                    icon: Icons.star,
                                    label: '白砂糖',
                                    value: _sugarInGrams!.toStringAsFixed(1),
                                    unit: '克',
                                  ),
                                ),
                                VerticalDivider(width: 1, thickness: 1, indent: 16, endIndent: 16, color: Theme.of(context).dividerTheme.color?.withOpacity(0.12) ?? Colors.white12),
                                Expanded(
                                  child: CalculatorResultMetricRow(
                                    icon: Icons.water_drop_outlined,
                                    label: '水',
                                    value: _waterInMl!.toStringAsFixed(1),
                                    unit: '毫升',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
}

enum SyrupRatio {
  oneToOne(density: 1.24),
  twoToOne(density: 1.32);

  const SyrupRatio({required this.density});
  final double density;
}