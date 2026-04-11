import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/features/inventory_provider.dart';
import '../../providers/features/settings_provider.dart';
import '../../providers/features/auth_provider.dart';
import '../../models/models.dart';
import '../../services/print_service.dart';
import '../widgets/app_status_bar.dart';

class BarcodePrintScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialItems;
  const BarcodePrintScreen({super.key, this.initialItems});

  @override
  State<BarcodePrintScreen> createState() => _BarcodePrintScreenState();
}

class _BarcodePrintScreenState extends State<BarcodePrintScreen> {
  final List<Map<String, dynamic>> selectedItems = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialItems != null) {
      selectedItems.addAll(widget.initialItems!);
    }
  }

  void _addItem(Product product) {
    setState(() {
      final existingIdx = selectedItems.indexWhere((i) => i['product'].id == product.id);
      if (existingIdx >= 0) {
        selectedItems[existingIdx]['quantity'] = (selectedItems[existingIdx]['quantity'] ?? 0) + 1;
      } else {
        selectedItems.add({
          'product': product,
          'quantity': 1,
        });
      }
    });
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      final newQty = (selectedItems[index]['quantity'] ?? 0) + delta;
      if (newQty > 0) {
        selectedItems[index]['quantity'] = newQty;
      } else {
        selectedItems.removeAt(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final settings = context.watch<SettingsProvider>();
    final query = _searchController.text.toLowerCase();
    
    final filteredProducts = inventory.activeProducts.where((p) {
      return p.name.toLowerCase().contains(query) || p.barcode.contains(query);
    }).toList();

    final auth = context.watch<AuthProvider>();

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
                title: const Text('Shtrix-kodlarni chop etish', 
                    style: TextStyle(fontWeight: FontWeight.bold)),
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
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Mahsulot qidirish...',
                                prefixIcon: const Icon(Icons.search_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Expanded(
                              child: ListView.builder(
                                itemCount: filteredProducts.length,
                                itemBuilder: (context, index) {
                                  final p = filteredProducts[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text(p.barcode),
                                      trailing: IconButton(
                                        icon: Icon(Icons.add_circle_outline_rounded, color: Theme.of(context).colorScheme.primary),
                                        onPressed: () => _addItem(p),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('Tanlangan mahsulotlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: selectedItems.isEmpty
                                  ? const Center(child: Text('Mahsulot tanlanmagan'))
                                  : ListView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      itemCount: selectedItems.length,
                                      itemBuilder: (context, index) {
                                        final item = selectedItems[index];
                                        final Product p = item['product'];
                                        final int qty = item['quantity'];
                                        return ListTile(
                                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Text(p.barcode),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => _updateQuantity(index, -1)),
                                              Text(qty.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                              IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _updateQuantity(index, 1)),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: ElevatedButton.icon(
                                onPressed: selectedItems.isEmpty
                                    ? null
                                    : () => PrintService.printBarcodeLabels(
                                          items: selectedItems,
                                          printerName: settings.barcodePrinterName,
                                          ipAddress: settings.networkBarcodePrinterIp,
                                        ),
                                icon: const Icon(Icons.print_rounded),
                                label: const Text('CHOP ETISH', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(60),
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
}
