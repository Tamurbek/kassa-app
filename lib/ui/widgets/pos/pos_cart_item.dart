import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/models.dart';
import '../../../providers/features/inventory_provider.dart';
import '../../../providers/features/sales_provider.dart';
import '../../../providers/features/settings_provider.dart';
import 'package:simple_sale/core/utils/responsive.dart';

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

    final bool isShort = Responsive.isShort(context);
    
    return Container(
      margin: EdgeInsets.only(bottom: isShort ? 4.h : 8.h),
      padding: EdgeInsets.symmetric(horizontal: isShort ? 10.sp : 14.sp, vertical: isShort ? 8.h : 12.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Responsive.borderRadius),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 10.sp, offset: Offset(0, 4.h))],
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
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, letterSpacing: -0.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  '${item.price.toStringAsFixed(0)} s',
                  style: TextStyle(
                    fontSize: 11.sp,
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
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp, color: Theme.of(context).colorScheme.primary),
              ),
              SizedBox(height: 6.h),
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
                      width: 40.w,
                      alignment: Alignment.center,
                      child: Text(
                        item.quantity % 1 == 0
                            ? item.quantity.toInt().toString()
                            : item.quantity.toStringAsFixed(1),
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp),
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
        borderRadius: BorderRadius.circular(Responsive.borderRadius),
        child: Container(
          padding: EdgeInsets.all(Responsive.isShort(context) ? 6.sp : 8.sp),
          decoration: BoxDecoration(
            color: color ?? Theme.of(context).dividerColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular( Responsive.borderRadius),
          ),
          child: Icon(icon, size: 20.sp, color: iconColor ?? Theme.of(context).colorScheme.onSurface),
        ),
      ),
    );
  }
}
