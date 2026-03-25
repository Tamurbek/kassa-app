import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/features/inventory_provider.dart';
import 'package:intl/intl.dart';
import '../../services/excel_import_service.dart';

class StockEntryScreen extends StatefulWidget {
  final StockEntry? entry;

  const StockEntryScreen({super.key, this.entry});

  @override
  State<StockEntryScreen> createState() => _StockEntryScreenState();
}

class _StockEntryScreenState extends State<StockEntryScreen> {
  String? entryWarehouseId;
  final TextEditingController descriptionCtrl = TextEditingController();
  final List<Map<String, dynamic>> items = [];
  final TextEditingController barcodeCtrl = TextEditingController();
  final FocusNode barcodeFocusNode = FocusNode();
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final inventory = context.read<InventoryProvider>();

    if (widget.entry != null) {
      entryWarehouseId = widget.entry!.warehouseId;
      descriptionCtrl.text = widget.entry!.description;
      selectedDate = widget.entry!.date;
      for (var item in widget.entry!.items) {
        items.add({
          'productId': item.productId,
          'productName': item.productName,
          'quantity': item.quantity,
          'costPrice': item.costPrice,
        });
      }
    } else {
      entryWarehouseId = inventory.mainWarehouse?.id;
    }
  }

  @override
  void dispose() {
    descriptionCtrl.dispose();
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
          selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                title: Text(widget.entry == null ? 'Yangi Kirim' : 'Kirimni Tahrirlash', 
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                centerTitle: false,
                backgroundColor: Colors.transparent,
                elevation: 0,
                actions: [
                  _buildAppBarAction(
                    Icons.upload_file_rounded,
                    'Excel',
                    () {
                      if (entryWarehouseId != null) {
                        _importExcel();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avval omborni tanlang')));
                      }
                    },
                    Colors.green.shade800,
                  ),
                  const SizedBox(width: 8),
                  _buildAppBarAction(
                    Icons.file_download_outlined,
                    'Shablon',
                    () => ExcelImportService.downloadStockEntryTemplate(context, inventory.activeProducts),
                    Colors.amber.shade800,
                  ),
                  const SizedBox(width: 8),
                  _buildAppBarAction(
                    Icons.save_rounded,
                    'Saqlash',
                    _save,
                    Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildInputCard(title: 'Ombor', child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                          value: entryWarehouseId,
                          isExpanded: true,
                          items: inventory.warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                          onChanged: (val) => setState(() => entryWarehouseId = val),
                        )))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildInputCard(title: 'Sana', child: InkWell(onTap: _pickDate, child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(DateFormat('dd.MM.yyyy HH:mm').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)))))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInputCard(title: 'Izoh', child: TextField(controller: descriptionCtrl, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Qo\'shimcha ma\'lumotlar...'))),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: barcodeCtrl,
                focusNode: barcodeFocusNode,
                decoration: InputDecoration(
                  labelText: 'Shtrix kod orqali qo\'shish',
                  suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: () => _handleBarcode(barcodeCtrl.text, inventory)),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (val) => _handleBarcode(val, inventory),
              ),
              const SizedBox(height: 24),
              const Text('Mahsulotlar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              ...items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<String>(
                          value: item['productId'],
                          isExpanded: true,
                          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                          items: inventory.activeProducts.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            final p = inventory.activeProducts.firstWhere((p) => p.id == val);
                            setState(() {
                              items[idx]['productId'] = val;
                              items[idx]['productName'] = p.name;
                              items[idx]['costPrice'] = p.costPrice;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: item['costPrice'].toString(),
                          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Narxi'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (val) => items[idx]['costPrice'] = double.tryParse(val) ?? 0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: item['quantity'].toString(),
                          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Soni'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (val) => items[idx]['quantity'] = double.tryParse(val) ?? 0,
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => setState(() => items.removeAt(idx))),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              OutlinedButton.icon(onPressed: () => setState(() => items.add({'productId': null, 'productName': '', 'quantity': 0.0, 'costPrice': 0.0})), icon: const Icon(Icons.add), label: const Text('Qator qo\'shish')),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('TASDIQLASH VA SAQLASH', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBarcode(String barcode, InventoryProvider inventory) {
    if (barcode.isEmpty) return;
    try {
      final p = inventory.activeProducts.firstWhere((p) => p.barcode == barcode || p.additionalBarcodes.contains(barcode));
      setState(() {
        final existingIdx = items.indexWhere((i) => i['productId'] == p.id);
        if (existingIdx >= 0) {
          items[existingIdx]['quantity'] = (items[existingIdx]['quantity'] ?? 0) + 1;
        } else {
          items.add({'productId': p.id, 'productName': p.name, 'quantity': 1.0, 'costPrice': p.costPrice});
        }
        barcodeCtrl.clear();
        barcodeFocusNode.requestFocus();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mahsulot topilmadi!')));
    }
  }

  Future<void> _importExcel() async {
    final parsedItems = await ExcelImportService.parseStockEntryFile(context);
    if (parsedItems != null && parsedItems.isNotEmpty) {
      setState(() {
        for (var pItem in parsedItems) {
          final existingIdx = items.indexWhere((i) => i['productId'] == pItem.productId);
          if (existingIdx >= 0) {
            items[existingIdx]['quantity'] = (items[existingIdx]['quantity'] ?? 0) + pItem.quantity;
          } else {
            items.add({'productId': pItem.productId, 'productName': pItem.productName, 'quantity': pItem.quantity, 'costPrice': pItem.costPrice});
          }
        }
      });
    }
  }

  Future<void> _save() async {
    final inventory = context.read<InventoryProvider>();
    if (entryWarehouseId == null) return;
    final finalItems = items.where((i) => i['productId'] != null && i['quantity'] > 0).map((i) => StockEntryItem(productId: i['productId'], productName: i['productName'], quantity: i['quantity'], costPrice: (i['costPrice'] as num).toDouble())).toList();
    if (finalItems.isEmpty) return;

    final entry = StockEntry(id: widget.entry?.id ?? const Uuid().v4(), warehouseId: entryWarehouseId!, date: selectedDate, description: descriptionCtrl.text, items: finalItems);
    try {
      await inventory.addStockEntry(entry);
      if (mounted) Navigator.pop(context);
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xatolik: $e')));
    }
  }

  Widget _buildInputCard({required String title, required Widget child}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withOpacity(0.2))), child: child),
    ]);
  }

  Widget _buildAppBarAction(IconData icon, String label, VoidCallback onTap, Color color) {
    return Center(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: color), const SizedBox(width: 8), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13))]))));
  }
}
