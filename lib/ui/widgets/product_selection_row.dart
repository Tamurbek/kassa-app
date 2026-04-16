import 'package:flutter/material.dart';
import '../../models/models.dart';

class ProductSelectionRow extends StatelessWidget {
  final Product? selectedProduct;
  final List<Product> availableProducts;
  final double quantity;
  final ValueChanged<String?> onProductChanged;
  final ValueChanged<String> onQuantityChanged;
  final VoidCallback onRemove;
  final String? quantityHint;
  final String? priceText;
  final List<Widget>? extraInfo;

  const ProductSelectionRow({
    super.key,
    required this.selectedProduct,
    required this.availableProducts,
    required this.quantity,
    required this.onProductChanged,
    required this.onQuantityChanged,
    required this.onRemove,
    this.quantityHint = 'Soni',
    this.priceText,
    this.extraInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 6,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: selectedProduct?.id,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              itemHeight: 60,
              items: availableProducts
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        p.name,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onProductChanged,
            ),
          ),
          const SizedBox(width: 8),
          if (extraInfo != null) ...[
            ...extraInfo!,
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 1,
            child: TextFormField(
              initialValue: quantity == 0 ? '' : quantity.toString(),
              decoration: InputDecoration(
                hintText: quantityHint,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              keyboardType: TextInputType.number,
              onChanged: onQuantityChanged,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
