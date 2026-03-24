import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
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
    final state = context.read<AppState>();

    if (widget.entry != null) {
      entryWarehouseId = widget.entry!.warehouseId;
      descriptionCtrl.text = widget.entry!.description;
      selectedDate = widget.entry!.date;
      for (var item in widget.entry!.items) {
        items.add({
          'productId': item.productId,
          'productName': item.productName,
          'quantity': item.quantity,
        });
      }
    } else {
      entryWarehouseId = state.mainWarehouse?.id;
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
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.entry == null ? 'Yangi Kirim Hujjati' : 'Kirimni Tahrirlash',
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.file_download_outlined, color: Colors.amber),
            tooltip: 'Kirim shablonini yuklab olish',
            onPressed: () => ExcelImportService.downloadStockEntryTemplate(context, context.read<AppState>().activeProducts),
          ),
          IconButton(
            icon: Icon(Icons.file_upload_outlined, color: Colors.indigo),
            tooltip: 'Exceldan kirim qilish',
            onPressed: () {
              if (entryWarehouseId != null) {
                ExcelImportService.importStockEntry(context, entryWarehouseId!);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avval omborni tanlang')));
              }
            },
          ),
          IconButton(icon: Icon(Icons.save), onPressed: _save),
          SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
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
                      value: entryWarehouseId,
                      decoration: const InputDecoration(
                        labelText: 'Ombor',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.store),
                      ),
                      items: state.warehouses
                          .map(
                            (w) => DropdownMenuItem(
                              value: w.id,
                              child: Text('${w.name}${w.isMain ? ' (Asosiy)' : ''}'),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => entryWarehouseId = val),
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
                controller: descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tavsif (izoh)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
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
                          items: state.products
                              .where((p) => !p.isDeleted || p.id == item['productId'])
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(p.isDeleted ? '${p.name} (O\'chirilgan)' : p.name),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            final p = state.products.firstWhere(
                              (p) => p.id == val,
                            );
                            setState(() {
                              items[idx]['productId'] = val;
                              items[idx]['productName'] = p.name;
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          initialValue: item['quantity'] == 0
                              ? ''
                              : item['quantity'].toString(),
                          decoration: const InputDecoration(
                            hintText: 'Soni',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => items[idx]['quantity'] =
                              double.tryParse(val) ?? 0,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.remove_circle, color: Colors.red),
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
                    'quantity': 0.0,
                  }),
                ),
                icon: Icon(Icons.add),
                label: Text('Mahsulot qo\'shish'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.1),
                  foregroundColor: Theme.of(context).colorScheme.primary,
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
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'SAQLASH',
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
          items.add({
            'productId': product.id,
            'productName': product.name,
            'quantity': 1.0,
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
    final state = context.read<AppState>();
    if (entryWarehouseId == null) return;

    final finalItems = items
        .where((i) => i['productId'] != null && i['quantity'] > 0)
        .map(
          (i) => StockEntryItem(
            productId: i['productId'],
            productName: i['productName'],
            quantity: i['quantity'],
          ),
        )
        .toList();

    if (finalItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kamida 1 ta mahsulot kiriting!')));
      return;
    }

    final entry = StockEntry(
      id: widget.entry?.id ?? Uuid().v4(),
      warehouseId: entryWarehouseId!,
      date: selectedDate,
      description: descriptionCtrl.text,
      items: finalItems,
    );

    if (widget.entry == null) {
      state.addStockEntry(entry);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kirim hujjati saqlandi')));
    } else {
      state.updateStockEntry(entry);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kirim hujjati tahrirlandi')));
    }

    Navigator.pop(context);
  }
}
