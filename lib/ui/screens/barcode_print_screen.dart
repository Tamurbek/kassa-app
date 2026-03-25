import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/models.dart';
import '../../services/print_service.dart';

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
    final state = context.watch<AppState>();
    final query = _searchController.text.toLowerCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final filteredProducts = state.activeProducts.where((p) {
      return p.name.toLowerCase().contains(query) || p.barcode.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Shtrix-kodlarni chop etish'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Row(
            children: [
              // Selection Side (Left)
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Theme.of(context).dividerColor.withOpacity(0.5)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Mahsulot qidirish...',
                            prefixIcon: Icon(Icons.search_rounded,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.7)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: filteredProducts.isEmpty
                            ? Center(
                                child: Text('Mahsulot topilmadi',
                                    style: TextStyle(color: Colors.grey.shade500)))
                            : ListView.builder(
                                itemCount: filteredProducts.length,
                                itemBuilder: (context, index) {
                                  final p = filteredProducts[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: Theme.of(context)
                                              .dividerColor
                                              .withOpacity(0.5)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withOpacity(isDark ? 0.2 : 0.03),
                                          blurRadius: 5,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      title: Text(p.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14)),
                                      subtitle: Text(p.barcode,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color)),
                                      trailing: IconButton(
                                        icon: Icon(Icons.add_circle_rounded,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary),
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
    
              // Cart/Print Side (Right)
              Expanded(
                flex: 2,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(0, 24, 24, 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Theme.of(context).dividerColor.withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Chop etish uchun tanlanganlar',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      Divider(height: 1, color: Theme.of(context).dividerColor),
                      Expanded(
                        child: selectedItems.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.qr_code_scanner_rounded,
                                        size: 80,
                                        color: Theme.of(context)
                                            .dividerColor
                                            .withOpacity(0.5)),
                                    const SizedBox(height: 24),
                                    Text('Hozircha mahsulot tanlanmagan',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color
                                              ?.withOpacity(0.5),
                                          fontSize: 16,
                                        )),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                itemCount: selectedItems.length,
                                separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: Theme.of(context)
                                        .dividerColor
                                        .withOpacity(0.5)),
                                itemBuilder: (context, index) {
                                  final item = selectedItems[index];
                                  final Product p = item['product'];
                                  final int qty = item['quantity'];
    
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(p.name,
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16)),
                                              const SizedBox(height: 4),
                                              Text(p.barcode,
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      color: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.color)),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .scaffoldBackgroundColor,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              _buildQtyBtn(
                                                icon: Icons.remove_rounded,
                                                onTap: () => _updateQuantity(index, -1),
                                                color: Colors.red.withOpacity(0.1),
                                                iconColor: Colors.redAccent,
                                              ),
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                width: 50,
                                                child: Text(
                                                  qty.toString(),
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 18),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              _buildQtyBtn(
                                                icon: Icons.add_rounded,
                                                onTap: () => _updateQuantity(index, 1),
                                                color: Colors.green.withOpacity(0.1),
                                                iconColor: Colors.green,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: selectedItems.isEmpty
                                ? null
                                : () => PrintService.printBarcodeLabels(
                                      items: selectedItems,
                                      printerName: state.barcodePrinterName,
                                      ipAddress: state.networkBarcodePrinterIp,
                                    ),
                            icon: const Icon(Icons.print_rounded, size: 24),
                            label: const Text('BARCHASINI CHOP ETISH'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(64),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 0.5,
                              ),
                            ),
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
    );
  }

  Widget _buildQtyBtn({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required Color iconColor,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ),
    );
  }
}
