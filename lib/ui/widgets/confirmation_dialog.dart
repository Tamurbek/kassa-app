import 'package:flutter/material.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final Color confirmColor;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Ha',
    this.cancelLabel = 'Yo\'q',
    required this.onConfirm,
    this.confirmColor = Colors.redAccent,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            onConfirm();
            Navigator.pop(context);
          },
          child: Text(confirmLabel),
        ),
      ],
    );
  }

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Ha',
    String cancelLabel = 'Yo\'q',
    required VoidCallback onConfirm,
    Color confirmColor = Colors.redAccent,
  }) {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        onConfirm: onConfirm,
        confirmColor: confirmColor,
      ),
    );
  }
}
