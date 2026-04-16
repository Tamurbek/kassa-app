import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/features/inventory_provider.dart';
import '../../providers/features/auth_provider.dart';
import '../../providers/features/settings_provider.dart';
import '../../providers/app_state.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/product_selection_row.dart';
import '../widgets/barcode_scanner_input.dart';
import '../widgets/app_status_bar.dart';

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

    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: CustomAppBar(
        title: widget.inventory == null
            ? 'Yangi Inventarizatsiya'
            : 'Inventarizatsiyani Tahrirlash',
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: Theme.of(context).colorScheme.primary,
        ),
        actions: [
          IconButton(
            icon: Icon(_isSaving ? Icons.sync_rounded : Icons.save, color: Colors.teal), 
            onPressed: _isSaving ? null : _save
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
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
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: _pickDate,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
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
                        const SizedBox(height: 16),
                        TextField(
                          controller: descCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Tavsif (ixtiyoriy)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.comment),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        BarcodeScannerInput(
                          controller: barcodeCtrl,
                          focusNode: barcodeFocusNode,
                          label: 'Shtrix kod orqali qo\'shish',
                          hint: 'Shtrix kodni o\'qing yoki yozing...',
                          onBarcodeSubmitted: (val) => _handleBarcode(val, inventoryProv),
                        ),
                        const Divider(height: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'Mahsulotlar',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 16),
                        ...items.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          return ProductSelectionRow(
                            selectedProduct: item['productId'] != null
                                ? inventoryProv.activeProducts.firstWhere(
                                    (p) => p.id == item['productId'],
                                    orElse: () => inventoryProv.activeProducts.first,
                                  )
                                : null,
                            availableProducts: inventoryProv.activeProducts,
                            quantity: item['actual'] ?? 0.0,
                            quantityHint: 'Haqiqiy',
                            extraInfo: [
                              Expanded(
                                child: Text(
                                  'Kutilgan:\n${item['expected'] ?? 0}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                            ],
                            onProductChanged: (val) {
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
                            onQuantityChanged: (val) =>
                                items[idx]['actual'] = double.tryParse(val) ?? 0,
                            onRemove: () => setState(() => items.removeAt(idx)),
                          );
                        }),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => setState(
                            () => items.add({
                              'productId': null,
                              'productName': '',
                              'expected': 0.0,
                              'actual': 0.0,
                            }),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Mahsulot qo\'shish'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.withOpacity(0.1),
                            foregroundColor: Colors.teal,
                            elevation: 0,
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
                            child: _isSaving 
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text(
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
          ),
        ],
      ),
    );
  }

  void _handleBarcode(String barcode, InventoryProvider inventoryProv) {
    if (barcode.isEmpty) return;

    try {
      final product = inventoryProv.products.firstWhere(
        (p) => p.barcode == barcode || 
               p.additionalBarcodes.contains(barcode) ||
               p.boxBarcode == barcode ||
               p.additionalBoxBarcodes.contains(barcode),
      );

      setState(() {
        final existingIdx =
            items.indexWhere((i) => i['productId'] == product.id);
        if (existingIdx >= 0) {
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

  bool _isSaving = false;
  Future<void> _save() async {
    if (_isSaving) return;
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
      ).showSnackBar(const SnackBar(content: Text('Kamida 1 ta mahsulot kiriting!')));
      return;
    }

    setState(() => _isSaving = true);
    final entry = InventoryEntry(
      id: widget.inventory?.id ?? const Uuid().v4(),
      date: selectedDate,
      warehouseId: invWarehouseId!,
      description: descCtrl.text,
      items: finalItems,
    );

    try {
      if (widget.inventory == null) {
        await inventoryProv.addInventory(entry);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inventarizatsiya saqlandi')));
      } else {
        await inventoryProv.updateInventory(entry);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inventarizatsiya tahrirlandi')));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xatolik: $e')));
      }
    }
  }
}
