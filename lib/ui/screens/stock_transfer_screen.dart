import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';

class StockTransferScreen extends StatefulWidget {
  const StockTransferScreen({super.key});

  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen> {
  String? fromWarehouseId;
  String? toWarehouseId;
  final TextEditingController descriptionCtrl = TextEditingController();
  final List<Map<String, dynamic>> items = [];
  final TextEditingController barcodeCtrl = TextEditingController();
  final FocusNode barcodeFocusNode = FocusNode();
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    fromWarehouseId = state.mainWarehouse?.id;
    if (state.warehouses.length > 1) {
      toWarehouseId = state.warehouses.firstWhere((w) => w.id != fromWarehouseId).id;
    }
  }

  @override
  void dispose() {
    descriptionCtrl.dispose();
    barcodeCtrl.dispose();
    barcodeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Omborlararo Ko\'chirish'),
        backgroundColor: Theme.of(context).cardColor,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: fromWarehouseId,
                          decoration: const InputDecoration(
                            labelText: 'Qaysi ombordan',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.outbox_rounded, color: Colors.red),
                          ),
                          items: state.warehouses
                              .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                              .toList(),
                          onChanged: (val) => setState(() => fromWarehouseId = val),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.grey),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: toWarehouseId,
                          decoration: const InputDecoration(
                            labelText: 'Qaysi omborga',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.inbox_rounded, color: Colors.green),
                          ),
                          items: state.warehouses
                              .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                              .toList(),
                          onChanged: (val) => setState(() => toWarehouseId = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tavsif (izoh)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                  const Divider(height: 48),
                  
                  Row(
                    children: [
                       Expanded(
                        child: TextField(
                          controller: barcodeCtrl,
                          focusNode: barcodeFocusNode,
                          decoration: const InputDecoration(
                            labelText: 'Shtrix kod orqali qo\'shish',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.qr_code_scanner),
                          ),
                          onSubmitted: (val) => _handleBarcode(val, state),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () => _handleBarcode(barcodeCtrl.text, state),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
    
                  const SizedBox(height: 24),
                  const Text('Mahsulotlar ro\'yxati:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  
                  ...items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: item['productId'],
                              isExpanded: true,
                              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                              items: state.activeProducts.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                              onChanged: (val) {
                                if (val == null) return;
                                final p = state.activeProducts.firstWhere((p) => p.id == val);
                                setState(() {
                                  items[idx]['productId'] = val;
                                  items[idx]['productName'] = p.name;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              initialValue: item['quantity'] == 0 ? '' : item['quantity'].toString(),
                              decoration: const InputDecoration(hintText: 'Soni', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                              keyboardType: TextInputType.number,
                              onChanged: (val) => items[idx]['quantity'] = double.tryParse(val) ?? 0,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            onPressed: () => setState(() => items.removeAt(idx)),
                          ),
                        ],
                      ),
                    );
                  }),
    
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => items.add({'productId': null, 'productName': '', 'quantity': 0.0})),
                    icon: const Icon(Icons.add),
                    label: const Text('Qatlam qo\'shish'),
                    style: ElevatedButton.styleFrom(elevation: 0, backgroundColor: Colors.blue.withOpacity(0.1), foregroundColor: Colors.blue),
                  ),
    
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('KO\'CHIRISHNI TASDIQLASH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleBarcode(String barcode, AppState state) {
    if (barcode.isEmpty) return;
    try {
      final product = state.products.firstWhere(
        (p) => p.barcode == barcode || p.additionalBarcodes.contains(barcode),
      );
      setState(() {
        final existingIdx = items.indexWhere((i) => i['productId'] == product.id);
        if (existingIdx >= 0) {
          items[existingIdx]['quantity'] = (items[existingIdx]['quantity'] ?? 0) + 1;
        } else {
          items.add({'productId': product.id, 'productName': product.name, 'quantity': 1.0});
        }
        barcodeCtrl.clear();
        barcodeFocusNode.requestFocus();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mahsulot topilmadi!')));
    }
  }

  void _save() {
    final state = context.read<AppState>();
    if (fromWarehouseId == null || toWarehouseId == null) return;
    if (fromWarehouseId == toWarehouseId) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bir xil omborga ko\'chirib bo\'lmaydi!'), backgroundColor: Colors.orange));
       return;
    }

    final finalItems = items
        .where((i) => i['productId'] != null && i['quantity'] > 0)
        .map((i) => StockTransferItem(productId: i['productId'], productName: i['productName'], quantity: i['quantity']))
        .toList();

    if (finalItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kamida 1 ta mahsulot kiriting!')));
      return;
    }

    final transfer = StockTransfer(
      id: const Uuid().v4(),
      fromWarehouseId: fromWarehouseId!,
      toWarehouseId: toWarehouseId!,
      date: DateTime.now(),
      description: descriptionCtrl.text,
      items: finalItems,
    );

    state.addStockTransfer(transfer);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mahsulotlar muvaffaqiyatli ko\'chirildi'), backgroundColor: Colors.green));
    Navigator.pop(context);
  }
}
