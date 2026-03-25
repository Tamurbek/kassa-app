import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/features/inventory_provider.dart';

class InventoryScreen extends StatefulWidget {
  final InventoryEntry? inventory;

  const InventoryScreen({super.key, this.inventory});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String? invWarehouseId;
  final TextEditingController descCtrl = TextEditingController();
  final List<Map<String, dynamic>> items = [];
  final TextEditingController barcodeCtrl = TextEditingController();
  final FocusNode barcodeFocusNode = FocusNode();
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final inventoryProv = context.read<InventoryProvider>();

    if (widget.inventory != null) {
      invWarehouseId = widget.inventory!.warehouseId;
      descCtrl.text = widget.inventory!.description ?? '';
      selectedDate = widget.inventory!.date;
      for (var item in widget.inventory!.items) {
        items.add({
          'productId': item.productId,
          'productName': item.productName,
          'expected': item.expectedQuantity,
          'actual': item.actualQuantity,
        });
      }
    } else {
      if (inventoryProv.warehouses.isNotEmpty) {
        invWarehouseId = inventoryProv.warehouses.first.id;
      }
    }
  }

  @override
  void dispose() {
    descCtrl.dispose();
    barcodeCtrl.dispose();
    barcodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(selectedDate),
      );
      if (time != null) {
        setState(() {
          selectedDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProv = context.watch<InventoryProvider>();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          color: Theme.of(context).cardColor,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: AppBar(
                title: Text(
                  widget.inventory == null
                      ? 'Yangi Inventarizatsiya'
                      : 'Inventarizatsiyani Tahrirlash',
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                actions: [
                  IconButton(icon: Icon(Icons.save), onPressed: _save),
                  SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: invWarehouseId,
                          decoration: const InputDecoration(
                            labelText: 'Ombor',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.store),
                          ),
                          items: inventoryProv.warehouses
                              .map(
                                (w) => DropdownMenuItem(
                                  value: w.id,
                                  child: Text(w.name),
                                ),
                              )
                              .toList(),
                          onChanged: (val) => setState(() => invWarehouseId = val),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Sana va vaqt',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(selectedDate.toString().substring(0, 16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tavsif (ixtiyoriy)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.comment),
                    ),
                  ),
                  SizedBox(height: 24),
                  const Divider(),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: barcodeCtrl,
                          focusNode: barcodeFocusNode,
                          decoration: const InputDecoration(
                            labelText: 'Shtrix kod orqali qo\'shish',
                            hintText: 'Shtrix kodni o\'qing yoki yozing...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.qr_code_scanner),
                          ),
                          onSubmitted: (val) => _handleBarcode(val, inventoryProv),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () => _handleBarcode(barcodeCtrl.text, inventoryProv),
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 48),
                  SizedBox(height: 16),
                  Text(
                    'Mahsulotlar',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(height: 16),
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
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              hint: Text('Tanlang'),
                              items: inventoryProv.activeProducts
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p.id,
                                      child: Text(p.name),
                                    ),
                                  )
                                  .toList(),
                                onChanged: (val) {
                                if (val == null) return;
                                final p = inventoryProv.activeProducts.firstWhere(
                                  (p) => p.id == val,
                                );
                                setState(() {
                                  items[idx]['productId'] = val;
                                  items[idx]['productName'] = p.name;
                                  if (widget.inventory == null) {
                                    items[idx]['expected'] =
                                        p.stocks[invWarehouseId] ?? 0.0;
                                  }
                                });
                              },
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Kutilgan:\n${item['expected'] ?? 0}',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              initialValue: item['actual'] == 0
                                  ? ''
                                  : item['actual'].toString(),
                              decoration: const InputDecoration(
                                hintText: 'Haqiqiy',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (val) =>
                                  items[idx]['actual'] = double.tryParse(val) ?? 0,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.remove_circle, color: Colors.teal),
                            onPressed: () => setState(() => items.removeAt(idx)),
                          ),
                        ],
                      ),
                    );
                  }),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(
                      () => items.add({
                        'productId': null,
                        'productName': '',
                        'expected': 0.0,
                        'actual': 0.0,
                      }),
                    ),
                    icon: Icon(Icons.add),
                    label: Text('Mahsulot qo\'shish'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.withOpacity(0.1),
                      foregroundColor: Colors.teal,
                      elevation: 0,
                    ),
                  ),
                  SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        'Inventarizatsiyani Saqlash',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
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

  void _handleBarcode(String barcode, InventoryProvider inventoryProv) {
    if (barcode.isEmpty) return;

    try {
      final product = inventoryProv.products.firstWhere(
        (p) => p.barcode == barcode || p.additionalBarcodes.contains(barcode),
      );

      setState(() {
        final existingIdx =
            items.indexWhere((i) => i['productId'] == product.id);
        if (existingIdx >= 0) {
          // If already exists, just focus or maybe do nothing as actual quantity needs to be entered manually
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product.name} allaqachon ro\'yxatda bor'),
              duration: const Duration(seconds: 1),
            ),
          );
        } else {
          items.add({
            'productId': product.id,
            'productName': product.name,
            'expected': product.stocks[invWarehouseId] ?? 0.0,
            'actual': 0.0,
          });
        }
        barcodeCtrl.clear();
        barcodeFocusNode.requestFocus();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mahsulot topilmadi!')),
      );
    }
  }

  void _save() {
    final inventoryProv = context.read<InventoryProvider>();
    if (invWarehouseId == null) return;

    final finalItems = items
        .where((i) => i['productId'] != null)
        .map(
          (i) => InventoryItem(
            productId: i['productId'],
            productName: i['productName'],
            expectedQuantity: i['expected'] ?? 0.0,
            actualQuantity: i['actual'] ?? 0.0,
          ),
        )
        .toList();

    if (finalItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kamida 1 ta mahsulot kiriting!')));
      return;
    }

    final entry = InventoryEntry(
      id: widget.inventory?.id ?? Uuid().v4(),
      date: selectedDate,
      warehouseId: invWarehouseId!,
      description: descCtrl.text,
      items: finalItems,
    );

    if (widget.inventory == null) {
      inventoryProv.addInventory(entry);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Inventarizatsiya saqlandi')));
    } else {
      inventoryProv.updateInventory(entry);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Inventarizatsiya tahrirlandi')));
    }

    Navigator.pop(context);
  }
}
