import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/models.dart';
import '../../../providers/features/sales_provider.dart';
import '../../../providers/features/settings_provider.dart';
import 'package:simple_sale/core/utils/responsive.dart';

class POSProductCard extends StatelessWidget {
  final Product product;
  final SalesProvider sales;
  final SettingsProvider settings;

  const POSProductCard({
    super.key,
    required this.product,
    required this.sales,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final stock = product.stocks[settings.currentRegister?.warehouseId] ?? 0;
    final isLowStock = stock <= 0;

    return InkWell(
      onTap: () {
        try {
          sales.addToCart(product, warehouseId: settings.currentRegister?.warehouseId);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(Responsive.borderRadius),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.4)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10.sp, offset: Offset(0, 4.h))],
        ),
        child: Padding(
          padding: EdgeInsets.all(12.sp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  product.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w900, 
                    fontSize: 13.sp, 
                    height: 1.1,
                    color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.9),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(product.price)} s',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 15.sp,
                        ),
                      ),
                    ),
                  ),
                  if (settings.shouldTrackInventory && product.trackStock)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLowStock ? Colors.red.withOpacity(0.12) : Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${stock % 1 == 0 ? stock.toInt() : stock.toStringAsFixed(1)} ${product.unit}',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w900,
                          color: isLowStock ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
