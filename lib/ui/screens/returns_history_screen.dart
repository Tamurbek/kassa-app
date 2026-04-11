import '../../models/models.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/log_card.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/product_selection_row.dart';
import '../widgets/barcode_scanner_input.dart';
import '../../providers/features/sales_provider.dart';
import '../../providers/features/inventory_provider.dart';
import '../../providers/app_state.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

class ReturnsHistoryScreen extends StatelessWidget {
  final VoidCallback? onMenuPressed;
  const ReturnsHistoryScreen({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sales = context.watch<SalesProvider>();
    final inventory = context.watch<InventoryProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: 'Vazvratlar Tarixi',
        onMenuPressed: onMenuPressed,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.orange),
            onPressed: () => _showReturnDialog(context, sales, inventory),
          ),
        ],
      ),
      body: sales.returns.isEmpty
          ? const Center(
              child: Text(
                'Vazvratlar mavjud emas',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: sales.returns.length,
              itemBuilder: (context, index) {
                final ret = sales.returns[index];
                return LogCard(
                  title: 'Vazvrat #${ret.id.length > 8 ? ret.id.substring(0, 8) : ret.id}',
                  subtitle: 'Sotuv #${ret.saleId.length > 8 ? ret.saleId.substring(0, 8) : ret.saleId} • ${ret.date.toString().substring(0, 16)}',
                  trailingText: '${ret.items.length} ta tur',
                  accentColor: Colors.orange,
                  leadingIcon: Icons.assignment_return_outlined,
                  onDelete: () => ConfirmationDialog.show(
                    context,
                    title: 'Tasdiqlash',
                    message: 'Vazvratni bekor qilmoqchimisiz?',
                    confirmLabel: 'Ha, bekor qilinsin',
                    confirmColor: Colors.redAccent,
                    onConfirm: () async {
                      final inventory = context.read<InventoryProvider>();
                      final appState = context.read<AppState>();
                      await sales.deleteReturn(ret.id);
                      await inventory.reloadData();
                      await appState.reloadData();
                    },
                  ),
                  children: ret.items
                      .map(
                        (i) => ListTile(
                          title: Text(i.productName),
                          trailing: Text(
                            '${i.quantity} x ${i.price.toStringAsFixed(0)}',
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
    );
  }


  void _showReturnDialog(BuildContext context, SalesProvider sales, InventoryProvider inventory) {
    final List<Map<String, dynamic>> items = [];
    final saleIdCtrl = TextEditingController();
    String? returnWarehouseId = inventory.warehouses.isNotEmpty
        ? inventory.warehouses.first.id
        : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Yangi Vazvrat (Qaytarish)'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: returnWarehouseId,
                    decoration: const InputDecoration(
                      labelText: 'Qaysi omborga?',
                      border: OutlineInputBorder(),
                    ),
                    items: inventory.warehouses
                        .map(
                          (w) => DropdownMenuItem(
                            value: w.id,
                            child: Text(w.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setDialogState(() => returnWarehouseId = val),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: saleIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Sotuv ID (ixtiyoriy)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const Divider(height: 32),
                  BarcodeScannerInput(
                    label: 'Shtrix kod',
                    hint: 'Skanerlang...',
                    onBarcodeSubmitted: (barcode) {
                      try {
                        final p = inventory.activeProducts.firstWhere(
                          (p) =>
                              p.barcode == barcode ||
                              p.additionalBarcodes.contains(barcode),
                        );
                        setDialogState(() {
                          final existingIdx = items.indexWhere(
                            (i) => i['productId'] == p.id,
                          );
                          if (existingIdx >= 0) {
                            items[existingIdx]['quantity'] =
                                (items[existingIdx]['quantity'] ?? 0) + 1;
                          } else {
                            items.add({
                              'productId': p.id,
                              'productName': p.name,
                              'quantity': 1.0,
                              'price': p.price,
                            });
                          }
                        });
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Mahsulot topilmadi!'),
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 32),
                  ...items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return ProductSelectionRow(
                      selectedProduct: item['productId'] != null
                          ? inventory.activeProducts.firstWhere(
                              (p) => p.id == item['productId'],
                            )
                          : null,
                      availableProducts: inventory.activeProducts,
                      quantity: item['quantity'] ?? 0.0,
                      onProductChanged: (val) {
                        final p = inventory.activeProducts.firstWhere(
                          (p) => p.id == val,
                        );
                        setDialogState(() {
                          items[idx]['productId'] = val;
                          items[idx]['productName'] = p.name;
                          items[idx]['price'] = p.price;
                        });
                      },
                      onQuantityChanged: (v) =>
                          items[idx]['quantity'] = double.tryParse(v) ?? 0,
                      onRemove: () => setDialogState(() => items.removeAt(idx)),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () => setDialogState(
                      () => items.add({
                        'productId': null,
                        'productName': '',
                        'quantity': 0.0,
                        'price': 0.0,
                      }),
                    ),
                    icon: Icon(Icons.add),
                    label: Text('Mahsulot qo\'shish'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Yopish'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (items.isNotEmpty && returnWarehouseId != null) {
                  final ret = SaleReturn(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    saleId: saleIdCtrl.text.isEmpty
                        ? 'HAND_RETURN'
                        : saleIdCtrl.text,
                    date: DateTime.now(),
                    warehouseId: returnWarehouseId!,
                    total: items.fold(
                      0,
                      (sum, i) => sum + (i['price'] * (i['quantity'] ?? 0)),
                    ),
                    items: items
                        .where((i) => i['productId'] != null)
                        .map(
                          (i) => SaleReturnItem(
                            productId: i['productId'],
                            productName: i['productName'],
                            quantity: i['quantity'],
                            price: i['price'],
                          ),
                        )
                        .toList(),
                  );
                  final appState = context.read<AppState>();
                  await sales.addReturn(ret);
                  await inventory.reloadData();
                  await appState.reloadData();
                  Navigator.pop(context);
                }
              },
              child: Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }
}
