import 'package:flutter/material.dart';

class CommonListTile extends StatelessWidget {
  const CommonListTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: color ?? theme.primaryColor),
      title: Text(title, style: theme.textTheme.bodyLarge?.copyWith(color: color ?? theme.textTheme.bodyLarge?.color)),
      trailing: color == null ? Icon(Icons.arrow_forward_ios, size: 16, color: theme.colorScheme.onSurfaceVariant) : null,
      onTap: onTap,
    );
  }
}
