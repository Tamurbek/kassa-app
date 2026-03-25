import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../providers/features/inventory_provider.dart';
import '../../providers/features/sales_provider.dart';
import '../../models/models.dart';
import 'stock_entry_screen.dart';
import 'return_screen.dart';
import 'write_off_screen.dart';
import 'inventory_screen.dart';
import 'barcode_print_screen.dart';
import 'stock_transfer_screen.dart';

class WarehouseScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  const WarehouseScreen({super.key, this.onMenuPressed});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  String? selectedWarehouseId;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final inventory = context.read<InventoryProvider>();
    if (inventory.warehouses.isNotEmpty) {
      selectedWarehouseId = inventory.mainWarehouse?.id;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final sales = context.watch<SalesProvider>();
    final searchQuery = _searchController.text.toLowerCase();
    
    if (selectedWarehouseId == null && inventory.warehouses.isNotEmpty) {
      selectedWarehouseId = inventory.mainWarehouse?.id;
    }

    final filteredProducts = inventory.activeProducts.where((p) {
      final matchesSearch =
          p.name.toLowerCase().contains(searchQuery) ||
          p.barcode.contains(searchQuery);
      return matchesSearch;
    }).toList();

    return DefaultTabController(
      length: 6,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 800;
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(
                  children: [
                    _buildHeader(inventory, isNarrow),
                    TabBar(
                      isScrollable: true,
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor: Colors.grey.shade400,
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      tabs: const [
                        Tab(text: 'Qoldiqlar'),
                        Tab(text: 'Kirimlar'),
                        Tab(text: 'O\'tkazmalar'),
                        Tab(text: 'Vazvratlar'),
                        Tab(text: 'Hisobdan chiqarish'),
                        Tab(text: 'Inventarizatsiya'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // TAB 1: Current Stock
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                _buildStatsRow(inventory, constraints.maxWidth),
                                const SizedBox(height: 24),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Theme.of(context).dividerColor,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Mahsulotlar Qoldig\'i',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              _buildWarehouseSelector(inventory),
                                            ],
                                          ),
                                        ),
                                        const Divider(height: 1),
                                        Expanded(
                                          child: filteredProducts.isEmpty
                                              ? _buildEmptySearch()
                                              : _buildProductsList(
                                                  inventory,
                                                  filteredProducts,
                                                  isNarrow,
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildHistoryList(inventory),
                          _buildTransferList(inventory),
                          _buildReturnsList(sales, inventory),
                          _buildWriteOffsList(sales),
                          _buildInventoriesList(inventory),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWarehouseSelector(InventoryProvider inventory) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
      ),
      child: DropdownButton<String>(
        value: selectedWarehouseId,
        underline: const SizedBox(),
        hint: const Text('Omborni tanlang'),
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).colorScheme.primary),
        items: inventory.warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
        onChanged: (val) => setState(() => selectedWarehouseId = val),
      ),
    );
  }

  Widget _buildHeader(InventoryProvider inventory, bool isNarrow) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ombor Boshqaruvi',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                   'Tizim faol: ${DateFormat('HH:mm').format(DateTime.now())}',
                   style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (!isNarrow) ...[
            _buildModernAction(
              icon: Icons.add_rounded,
              label: 'Kirim',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const StockEntryScreen())),
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            _buildModernAction(
              icon: Icons.swap_horiz_rounded,
              label: 'O\'tkazma',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const StockTransferScreen())),
              color: Colors.indigo,
            ),
            const SizedBox(width: 8),
            _buildModernAction(
              icon: Icons.undo_rounded,
              label: 'Vazvrat',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ReturnScreen())),
              color: Colors.orange,
            ),
            const SizedBox(width: 8),
            _buildModernAction(
              icon: Icons.remove_circle_rounded,
              label: 'Chiqit',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const WriteOffScreen())),
              color: Colors.red,
            ),
            const SizedBox(width: 8),
            _buildModernAction(
              icon: Icons.fact_check_rounded,
              label: 'Inventar',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const InventoryScreen())),
              color: Colors.teal,
            ),
            const SizedBox(width: 8),
            _buildModernAction(
              icon: Icons.qr_code_2_rounded,
              label: 'Printer',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const BarcodePrintScreen())),
              color: Colors.blueGrey,
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: Theme.of(context).colorScheme.primary),
              onPressed: () => inventory.reloadData(),
            ),
            if (widget.onMenuPressed != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.menu_rounded, color: Theme.of(context).colorScheme.primary),
                onPressed: widget.onMenuPressed,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildModernAction({
    required IconData icon,
    String? label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            if (label != null) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(InventoryProvider inventory, double width) {
    final totalProducts = inventory.activeProducts.length;
    final lowStockCount = inventory.activeProducts.where((p) {
      final stock = p.stocks[selectedWarehouseId] ?? 0;
      return stock <= 5;
    }).length;

    double totalSaleValue = 0;
    for (var p in inventory.activeProducts) {
      final stock = p.stocks[selectedWarehouseId] ?? 0;
      totalSaleValue += (stock * p.price);
    }

    int crossAxisCount = width < 600 ? 1 : width < 1200 ? 2 : 4;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 24,
      mainAxisSpacing: 24,
      childAspectRatio: 3,
      children: [
        _buildStatCard('Jami Mahsulotlar', totalProducts.toString(), Icons.inventory_2_rounded, Colors.indigo),
        _buildStatCard('Kam qolganlar', lowStockCount.toString(), Icons.warning_amber_rounded, Colors.orange),
        _buildStatCard('Zaxira qiymati', '${NumberFormat.compact(locale: 'uz_UZ').format(totalSaleValue)} so\'m', Icons.payments_rounded, Colors.green),
        _buildStatCard('Kirimlar (Bugun)', inventory.stockEntries.length.toString(), Icons.add_circle_outline_rounded, Colors.blue),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList(InventoryProvider inventory, List<Product> products, bool isNarrow) {
     return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: products.length,
      separatorBuilder: (c, i) => const Divider(),
      itemBuilder: (c, i) {
        final product = products[i];
        final stock = product.stocks[selectedWarehouseId] ?? 0;
        final isLow = stock <= 5;
        return ListTile(
          leading: Icon(Icons.shopping_bag_outlined, color: isLow ? Colors.orange : Colors.grey),
          title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(product.barcode),
          trailing: Text(
            '${stock.toStringAsFixed(0)} ${product.unit}',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: isLow ? Colors.orange : Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      },
     );
  }

  Widget _buildEmptySearch() => const Center(child: Text('Mahsulot topilmadi'));

  Widget _buildHistoryList(InventoryProvider inventory) {
    return _buildMovementList(
      'Kirim',
      inventory.stockEntries.cast<dynamic>(),
      inventory,
      (entry) => 'Kirim #${entry.id.substring(0, 8)}',
      (entry) => entry.date.toString().substring(0, 16),
      Colors.blue,
      (entry) => inventory.deleteStockEntry(entry.id),
      (entry) { Navigator.push(context, MaterialPageRoute(builder: (_) => StockEntryScreen(entry: entry))); },
    );
  }

  Widget _buildTransferList(InventoryProvider inventory) {
    return _buildMovementList(
      'O\'tkazma',
      inventory.transfers.cast<dynamic>(),
      inventory,
      (entry) => 'O\'tkazma #${entry.id.substring(0, 8)}',
      (entry) => '${entry.fromWarehouseId} -> ${entry.toWarehouseId}',
      Colors.indigo,
      (entry) => inventory.deleteStockTransfer(entry.id),
      (entry) { Navigator.push(context, MaterialPageRoute(builder: (_) => StockTransferScreen(transfer: entry))); },
    );
  }

  Widget _buildReturnsList(SalesProvider sales, InventoryProvider inventory) {
    return _buildMovementList(
      'Vazvrat',
      sales.returns.cast<dynamic>(),
      inventory,
      (entry) => 'Vazvrat #${entry.id.substring(0, 8)}',
      (entry) => 'Sotuv #${entry.saleId.substring(0, 8)}',
      Colors.orange,
      (entry) => sales.deleteReturn(entry.id),
      (entry) { Navigator.push(context, MaterialPageRoute(builder: (_) => ReturnScreen(saleReturn: entry))); },
    );
  }

  Widget _buildWriteOffsList(SalesProvider sales) {
    return _buildMovementList(
      'Chiqit',
      sales.writeOffs.cast<dynamic>(),
      null,
      (entry) => 'Chiqit #${entry.id.substring(0, 8)}',
      (entry) => entry.date.toString().substring(0, 16),
      Colors.red,
      (entry) => sales.deleteWriteOff(entry.id),
      (entry) { Navigator.push(context, MaterialPageRoute(builder: (_) => WriteOffScreen(writeOff: entry))); },
    );
  }

  Widget _buildInventoriesList(InventoryProvider inventory) {
    return _buildMovementList(
      'Inventar',
      inventory.inventories.cast<dynamic>(),
      inventory,
      (entry) => 'Inventar #${entry.id.substring(0, 8)}',
      (entry) => entry.date.toString().substring(0, 16),
      Colors.teal,
      (entry) => inventory.deleteInventory(entry.id),
      (entry) { Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryScreen(inventory: entry))); },
    );
  }

  Widget _buildMovementList(
    String type,
    List<dynamic> list,
    InventoryProvider? inventory,
    String Function(dynamic) title,
    String Function(dynamic) subtitle,
    Color color,
    Future<void> Function(dynamic) onDelete,
    void Function(dynamic) onEdit,
  ) {
    if (list.isEmpty) return Center(child: Text('$type ma\'lumotlari mavjud emas'));
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final entry = list[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(Icons.history, color: color, size: 20)),
            title: Text(title(entry), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(subtitle(entry)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit_rounded, size: 20), onPressed: () => onEdit(entry)),
                IconButton(icon: const Icon(Icons.delete_rounded, color: Colors.grey, size: 20), onPressed: () => _confirmDelete(context, 'O\'chirishni tasdiqlaysizmi?', () => onDelete(entry))),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String message, Future<void> Function() action) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tasdiqlash'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await action();
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
  }
}
