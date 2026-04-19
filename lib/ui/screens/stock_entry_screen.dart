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
import '../widgets/custom_app_bar.dart';
import '../../core/utils/formatter.dart';
import 'product_form_screen.dart';

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
        final product = inventory.activeProducts.where((p) => p.id == item.productId).firstOrNull;
        double displayQty = item.quantity;
        double displayCost = item.costPrice;
        double displayPrice = item.price;
        
        if (item.isBox && product != null && product.quantityInBox > 1) {
          displayQty = item.quantity / product.quantityInBox;
          displayCost = item.costPrice * product.quantityInBox;
          displayPrice = item.price * product.quantityInBox;
        }

        items.add({
          'productId': item.productId,
          'productName': item.productName,
          'quantity': displayQty,
          'costPrice': displayCost,
          'price': displayPrice,
          'isBox': item.isBox,
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

    final double totalPrice = items.fold(0.0, (sum, item) => sum + ((item['price'] as num).toDouble() * (item['quantity'] as num).toDouble()));
    final double totalCost = items.fold(0.0, (sum, item) => sum + ((item['costPrice'] as num).toDouble() * (item['quantity'] as num).toDouble()));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: widget.entry == null ? 'Yangi Kirim' : 'Kirimni Tahrirlash',
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: Theme.of(context).colorScheme.primary,
        ),
        actions: [
          _buildAppBarAction(Icons.upload_file_rounded, 'Excel', () {
            if (entryWarehouseId != null) _importExcel();
            else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avval omborni tanlang')));
          }, Colors.green.shade800),
          const SizedBox(width: 8),
          _buildAppBarAction(Icons.file_download_outlined, 'Shablon', () => _showTemplateSelectionDialog(context, inventory), Colors.amber.shade800),
          const SizedBox(width: 8),
          _buildAppBarAction(
            _isSaving ? Icons.sync_rounded : Icons.save_rounded, 
            _isSaving ? 'Saqlash...' : 'Saqlash', 
            _isSaving ? () {} : _save, 
            _isSaving ? Colors.grey : Theme.of(context).colorScheme.primary
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 950;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: isWide 
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT PANEL: Controls & Info
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildInfoCard(inventory),
                            const SizedBox(height: 16),
                            _buildSearchSection(inventory),
                            const SizedBox(height: 24),
                            _buildSummaryCard(totalCost, totalPrice),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // RIGHT PANEL: Product List
                    Expanded(
                      flex: 7,
                      child: _buildItemsList(inventory),
                    ),
                  ],
                )
              : ListView(
                  children: [
                    _buildInfoCard(inventory),
                    const SizedBox(height: 16),
                    _buildSearchSection(inventory),
                    const SizedBox(height: 24),
                    const Text('Mahsulotlar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 16),
                    ...items.asMap().entries.map((e) => _buildItemRow(e.key, e.value, inventory)),
                    const SizedBox(height: 16),
                    _buildAddRowButton(),
                    const SizedBox(height: 24),
                    _buildSummaryCard(totalCost, totalPrice),
                    const SizedBox(height: 16),
                    _buildSaveButton(),
                  ],
                ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(InventoryProvider inventory) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildInputCard(title: 'Ombor', child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                value: entryWarehouseId,
                isExpanded: true,
                items: inventory.warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                onChanged: (val) => setState(() => entryWarehouseId = val),
              )))),
              const SizedBox(width: 12),
              Expanded(child: _buildInputCard(title: 'Sana', child: InkWell(onTap: _pickDate, child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(DateFormat('dd.MM.yyyy HH:mm').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))))),
            ],
          ),
          const SizedBox(height: 16),
          _buildInputCard(title: 'Izoh', child: TextField(controller: descriptionCtrl, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Qo\'shimcha ma\'lumotlar...', isDense: true))),
        ],
      ),
    );
  }

  Widget _buildSearchSection(InventoryProvider inventory) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          TextField(
            controller: barcodeCtrl,
            focusNode: barcodeFocusNode,
            decoration: InputDecoration(
              labelText: 'Shtrix kod',
              hintText: 'Skanerlang...',
              prefixIcon: const Icon(Icons.qr_code_scanner),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
            ),
            onSubmitted: (val) => _handleBarcode(val, inventory),
          ),
          const SizedBox(height: 12),
          Autocomplete<Product>(
            displayStringForOption: (Product option) => option.name,
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text == '') return const Iterable<Product>.empty();
              return inventory.activeProducts.where((Product option) => option.matchesSearch(textEditingValue.text));
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
                decoration: InputDecoration(
                  labelText: 'Nomi bo\'yicha izlash',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _addNewProduct,
              icon: const Icon(Icons.add_business_rounded, size: 20),
              label: const Text('Yangi mahsulot qo\'shish', style: TextStyle(fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addNewProduct() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProductFormScreen()),
    );
    
    if (result != null && result is Product) {
      _addProductToItems(result);
    }
  }

  Widget _buildItemsList(InventoryProvider inventory) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8.0, bottom: 12),
          child: Text('Mahsulotlar Ro\'yxati', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        Expanded(
          child: items.isEmpty 
            ? Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('Mahsulotlar hali qo\'shilmadi', style: TextStyle(color: Colors.grey.shade500)),
                ],
              ))
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, idx) => _buildItemRow(idx, items[idx], inventory),
              ),
        ),
        const SizedBox(height: 12),
        _buildAddRowButton(),
      ],
    );
  }

  Widget _buildItemRow(int idx, Map<String, dynamic> item, InventoryProvider inventory) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Index Number
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${idx + 1}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Product Selection
          Expanded(flex: 12, child: _buildProductDisplay(idx, item, inventory)),
          const SizedBox(width: 12),
          // Unit Selection
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Birlik',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
                    border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<bool>(
                      value: item['isBox'] ?? false,
                      isExpanded: true,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                      items: const [
                        DropdownMenuItem(value: false, child: Text('Dona', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                        DropdownMenuItem(value: true, child: Text('Blok', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                      ],
                      onChanged: (val) => setState(() => items[idx]['isBox'] = val),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // cost price
          Expanded(flex: 4, child: _buildCompactInput(item['costPrice'], 'Tan narxi', (val) => items[idx]['costPrice'] = double.tryParse(val) ?? 0)),
          const SizedBox(width: 8),
          // selling price
          Expanded(flex: 4, child: _buildCompactInput(item['price'], 'Sotuv narxi', (val) => items[idx]['price'] = double.tryParse(val) ?? 0)),
          const SizedBox(width: 8),
          // quantity
          Expanded(flex: 3, child: _buildCompactInput(item['quantity'], 'Soni', (val) => items[idx]['quantity'] = double.tryParse(val) ?? 0)),
          const SizedBox(width: 12),
          // delete button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => items.removeAt(idx)),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double totalCost, double totalPrice) {
    final fmt = NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Umumiy Tan Narxi:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text('${fmt.format(totalCost)} so\'m', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const Divider(color: Colors.white24, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Umumiy Sotuv Narxi:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Text('${fmt.format(totalPrice)} so\'m', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddRowButton() {
    return OutlinedButton.icon(
      onPressed: () => setState(() => items.add({'productId': null, 'productName': '', 'quantity': 1.0, 'costPrice': 0.0, 'price': 0.0})),
      icon: const Icon(Icons.add_circle_outline),
      label: const Text('Yangi qator qo\'shish'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _save,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
      child: _isSaving 
        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Text('TASDIQLASH VA SAQLASH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
    );
  }

  void _handleBarcode(String barcode, InventoryProvider inventory) {
    if (barcode.isEmpty) return;
    try {
      final p = inventory.activeProducts.firstWhere((p) => 
        p.barcode == barcode || 
        p.additionalBarcodes.contains(barcode) ||
        p.boxBarcode == barcode ||
        p.additionalBoxBarcodes.contains(barcode)
      );
      final bool isBox = (p.boxBarcode == barcode || p.additionalBoxBarcodes.contains(barcode));
      _addProductToItems(p, isBox: isBox);
      barcodeCtrl.clear();
      barcodeFocusNode.requestFocus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mahsulot topilmadi!')));
    }
  }

  void _addProductToItems(Product p, {bool isBox = false}) {
    setState(() {
      final existingIdx = items.indexWhere((i) => i['productId'] == p.id);
      if (existingIdx >= 0) {
        items[existingIdx]['quantity'] = (items[existingIdx]['quantity'] ?? 0) + 1;
      } else {
        items.add({
          'productId': p.id,
          'productName': p.name,
          'quantity': 1.0,
          'costPrice': isBox ? (p.boxPrice ?? (p.costPrice * p.quantityInBox)) : p.costPrice,
          'price': isBox ? (p.boxPrice ?? (p.price * p.quantityInBox)) : p.price,
          'isBox': isBox,
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

  bool _isSaving = false;
  Future<void> _save() async {
    if (_isSaving) return;
    final inventory = context.read<InventoryProvider>();
    if (entryWarehouseId == null) return;
    final finalItems = <StockEntryItem>[];
    for (var i in items) {
      if (i['productId'] == null || i['quantity'] <= 0) continue;
      
      final product = inventory.activeProducts.firstWhere((p) => p.id == i['productId']);
      final bool isBox = i['isBox'] ?? false;
      double qty = (i['quantity'] as num).toDouble();
      double cost = (i['costPrice'] as num).toDouble();
      double price = (i['price'] as num).toDouble();
      
      if (isBox) {
        qty *= product.quantityInBox;
        // If the price entered was for a BOX, we should convert it to PIECE price
        // Usually in kirim entries, users enter price per unit they are buying.
        // If they chose "Blok" and entered price, it's likely price per block.
        if (product.quantityInBox > 1) {
          cost = double.parse((cost / product.quantityInBox).toStringAsFixed(2));
          price = double.parse((price / product.quantityInBox).toStringAsFixed(2));
        }
      }
      
      finalItems.add(StockEntryItem(
        productId: i['productId'], 
        productName: i['productName'], 
        quantity: qty, 
        costPrice: cost,
        price: price,
        isBox: isBox,
      ));
    }
    if (finalItems.isEmpty) return;

    setState(() => _isSaving = true);
    final entry = StockEntry(id: widget.entry?.id ?? const Uuid().v4(), warehouseId: entryWarehouseId!, date: selectedDate, description: descriptionCtrl.text, items: finalItems);
    try {
      await inventory.addStockEntry(entry);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xatolik: $e')));
      }
    }
  }

  void _showTemplateSelectionDialog(BuildContext context, InventoryProvider inventory) {
    List<Product> selectedProducts = [];
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filteredProducts = inventory.activeProducts.where((p) {
            return p.matchesSearch(searchQuery);
          }).toList();

          return AlertDialog(
            title: const Text('Shablon uchun mahsulotlarni tanlang'),
            content: SizedBox(
              width: 500,
              height: 600,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Nomi yoki shtrix kodi bilan izlash...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setDialogState(() => searchQuery = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            selectedProducts = List.from(inventory.activeProducts);
                          });
                        },
                        child: const Text('Hammasini tanlash'),
                      ),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            selectedProducts.clear();
                          });
                        },
                        child: const Text('Hammasini bekor qilish'),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final p = filteredProducts[index];
                        final isSelected = selectedProducts.any((sp) => sp.id == p.id);
                        return CheckboxListTile(
                          title: Text(p.name),
                          subtitle: Text(p.barcode),
                          value: isSelected,
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedProducts.add(p);
                              } else {
                                selectedProducts.removeWhere((sp) => sp.id == p.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Bekor qilish'),
              ),
              ElevatedButton(
                onPressed: selectedProducts.isEmpty 
                  ? null 
                  : () {
                      Navigator.pop(context);
                      ExcelImportService.downloadStockEntryTemplate(context, selectedProducts);
                    },
                child: Text('${selectedProducts.length} ta mahsulotni yuklash'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductDisplay(int idx, Map<String, dynamic> item, InventoryProvider inventory) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Mahsulot',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
          ),
          child: Text(
            item['productName'] ?? 'Nomsiz mahsulot',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactInput(dynamic initialValue, String label, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: initialValue is double ? AppFormatter.formatDouble(initialValue) : initialValue.toString(),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            filled: true,
            fillColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), width: 1.5),
            ),
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChanged,
        ),
      ],
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
