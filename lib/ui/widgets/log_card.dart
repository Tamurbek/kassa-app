import 'package:flutter/material.dart';

class LogCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailingText;
  final Color accentColor;
  final IconData leadingIcon;
  final List<Widget> children;
  final VoidCallback? onDelete;
  final String? deleteLabel;

  const LogCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailingText,
    this.accentColor = Colors.orange,
    this.leadingIcon = Icons.assignment_return_outlined,
    required this.children,
    this.onDelete,
    this.deleteLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        collapsedShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Colors.transparent,
        leading: CircleAvatar(
          backgroundColor: accentColor.withOpacity(0.1),
          child: Icon(leadingIcon, color: accentColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              trailingText,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.cancel_outlined, color: Colors.grey, size: 20),
                onPressed: onDelete,
              ),
          ],
        ),
        children: children,
      ),
    );
  }
}
