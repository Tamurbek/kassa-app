import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/features/sales_provider.dart';
import '../../providers/features/inventory_provider.dart';
import '../../models/models.dart';

class ReturnsHistoryScreen extends StatelessWidget {
  final VoidCallback? onMenuPressed;
  const ReturnsHistoryScreen({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    final sales = context.watch<SalesProvider>();
    final inventory = context.watch<InventoryProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          color: Theme.of(context).cardColor,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: AppBar(
                automaticallyImplyLeading: false,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/icon.png',
                        width: 30,
                        height: 30,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('Vazvratlar Tarixi'),
                  ],
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                centerTitle: true,
                leading: onMenuPressed != null
                    ? IconButton(
                        icon: const Icon(Icons.menu_rounded),
                        onPressed: onMenuPressed,
                      )
                    : null,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.orange),
                    onPressed: () => _showReturnDialog(context, sales, inventory),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
      body: sales.returns.isEmpty
          ? Center(
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
                return _buildLogCard(
                  context,
                  sales,
                  'Vazvrat #${ret.id.substring(0, 8)}',
                  'Sotuv #${ret.saleId.substring(0, 8)} • ${ret.date.toString().substring(0, 16)}',
                  ret.items.length.toString(),
                  Colors.orange,
                  ret.items
                      .map(
                        (i) => ListTile(
                          title: Text(i.productName),
                          trailing: Text(
                            '${i.quantity} x ${i.price.toStringAsFixed(0)}',
                          ),
                        ),
                      )
                      .toList(),
                  onDelete: () => _confirmDelete(
                    context,
                    'Vazvratni bekor qilmoqchimisiz?',
                    () => sales.deleteReturn(ret.id),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildLogCard(
    BuildContext context,
    SalesProvider sales,
    String title,
    String subtitle,
    String count,
    Color color,
    List<Widget> items, {
    VoidCallback? onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.02,
            ),
            blurRadius: 10,
          ),
        ],
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(Icons.assignment_return_outlined, color: color, size: 20),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count ta tur',
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            if (onDelete != null)
              IconButton(
                icon: Icon(Icons.cancel_outlined, color: Colors.grey, size: 20),
                onPressed: onDelete,
              ),
          ],
        ),
        children: items,
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    String message,
    Future<void> Function() action,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tasdiqlash'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Yo\'q'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await action();
              if (context.mounted) Navigator.pop(context);
            },
            child: Text('Ha, bekor qilinsin'),
          ),
        ],
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
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Shtrix kod',
                            hintText: 'Skanerlang...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.qr_code_scanner),
                          ),
                          onSubmitted: (barcode) {
                            if (barcode.isEmpty) return;
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
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  ...items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: item['productId'],
                              items: inventory.activeProducts
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p.id,
                                      child: Text(p.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                final p = inventory.activeProducts.firstWhere(
                                  (p) => p.id == val,
                                );
                                setDialogState(() {
                                  items[idx]['productId'] = val;
                                  items[idx]['productName'] = p.name;
                                  items[idx]['price'] = p.price;
                                });
                              },
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Soni',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => items[idx]['quantity'] =
                                  double.tryParse(v) ?? 0,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () =>
                                setDialogState(() => items.removeAt(idx)),
                          ),
                        ],
                      ),
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
              onPressed: () {
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
                  sales.addReturn(ret);
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
