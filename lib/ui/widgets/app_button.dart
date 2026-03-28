import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppButtonStyle { primary, secondary, danger, outline, ghost }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final AppButtonStyle style;
  final double? width;
  final double height;
  final bool disabled;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.style = AppButtonStyle.primary,
    this.width,
    this.height = 56.0,
    this.disabled = false,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final bool isEnabled = widget.onPressed != null && !widget.isLoading && !widget.disabled;

    Color getBgColor() {
      if (!isEnabled) return isDark ? Colors.white10 : Colors.black12;
      switch (widget.style) {
        case AppButtonStyle.primary: return AppTheme.primaryColor;
        case AppButtonStyle.secondary: return AppTheme.secondaryColor;
        case AppButtonStyle.danger: return Colors.redAccent;
        case AppButtonStyle.outline: return Colors.transparent;
        case AppButtonStyle.ghost: return Colors.transparent;
      }
    }

    Color getFgColor() {
      if (!isEnabled) return isDark ? Colors.white24 : Colors.black26;
      switch (widget.style) {
        case AppButtonStyle.primary:
        case AppButtonStyle.secondary:
        case AppButtonStyle.danger: return Colors.white;
        case AppButtonStyle.outline: return AppTheme.primaryColor;
        case AppButtonStyle.ghost: return isDark ? Colors.white70 : Colors.black54;
      }
    }

    return GestureDetector(
      onTapDown: isEnabled ? (_) => _controller.forward() : null,
      onTapUp: isEnabled ? (_) => _controller.reverse() : null,
      onTapCancel: isEnabled ? () => _controller.reverse() : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: getBgColor(),
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: widget.style == AppButtonStyle.outline 
                  ? Border.all(color: isEnabled ? AppTheme.primaryColor : Colors.transparent)
                  : null,
              boxShadow: (widget.style == AppButtonStyle.primary && isEnabled)
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isEnabled ? widget.onPressed : null,
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                child: Center(
                  child: widget.isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(getFgColor()),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(widget.icon, size: 20, color: getFgColor()),
                              const SizedBox(width: 10),
                            ],
                            Text(
                              widget.label,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: getFgColor(),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
