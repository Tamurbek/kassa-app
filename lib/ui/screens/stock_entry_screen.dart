import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/features/inventory_provider.dart';
import '../../providers/app_state.dart';
import 'package:intl/intl.dart';
import '../../services/excel_import_service.dart';
import '../../providers/features/auth_provider.dart';
import '../../providers/features/settings_provider.dart';
import '../widgets/app_status_bar.dart';

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
  TextEditingController? _nameSearchCtrl;
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
          'price': item.price,
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

    final auth = context.watch<AuthProvider>();
    final settingsProv = context.watch<SettingsProvider>();

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
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: ListView(
                  padding: const EdgeInsets.all(16),
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
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: barcodeCtrl,
                            focusNode: barcodeFocusNode,
                            decoration: InputDecoration(
                              labelText: 'Shtrix kod orqali qo\'shish',
                              prefixIcon: const Icon(Icons.qr_code_scanner),
                              suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: () => _handleBarcode(barcodeCtrl.text, inventory)),
                              border: const OutlineInputBorder(),
                            ),
                            onSubmitted: (val) => _handleBarcode(val, inventory),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 4,
                          child: Autocomplete<Product>(
                            displayStringForOption: (Product option) => option.name,
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text == '') {
                                return const Iterable<Product>.empty();
                              }
                              return inventory.activeProducts.where((Product option) {
                                return option.name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                              });
                            },
                            onSelected: (Product selection) {
                              _addProductToItems(selection);
                              _nameSearchCtrl?.clear();
                            },
                            fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                              _nameSearchCtrl = textController;
                              return TextField(
                                controller: textController,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Nomi bo\'yicha izlash',
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (val) {
                                  onFieldSubmitted();
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Mahsulotlar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 16),
                    ...items.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final bool isSmall = constraints.maxWidth < 650;
                            
                            if (isSmall) {
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: _buildProductDropdown(idx, item, inventory)),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => setState(() => items.removeAt(idx)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(child: _buildCompactInput(item['costPrice'], 'Tan narxi', (val) => items[idx]['costPrice'] = double.tryParse(val) ?? 0)),
                                      const SizedBox(width: 8),
                                      Expanded(child: _buildCompactInput(item['price'], 'Sotuv narxi', (val) => items[idx]['price'] = double.tryParse(val) ?? 0)),
                                      const SizedBox(width: 8),
                                      Expanded(child: _buildCompactInput(item['quantity'], 'Soni', (val) => items[idx]['quantity'] = double.tryParse(val) ?? 0)),
                                    ],
                                  ),
                                ],
                              );
                            }
          
                            return Row(
                              children: [
                                Expanded(flex: 4, child: _buildProductDropdown(idx, item, inventory)),
                                const SizedBox(width: 8),
                                Expanded(flex: 2, child: _buildCompactInput(item['costPrice'], 'Tan narxi', (val) => items[idx]['costPrice'] = double.tryParse(val) ?? 0)),
                                const SizedBox(width: 8),
                                Expanded(flex: 2, child: _buildCompactInput(item['price'], 'Sotuv narxi', (val) => items[idx]['price'] = double.tryParse(val) ?? 0)),
                                const SizedBox(width: 8),
                                Expanded(flex: 2, child: _buildCompactInput(item['quantity'], 'Soni', (val) => items[idx]['quantity'] = double.tryParse(val) ?? 0)),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () => setState(() => items.removeAt(idx)),
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(onPressed: () => setState(() => items.add({'productId': null, 'productName': '', 'quantity': 0.0, 'costPrice': 0.0, 'price': 0.0})), icon: const Icon(Icons.add), label: const Text('Qator qo\'shish')),
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
          ),
        ],
      ),
    );
  }

  void _handleBarcode(String barcode, InventoryProvider inventory) {
    if (barcode.isEmpty) return;
    try {
      final p = inventory.activeProducts.firstWhere((p) => p.barcode == barcode || p.additionalBarcodes.contains(barcode));
      _addProductToItems(p);
      barcodeCtrl.clear();
      barcodeFocusNode.requestFocus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mahsulot topilmadi!')));
    }
  }

  void _addProductToItems(Product p) {
    setState(() {
      final existingIdx = items.indexWhere((i) => i['productId'] == p.id);
      if (existingIdx >= 0) {
        items[existingIdx]['quantity'] = (items[existingIdx]['quantity'] ?? 0) + 1;
      } else {
        items.add({
          'productId': p.id,
          'productName': p.name,
          'quantity': 1.0,
          'costPrice': p.costPrice,
          'price': p.price
        });
      }
    });
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
            items.add({'productId': pItem.productId, 'productName': pItem.productName, 'quantity': pItem.quantity, 'costPrice': pItem.costPrice, 'price': pItem.price});
          }
        }
      });
    }
  }

  Future<void> _save() async {
    final inventory = context.read<InventoryProvider>();
    if (entryWarehouseId == null) return;
    final finalItems = items.where((i) => i['productId'] != null && i['quantity'] > 0).map((i) => StockEntryItem(
      productId: i['productId'], 
      productName: i['productName'], 
      quantity: i['quantity'], 
      costPrice: (i['costPrice'] as num).toDouble(),
      price: (i['price'] as num).toDouble(),
    )).toList();
    if (finalItems.isEmpty) return;

    final entry = StockEntry(id: widget.entry?.id ?? const Uuid().v4(), warehouseId: entryWarehouseId!, date: selectedDate, description: descriptionCtrl.text, items: finalItems);
    try {
      final appState = context.read<AppState>();
      await inventory.addStockEntry(entry);
      await appState.reloadData();
      if (mounted) Navigator.pop(context);
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xatolik: $e')));
    }
  }

  Widget _buildProductDropdown(int idx, Map<String, dynamic> item, InventoryProvider inventory) {
    return DropdownButtonFormField<String>(
      value: item['productId'],
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(), 
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        hintText: 'Mahsulotni tanlang',
        isDense: true,
      ),
      items: inventory.activeProducts.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (val) {
        if (val == null) return;
        final p = inventory.activeProducts.firstWhere((p) => p.id == val);
        setState(() {
          items[idx]['productId'] = val;
          items[idx]['productName'] = p.name;
          items[idx]['costPrice'] = p.costPrice;
          items[idx]['price'] = p.price;
        });
      },
    );
  }

  Widget _buildCompactInput(dynamic initialValue, String label, Function(String) onChanged) {
    return TextFormField(
      initialValue: initialValue.toString(),
      decoration: InputDecoration(
        border: const OutlineInputBorder(), 
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      style: const TextStyle(fontSize: 13),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
    );
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
