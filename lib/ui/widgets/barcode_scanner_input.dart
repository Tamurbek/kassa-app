import 'package:flutter/material.dart';

class BarcodeScannerInput extends StatefulWidget {
  final ValueChanged<String> onBarcodeSubmitted;
  final String label;
  final String hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  const BarcodeScannerInput({
    super.key,
    required this.onBarcodeSubmitted,
    this.label = 'Shtrix kod',
    this.hint = 'Skanerlang...',
    this.controller,
    this.focusNode,
  });

  @override
  State<BarcodeScannerInput> createState() => _BarcodeScannerInputState();
}

class _BarcodeScannerInputState extends State<BarcodeScannerInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit(String value) {
    if (value.isNotEmpty) {
      widget.onBarcodeSubmitted(value);
      _controller.clear();
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.qr_code_scanner),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onSubmitted: _handleSubmit,
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: () => _handleSubmit(_controller.text),
          icon: const Icon(Icons.add),
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
