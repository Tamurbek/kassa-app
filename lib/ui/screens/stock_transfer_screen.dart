import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/features/inventory_provider.dart';
import '../../providers/features/auth_provider.dart';
import '../../providers/features/settings_provider.dart';
import '../widgets/app_status_bar.dart';
import '../../providers/app_state.dart';

class StockTransferScreen extends StatefulWidget {
  final StockTransfer? transfer;
  const StockTransferScreen({super.key, this.transfer});

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
    final inventory = context.read<InventoryProvider>();
    
    if (widget.transfer != null) {
      fromWarehouseId = widget.transfer!.fromWarehouseId;
      toWarehouseId = widget.transfer!.toWarehouseId;
      descriptionCtrl.text = widget.transfer!.description;
      selectedDate = widget.transfer!.date;
      for (var item in widget.transfer!.items) {
        items.add({
          'productId': item.productId,
          'productName': item.productName,
          'quantity': item.quantity,
        });
      }
    } else {
      fromWarehouseId = inventory.mainWarehouse?.id;
      if (inventory.warehouses.length > 1) {
        toWarehouseId = inventory.warehouses.firstWhere((w) => w.id != fromWarehouseId).id;
      }
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
                title: Text(widget.transfer == null ? 'Omborlararo Ko\'chirish' : 'O\'tkazmani Tahrirlash', 
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.transparent,
                elevation: 0,
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
                constraints: const BoxConstraints(maxWidth: 1400),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 900;
                    
                    if (isWide) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column: Configuration & Barcode
                            Expanded(
                              flex: 5,
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildConfigSection(inventory),
                                    const SizedBox(height: 24),
                                    _buildBarcodeSection(inventory),
                                    const SizedBox(height: 48),
                                    _buildConfirmButton(),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 40),
                            // Right Column: Products List
                            Expanded(
                              flex: 7,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Mahsulotlar ro\'yxati', 
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: _buildItemsList(inventory),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildAddRowButton(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
          
                    // Mobile/Small Screen Layout
                    return ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        _buildConfigSection(inventory),
                        const SizedBox(height: 24),
                        _buildBarcodeSection(inventory),
                        const SizedBox(height: 32),
                        const Text('Mahsulotlar ro\'yxati', 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 16),
                        ..._buildItemsListItems(inventory),
                        const SizedBox(height: 16),
                        _buildAddRowButton(),
                        const SizedBox(height: 48),
                        _buildConfirmButton(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          AppStatusBar(
            settings: settingsProv,
            auth: auth,
            onExit: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigSection(InventoryProvider inventory) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: fromWarehouseId,
                  decoration: const InputDecoration(
                    labelText: 'Qaysi ombordan', 
                    border: OutlineInputBorder(), 
                    prefixIcon: Icon(Icons.outbox_rounded, color: Colors.red)
                  ),
                  items: inventory.warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                  onChanged: (val) => setState(() => fromWarehouseId = val),
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.swap_horiz_rounded, color: Colors.grey)),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: toWarehouseId,
                  decoration: const InputDecoration(
                    labelText: 'Qaysi omborga', 
                    border: OutlineInputBorder(), 
                    prefixIcon: Icon(Icons.inbox_rounded, color: Colors.green)
                  ),
                  items: inventory.warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
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
              prefixIcon: Icon(Icons.description_outlined)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeSection(InventoryProvider inventory) {
    return TextField(
      controller: barcodeCtrl,
      focusNode: barcodeFocusNode,
      decoration: InputDecoration(
        labelText: 'Shtrix kod orqali qo\'shish',
        hintText: 'Shtrix kodni skanerlang...',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
        filled: true,
        fillColor: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        suffixIcon: IconButton(
          icon: const Icon(Icons.add), 
          onPressed: () => _handleBarcode(barcodeCtrl.text, inventory)
        ),
      ),
      onSubmitted: (val) => _handleBarcode(val, inventory),
    );
  }

  Widget _buildItemsList(InventoryProvider inventory) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text('Hali mahsulot qo\'shilmadi', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView(
      children: _buildItemsListItems(inventory),
    );
  }

  List<Widget> _buildItemsListItems(InventoryProvider inventory) {
    return items.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: DropdownButtonFormField<String>(
                  value: item['productId'],
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: InputBorder.none, 
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    hintText: 'Mahsulotni tanlang'
                  ),
                  items: inventory.activeProducts.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    final p = inventory.activeProducts.firstWhere((p) => p.id == val);
                    setState(() {
                      items[idx]['productId'] = val;
                      items[idx]['productName'] = p.name;
                    });
                  },
                ),
              ),
              Container(width: 1, height: 24, color: Theme.of(context).dividerColor),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextFormField(
                  initialValue: item['quantity'] == 0 ? '' : item['quantity'].toString(),
                  decoration: const InputDecoration(
                    hintText: 'Soni', 
                    border: InputBorder.none, 
                    contentPadding: EdgeInsets.symmetric(horizontal: 12)
                  ),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  onChanged: (val) => items[idx]['quantity'] = double.tryParse(val) ?? 0,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red), 
                onPressed: () => setState(() => items.removeAt(idx))
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildAddRowButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => setState(() => items.add({'productId': null, 'productName': '', 'quantity': 0.0})), 
        icon: const Icon(Icons.add_rounded), 
        label: const Text('Qator qo\'shish'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary, 
          foregroundColor: Colors.white, 
          elevation: 4,
          shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
        ),
        child: const Text('KO\'CHIRISHNI TASDIQLASH', 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
      ),
    );
  }

  void _handleBarcode(String barcode, InventoryProvider inventory) {
    if (barcode.isEmpty) return;
    try {
      final product = inventory.activeProducts.firstWhere((p) => p.barcode == barcode || p.additionalBarcodes.contains(barcode));
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

  Future<void> _save() async {
    final inventory = context.read<InventoryProvider>();
    if (fromWarehouseId == null || toWarehouseId == null) return;
    if (fromWarehouseId == toWarehouseId) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bir xil omborga ko\'chirib bo\'lmaydi!'), backgroundColor: Colors.orange));
       return;
    }

    final finalItems = items.where((i) => i['productId'] != null && (i['quantity'] as num) > 0).map((i) => StockTransferItem(productId: i['productId'], productName: i['productName'], quantity: (i['quantity'] as num).toDouble())).toList();
    if (finalItems.isEmpty) return;

    final transfer = StockTransfer(
      id: widget.transfer?.id ?? const Uuid().v4(),
      fromWarehouseId: fromWarehouseId!,
      toWarehouseId: toWarehouseId!,
      date: selectedDate,
      description: descriptionCtrl.text,
      items: finalItems,
    );

    try {
      final appState = context.read<AppState>();
      await inventory.saveStockTransfer(transfer);
      await appState.reloadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mahsulotlar muvaffaqiyatli ko\'chirildi'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xatolik: $e')));
    }
  }
}
