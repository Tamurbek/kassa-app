import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/models.dart';
import '../../../providers/features/inventory_provider.dart';
import '../../../providers/features/sales_provider.dart';
import '../../../providers/features/settings_provider.dart';
import 'package:simple_sale/core/utils/responsive.dart';
import 'package:simple_sale/core/utils/formatter.dart';

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
                  item.productName + (item.isBox ? ' (BLOK)' : ''),
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, letterSpacing: -0.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  item.isBox 
                    ? '${(item.price * (product?.quantityInBox ?? 1)).toStringAsFixed(0)} s / blok'
                    : '${item.price.toStringAsFixed(0)} s',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                  ),
                ),
                if (product != null && product.quantityInBox > 1) ...[
                  SizedBox(height: 8.h),
                  InkWell(
                    onTap: () {
                      // Toggle isBox mode
                      final newIsBox = !item.isBox;
                      final double newQty = newIsBox ? (1.0 * product.quantityInBox) : 1.0;
                      sales.updateCartItemMode(item.productId, item.isBox, newIsBox, newQty, product: product);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.sp, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: item.isBox ? Colors.amber.withOpacity(0.15) : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: (item.isBox ? Colors.amber : Colors.blue).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.isBox ? Icons.inventory_2_outlined : Icons.ads_click_rounded, 
                            size: 10.sp, 
                            color: item.isBox ? Colors.orange.shade900 : Colors.blue.shade900
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            item.isBox ? 'BLOK REJIMIDA' : 'DONA REJIMIDA',
                            style: TextStyle(
                              fontSize: 9.sp, 
                              fontWeight: FontWeight.w900,
                              color: item.isBox ? Colors.orange.shade900 : Colors.blue.shade900,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(Icons.swap_horiz_rounded, size: 10.sp, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ],
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
                    onTap: () => sales.decrementCartItem(item.productId, item.isBox, product: product, warehouseId: settings.currentRegister?.warehouseId),
                    color: Colors.red.withOpacity(0.08),
                    iconColor: Colors.red,
                  ),
                  InkWell(
                    onTap: () => onShowQuantityDialog(item),
                    child: Container(
                      width: 50.w,
                      alignment: Alignment.center,
                      child: Text(
                        item.isBox && product != null
                            ? AppFormatter.formatDouble(item.quantity / product.quantityInBox)
                            : AppFormatter.formatDouble(item.quantity),
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp),
                      ),
                    ),
                  ),
                  _QtyButton(
                    icon: Icons.add,
                    onTap: () {
                      if (product != null) {
                        try {
                          sales.incrementCartItem(item.productId, item.isBox, product: product, warehouseId: settings.currentRegister?.warehouseId);
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
