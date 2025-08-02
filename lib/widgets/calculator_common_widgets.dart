import 'dart:ui';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 通用计算器卡片
class CalculatorCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const CalculatorCard({
    super.key,
    required this.child,
    this.borderColor,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16), // Increased bottom margin
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius), // Use the passed borderRadius
        color: backgroundColor ?? theme.colorScheme.surface, // Use surface color for background
        border: Border.all(color: borderColor ?? theme.colorScheme.outlineVariant.withOpacity(0.4), width: 1), // Softer border
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.08), // Lighter shadow
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius), // Use the passed borderRadius
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

// 通用计算器文本输入框
class CalculatorTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData icon;
  final FormFieldValidator<String> validator;
  final FormFieldSetter<String> onSaved;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const CalculatorTextField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.icon,
    required this.validator,
    required this.onSaved,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onSaved: onSaved,
      style: TextStyle(color: theme.colorScheme.onSurface, fontSize: theme.textTheme.bodyLarge?.fontSize ?? 16), // Larger font size
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: theme.textTheme.labelLarge?.fontSize ?? 16), // Larger label font size
        prefixIcon: Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: theme.iconTheme.size ?? 20), // Larger icon size
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), // Slightly more rounded corners
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.6), width: 1), // Softer border
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2), // Thicker primary border on focus
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.colorScheme.error, width: 1), // Consistent error border
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.colorScheme.error, width: 2), // Thicker error border on focus
        ),
        contentPadding: theme.inputDecorationTheme.contentPadding ?? const EdgeInsets.symmetric(vertical: 14, horizontal: 16), // Increased padding
      ),
    );
  }
}

// 通用添加按钮
class CalculatorAddButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const CalculatorAddButton({
    super.key,
    required this.onPressed,
    this.label = '+ 添加模块',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16), // More rounded corners
      child: Container(
        height: 56, // Taller button
        decoration: BoxDecoration(
          borderRadius:  BorderRadius.circular(16), // More rounded corners
          color: theme.colorScheme.primary.withOpacity(0.12), // Slightly more opaque
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, color: theme.colorScheme.primary, size: theme.iconTheme.size ?? 24), // Larger icon
              const SizedBox(width: 8),
              Text(label, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)), // Larger text
            ],
          ),
        ),
      ),
    );
  }
}

// 通用执行/计算按钮
class CalculatorExecuteButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  const CalculatorExecuteButton({
    super.key,
    required this.onPressed,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius:   BorderRadius.circular(30), // More rounded
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.primaryContainer], // Keep gradient
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.4), blurRadius: 12, spreadRadius: 2)], // Stronger shadow
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: theme.colorScheme.onPrimary, size: theme.iconTheme.size ?? 28), // Larger icon
        label: Text(label, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold)), // Larger text
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16), // Increased padding
          shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), // Match container border radius
        ),
      ),
    );
  }
}

// 通用结果显示容器
class CalculatorResultDisplay extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final double borderRadius;

  const CalculatorResultDisplay({
    super.key,
    required this.animation,
    required this.child,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ScaleTransition(
      scale: animation,
      child: Container(
        width: double.infinity,
        padding:  const EdgeInsets.all(20), // Increased padding
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16), // Use the passed borderRadius
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surfaceVariant.withOpacity(0.6),
              theme.colorScheme.surfaceVariant.withOpacity(0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ), // Subtle gradient
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5), width: 1), // Softer border
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.15),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius:  BorderRadius.circular(borderRadius - 1),
          child: Container(
            color: theme.colorScheme.surface.withOpacity(0.0), // Make inner container transparent
            child: child,
          ),
        ),
      ),
    );
  }
}

// 通用页面/部分标题
class CalculatorSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Color? subtitleColor;

  const CalculatorSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0), // Increased bottom padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith( // Larger title
              color: titleColor ?? theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0), // Add some top padding for subtitle
              child: Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith( // Slightly larger subtitle
                  color: subtitleColor ?? theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 通用滑块
class CalculatorSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const CalculatorSlider({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 4.0), // Adjust padding
          child: Text(label, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: theme.textTheme.bodyLarge?.fontSize ?? 16)), // Larger font
        ),
        Row(
          children: [
            Icon(icon, color: theme.colorScheme.secondary, size: theme.iconTheme.size ?? 24), // Larger icon
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                label: displayValue, // Use displayValue for label
                onChanged: onChanged,
                activeColor: theme.colorScheme.secondary, // Keep active color
                inactiveColor: theme.colorScheme.secondary.withOpacity(0.2), // Lighter inactive color
                thumbColor: theme.colorScheme.secondary, // Thumb color
              ),
            ),
            SizedBox(width: 8), // Add some space
            Text(displayValue, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)), // Bold value
          ],
        ),
      ],
    );
  }
}

// 通用分段按钮
class CalculatorSegmentedButton<T> extends StatelessWidget {
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;
  final List<ButtonSegment<T>> segments;

  const CalculatorSegmentedButton({
    super.key,
    required this.selected,
    required this.onSelectionChanged,
    required this.segments,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SegmentedButton<T>(
        segments: segments,
        selected: selected,
        onSelectionChanged: onSelectionChanged,
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: theme.colorScheme.primary.withOpacity(0.15), // Slightly more opaque
          selectedForegroundColor: theme.colorScheme.primary, // Keep primary color
          side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.6), width: 1), // Softer border
          textStyle: theme.textTheme.bodyMedium, // Larger text
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Increased padding
          shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // More rounded corners
        ),
      ),
    );
  }
}

// 通用结果指标行
class CalculatorResultMetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isSubtle;
  final String? unit;

  const CalculatorResultMetricRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.isSubtle = false,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0), // Slightly reduced vertical padding
      child: Row(
        children: [
          Icon(icon, color: isSubtle ? theme.colorScheme.onSurface.withOpacity(0.6) : theme.colorScheme.secondary, size: theme.iconTheme.size ?? 22), // Larger icon
          const SizedBox(width: 16), // Increased spacing
          Expanded(child: Text(label, style: TextStyle(fontSize: isSubtle ? theme.textTheme.bodyMedium?.fontSize ?? 15 : theme.textTheme.bodyLarge?.fontSize ?? 17, color: theme.colorScheme.onSurface))), // Larger font
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: isSubtle ? theme.textTheme.bodyMedium?.fontSize ?? 15 : theme.textTheme.bodyLarge?.fontSize ?? 17, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface), // Larger font
              children: [
                TextSpan(text: value),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), // Consistent with bodyMedium
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
