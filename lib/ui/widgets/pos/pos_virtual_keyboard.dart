import 'package:flutter/material.dart';

class POSVirtualKeyboard extends StatelessWidget {
  final Function(String) onKeyTap;
  final VoidCallback onHideKeyboard;
  final bool isCaps;

  const POSVirtualKeyboard({
    super.key,
    required this.onKeyTap,
    required this.onHideKeyboard,
    required this.isCaps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Toolbar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: onHideKeyboard,
                      icon: const Icon(Icons.keyboard_hide_rounded, size: 18, color: Colors.grey),
                      label: const Text('Yashirish', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: () => onKeyTap('clear'),
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.redAccent),
                      label: const Text('Tozalash', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              // Row 1: Numbers
              _buildKeyRow(
                context,
                ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0', 'back'],
                rowFlex: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.5],
              ),
              const SizedBox(height: 4),
              // Row 2: QWERTY
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildKeyRow(context, ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p']),
              ),
              const SizedBox(height: 4),
              // Row 3: ASDF
              _buildKeyRow(
                context,
                ['caps', 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'enter'],
                rowFlex: [1.2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.5],
              ),
              const SizedBox(height: 4),
              // Row 4: ZXCV
              _buildKeyRow(
                context,
                ['z', 'x', 'c', 'v', 'b', 'n', 'm', '.', ',', 'space'],
                rowFlex: [1, 1, 1, 1, 1, 1, 1, 1, 1, 3.5],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyRow(BuildContext context, List<String> keys, {List<double>? rowFlex}) {
    return Row(
      children: keys.asMap().entries.map((entry) {
        final idx = entry.key;
        final k = entry.value;
        final flexValue = rowFlex != null ? (rowFlex[idx] * 100).toInt() : 100;
        return Expanded(flex: flexValue, child: _buildVirtualKey(context, k));
      }).toList(),
    );
  }

  Widget _buildVirtualKey(BuildContext context, String k) {
    final isBack = k == 'back';
    final isEnter = k == 'enter';
    final isSpace = k == 'space';
    final isCapsKey = k == 'caps';

    final Color bgColor;
    final Color textColor;
    Widget labelWidget;

    if (isEnter) {
      bgColor = Theme.of(context).colorScheme.primary;
      textColor = Colors.white;
      labelWidget = const Icon(Icons.keyboard_return_rounded, color: Colors.white, size: 20);
    } else if (isBack) {
      bgColor = Theme.of(context).dividerColor;
      textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
      labelWidget = Icon(Icons.backspace_outlined, size: 18, color: textColor);
    } else if (isCapsKey) {
      bgColor = isCaps ? Theme.of(context).colorScheme.primary.withOpacity(0.8) : Theme.of(context).dividerColor;
      textColor = isCaps ? Colors.white : (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87);
      labelWidget = Text('ABC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor));
    } else if (isSpace) {
      bgColor = Theme.of(context).dividerColor;
      textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
      labelWidget = Icon(Icons.space_bar_rounded, size: 18, color: textColor);
    } else {
      bgColor = Theme.of(context).dividerColor;
      textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
      labelWidget = Text(isCaps ? k.toUpperCase() : k, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor));
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      height: 40,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: () => onKeyTap(k),
          borderRadius: BorderRadius.circular(6),
          child: Center(child: labelWidget),
        ),
      ),
    );
  }
}
