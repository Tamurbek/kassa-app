import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/features/inventory_provider.dart';
import '../../providers/features/settings_provider.dart';
import '../../providers/features/auth_provider.dart';
import '../../models/models.dart';
import '../../services/print_service.dart';
import '../widgets/app_status_bar.dart';
import '../widgets/custom_app_bar.dart';
import '../../core/utils/formatter.dart';

class BarcodePrintScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialItems;
  const BarcodePrintScreen({super.key, this.initialItems});

  @override
  State<BarcodePrintScreen> createState() => _BarcodePrintScreenState();
}

class _BarcodePrintScreenState extends State<BarcodePrintScreen> {
  final List<Map<String, dynamic>> selectedItems = [];
  final TextEditingController _searchController = TextEditingController();
  bool isPriceMode = false;
  int paperWidth = 40;

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
      appBar: const CustomAppBar(
        title: 'Shtrix-kodlarni chop etish',
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
                                      subtitle: Text('${p.barcode} - ${AppFormatter.formatDouble(p.price)} so\'m'),
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
                                          subtitle: Text('${p.barcode} - ${AppFormatter.formatDouble(p.price)} so\'m'),
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
                               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                               child: Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                 decoration: BoxDecoration(
                                   color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                                   borderRadius: BorderRadius.circular(16),
                                   border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
                                 ),
                                 child: Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   children: [
                                     Row(
                                       children: [
                                         Icon(isPriceMode ? Icons.sell_rounded : Icons.qr_code_2_rounded, color: Theme.of(context).colorScheme.primary),
                                         const SizedBox(width: 12),
                                         Text(
                                           isPriceMode ? 'Nom va Narx rejimi' : 'Nom va Shtrix-kod rejimi',
                                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                         ),
                                       ],
                                     ),
                                     Switch.adaptive(
                                       value: isPriceMode,
                                       onChanged: (val) => setState(() => isPriceMode = val),
                                     ),
                                   ],
                                 ),
                               ),
                             ),
                             Padding(
                               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                               child: Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                 decoration: BoxDecoration(
                                   color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                                   borderRadius: BorderRadius.circular(16),
                                   border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
                                 ),
                                 child: Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   children: [
                                     const Row(
                                       children: [
                                         Icon(Icons.straighten_rounded, color: Colors.blue),
                                         SizedBox(width: 12),
                                         Text(
                                           'Qog\'oz kengligi',
                                           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                         ),
                                       ],
                                     ),
                                     DropdownButton<int>(
                                       value: paperWidth,
                                       underline: const SizedBox(),
                                       items: const [
                                         DropdownMenuItem(value: 40, child: Text('40 mm (Etiketka)')),
                                         DropdownMenuItem(value: 80, child: Text('80 mm (Chek)')),
                                       ],
                                       onChanged: (val) => setState(() => paperWidth = val ?? 40),
                                     ),
                                   ],
                                 ),
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
                                           isPriceLabel: isPriceMode,
                                           width: paperWidth,
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
