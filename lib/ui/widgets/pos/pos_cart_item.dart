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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: -0.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.price.toStringAsFixed(0)} s',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                (item.price * item.quantity).toStringAsFixed(0),
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QtyButton(
                    icon: Icons.remove,
                    onTap: () => sales.updateCartQuantity(item.productId, item.quantity - 1),
                    color: Colors.red.withOpacity(0.08),
                    iconColor: Colors.red,
                  ),
                  InkWell(
                    onTap: () => onShowQuantityDialog(item),
                    child: Container(
                      width: 48,
                      alignment: Alignment.center,
                      child: Text(
                        item.quantity % 1 == 0
                            ? item.quantity.toInt().toString()
                            : item.quantity.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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
                    color: Colors.green.withOpacity(0.08),
                    iconColor: Colors.green,
                  ),
                ],
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
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color ?? Theme.of(context).dividerColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 24, color: iconColor ?? Theme.of(context).colorScheme.onSurface),
        ),
      ),
    );
  }
}
