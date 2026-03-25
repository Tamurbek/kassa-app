import 'package:flutter/material.dart';

enum AppButtonStyle { primary, secondary, danger, outline }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final AppButtonStyle style;
  final double? width;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.style = AppButtonStyle.primary,
    this.width,
    this.height = 55.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Color getBgColor() {
      switch (style) {
        case AppButtonStyle.primary: return theme.colorScheme.primary;
        case AppButtonStyle.secondary: return theme.colorScheme.secondary;
        case AppButtonStyle.danger: return Colors.red;
        case AppButtonStyle.outline: return Colors.transparent;
      }
    }

    Color getFgColor() {
      switch (style) {
        case AppButtonStyle.primary: return Colors.white;
        case AppButtonStyle.secondary: return Colors.white;
        case AppButtonStyle.danger: return Colors.white;
        case AppButtonStyle.outline: return theme.colorScheme.primary;
      }
    }

    return SizedBox(
      width: width,
      height: height,
      child: style == AppButtonStyle.outline
          ? OutlinedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: isLoading ? const SizedBox.shrink() : (icon != null ? Icon(icon, size: 20) : const SizedBox.shrink()),
              label: isLoading ? const CircularProgressIndicator(strokeWidth: 2) : Text(label.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.primary),
                foregroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            )
          : ElevatedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: isLoading ? const SizedBox.shrink() : (icon != null ? Icon(icon, size: 20) : const SizedBox.shrink()),
              label: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : Text(label.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: getBgColor(),
                foregroundColor: getFgColor(),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
    );
  }
}
