import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/models.dart';
import '../../../providers/features/inventory_provider.dart';
import '../../../providers/features/sales_provider.dart';
import '../../../providers/features/settings_provider.dart';

class POSCartItem extends StatelessWidget {
  final SaleItem item;
  final Function(SaleItem) onShowQuantityDialog;

  const POSCartItem({
    super.key,
    required this.item,
    required this.onShowQuantityDialog,
  });

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final sales = context.watch<SalesProvider>();
    final settings = context.watch<SettingsProvider>();

    final product = inventory.products
        .where((p) => p.id == item.productId)
        .firstOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          // Index or small icon could go here, but omitted for space
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.price.toStringAsFixed(0)} x ${item.quantity}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Total price for this item
          Text(
            (item.price * item.quantity).toStringAsFixed(0),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
          const SizedBox(width: 8),
          // Simple Qty Controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QtyButton(
                icon: Icons.remove,
                onTap: () => sales.updateCartQuantity(item.productId, item.quantity - 1),
                color: Colors.red.withOpacity(0.05),
                iconColor: Colors.redAccent,
              ),
              InkWell(
                onTap: () => onShowQuantityDialog(item),
                child: Container(
                  width: 32,
                  alignment: Alignment.center,
                  child: Text(
                    item.quantity % 1 == 0
                        ? item.quantity.toInt().toString()
                        : item.quantity.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              _QtyButton(
                icon: Icons.add,
                onTap: () {
                  if (product != null) {
                    try {
                      sales.addToCart(product, warehouseId: settings.currentRegister?.warehouseId);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                color: Colors.green.withOpacity(0.05),
                iconColor: Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final Color? iconColor;

  const _QtyButton({required this.icon, required this.onTap, this.color, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color ?? Theme.of(context).dividerColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: iconColor ?? Theme.of(context).colorScheme.onSurface),
        ),
      ),
    );
  }
}
