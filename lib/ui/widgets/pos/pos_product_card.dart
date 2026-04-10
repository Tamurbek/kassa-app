import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/models.dart';
import '../../../providers/features/sales_provider.dart';
import '../../../providers/features/settings_provider.dart';

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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.25),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(product.price)} s',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isLowStock ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${stock % 1 == 0 ? stock.toInt() : stock.toStringAsFixed(1)} ${product.unit}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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
