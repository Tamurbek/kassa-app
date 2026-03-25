import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
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
          'costPrice': item.costPrice,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.entry == null ? 'Yangi Kirim' : 'Kirimni Tahrirlash',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5),
        ),
        elevation: 0,
        centerTitle: false,
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
            Colors.green,
          ),
          const SizedBox(width: 8),
          _buildAppBarAction(
            Icons.file_download_outlined,
            'Shablon',
            () => ExcelImportService.downloadStockEntryTemplate(context, state.activeProducts),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildInputCard(
                              title: 'Ombor',
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: entryWarehouseId,
                                  isExpanded: true,
                                  items: state.warehouses
                                      .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                                      .toList(),
                                  onChanged: (val) => setState(() => entryWarehouseId = val),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildInputCard(
                              title: 'Sana',
                              child: InkWell(
                                onTap: _pickDate,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_month_rounded, size: 20, color: Colors.grey),
                                      const SizedBox(width: 12),
                                      Text(
                                        DateFormat('MMM d, yyyy HH:mm').format(selectedDate),
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildInputCard(
                        title: 'Tavsif (izoh)',
                        child: TextField(
                          controller: descriptionCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Qo\'shimcha ma\'lumotlar...',
                            border: InputBorder.none,
                            icon: Icon(Icons.notes_rounded, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: barcodeCtrl,
                              focusNode: barcodeFocusNode,
                              decoration: const InputDecoration(
                                labelText: 'Shtrix kod orqali qo\'shish',
                                hintText: 'Shtrix kodni o\'qing...',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.qr_code_scanner_rounded),
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
                    ],
                  ),
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
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: DropdownButtonFormField<String>(
                            value: item['productId'],
                            isExpanded: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                            ),
                            hint: const Text('Tanlang'),
                            items: state.products
                                .where((p) => !p.isDeleted || p.id == item['productId'])
                                .map((p) => DropdownMenuItem(
                                      value: p.id,
                                      child: Text(
                                        p.isDeleted ? '${p.name} (O\'ch.)' : p.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              final p = state.products.firstWhere((p) => p.id == val);
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
                            initialValue: item['costPrice'] == 0 ? '' : item['costPrice'].toString(),
                            decoration: const InputDecoration(
                              hintText: 'Tannarx',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                              suffixText: 's',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (val) => items[idx]['costPrice'] = double.tryParse(val) ?? 0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: item['quantity'] == 0 ? '' : item['quantity'].toString(),
                            decoration: const InputDecoration(
                              hintText: 'Soni',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (val) => items[idx]['quantity'] = double.tryParse(val) ?? 0,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => setState(() => items.removeAt(idx)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => setState(() => items.add({
                        'productId': null,
                        'productName': '',
                        'quantity': 0.0,
                        'costPrice': 0.0,
                      })),
                  icon: const Icon(Icons.add),
                  label: const Text('Mahsulot qo\'shish'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    foregroundColor: Theme.of(context).colorScheme.primary,
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
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      'SAQLASH',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ),
              ],
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
          items.add({
            'productId': product.id,
            'productName': product.name,
            'quantity': 1.0,
            'costPrice': product.costPrice,
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

  Future<void> _importExcel() async {
    final state = context.read<AppState>();
    final parsedItems = await ExcelImportService.parseStockEntryFile(context);
    
    if (parsedItems != null && parsedItems.isNotEmpty) {
      setState(() {
        for (var pItem in parsedItems) {
          final existingIdx = items.indexWhere((i) => i['productId'] == pItem.productId);
          if (existingIdx >= 0) {
            items[existingIdx]['quantity'] = (items[existingIdx]['quantity'] ?? 0) + pItem.quantity;
          } else {
            items.add({
              'productId': pItem.productId,
              'productName': pItem.productName,
              'quantity': pItem.quantity,
              'costPrice': pItem.costPrice,
            });
          }
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${parsedItems.length} ta mahsulot Exceldan o\'qildi')),
        );
      }
    }
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    if (entryWarehouseId == null) return;

    final finalItems = items
        .where((i) => i['productId'] != null && i['quantity'] > 0)
        .map(
          (i) => StockEntryItem(
            productId: i['productId'],
            productName: i['productName'],
            quantity: i['quantity'],
            costPrice: (i['costPrice'] as num).toDouble(),
          ),
        )
        .toList();

    if (finalItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kamida 1 ta mahsulot kiriting!')),
      );
      return;
    }

    final entry = StockEntry(
      id: widget.entry?.id ?? const Uuid().v4(),
      warehouseId: entryWarehouseId!,
      date: selectedDate,
      description: descriptionCtrl.text,
      items: finalItems,
    );

    try {
      if (widget.entry == null) {
        await state.addStockEntry(entry);
      } else {
        await state.updateStockEntry(entry);
      }
      
      await state.reloadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kirim hujjati muvaffaqiyatli saqlandi')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saqlashda xatolik: $e')),
        );
      }
    }
  }

  Widget _buildInputCard({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodySmall?.color,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildAppBarAction(IconData icon, String label, VoidCallback onTap, Color color) {
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
