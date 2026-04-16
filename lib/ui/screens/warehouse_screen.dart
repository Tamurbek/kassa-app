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
import '../../core/utils/responsive.dart';
import '../../providers/features/navigation_provider.dart';
import '../../core/utils/formatter.dart';

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
      length: 7,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 800;
          final bool isShort = constraints.maxHeight < 700;
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Column(
              children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: Column(
                        children: [
                          _buildHeader(inventory, constraints.maxWidth, constraints.maxHeight),
                          TabBar(
                            isScrollable: true,
                            labelColor: Theme.of(context).colorScheme.primary,
                            unselectedLabelColor: Colors.grey.shade400,
                            indicatorColor: Theme.of(context).colorScheme.primary,
                            indicatorWeight: 3.h,
                            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                            tabs: const [
                              Tab(text: 'Statistika'),
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
                                // TAB 0: Statistics Dashboard
                                Padding(
                                  padding: EdgeInsets.all(Responsive.isShort(context) ? 12.sp : 24.sp),
                                  child: SingleChildScrollView(
                                    child: _buildStatsRow(inventory, constraints.maxWidth),
                                  ),
                                ),
                                
                                // TAB 1: Detailed Product Balances
                                Padding(
                                  padding: EdgeInsets.all(Responsive.isShort(context) ? 12.sp : 24.sp),
                                  child: Column(
                                    children: [
                                      _buildBalancesControlRow(inventory),
                                      const SizedBox(height: 16),
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalancesControlRow(InventoryProvider inventory) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Mahsulot qidirish...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 16),
        _buildWarehouseSelector(inventory),
      ],
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

  Widget _buildHeader(InventoryProvider inventory, double width, double height) {
    final bool isShort = height < 700;
    final bool showLabels = width > 900;
    final bool isNarrow = width < 850;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.sp, vertical: isShort ? 12.h : 20.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          if (Navigator.canPop(context)) ...[
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
          ] else ...[
            IconButton(
              onPressed: () => context.read<NavigationProvider>().openSessions(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
          ],
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
            child: Icon(Icons.inventory_2_rounded, color: Colors.white, size: isShort ? 22.sp : 28.sp),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ombor Boshqaruvi',
                  style: TextStyle(
                    fontSize: isShort ? 20.sp : 28.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                   'Tizim faol: ${DateFormat('HH:mm').format(DateTime.now())}',
                   style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (!isNarrow) ...[
            _buildModernAction(
              icon: Icons.add_rounded,
              label: showLabels ? 'Kirim' : null,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const StockEntryScreen())),
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            _buildModernAction(
              icon: Icons.swap_horiz_rounded,
              label: showLabels ? 'O\'tkazma' : null,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const StockTransferScreen())),
              color: Colors.indigo,
            ),
            const SizedBox(width: 8),
            _buildModernAction(
              icon: Icons.undo_rounded,
              label: showLabels ? 'Vazvrat' : null,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ReturnScreen())),
              color: Colors.orange,
            ),
            const SizedBox(width: 8),
            _buildModernAction(
              icon: Icons.remove_circle_rounded,
              label: showLabels ? 'Chiqit' : null,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const WriteOffScreen())),
              color: Colors.red,
            ),
            const SizedBox(width: 8),
            _buildModernAction(
              icon: Icons.fact_check_rounded,
              label: showLabels ? 'Inventar' : null,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const InventoryScreen())),
              color: Colors.teal,
            ),
            const SizedBox(width: 8),
            _buildModernAction(
              icon: Icons.qr_code_2_rounded,
              label: showLabels ? 'Printer' : null,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const BarcodePrintScreen())),
              color: Colors.blueGrey,
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: Theme.of(context).colorScheme.primary),
              onPressed: () => inventory.reloadData(),
            ),
          ],
          IconButton(
            icon: Icon(Icons.menu_rounded, color: Theme.of(context).colorScheme.primary),
            onPressed: widget.onMenuPressed,
            tooltip: 'Menyu',
          ),
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
    final bool isShort = Responsive.isShort(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.sp, vertical: isShort ? 6.h : 10.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: isShort ? 16.sp : 20.sp),
            if (label != null) ...[
              SizedBox(width: 8.w),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13.sp),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(InventoryProvider inventory, double width) {
    final bool isShort = Responsive.isShort(context);
    final totalProducts = inventory.activeProducts.length;
    final lowStockCount = inventory.activeProducts.where((p) {
      final stock = p.stocks[selectedWarehouseId] ?? 0;
      return stock <= 5;
    }).length;

    double totalSaleValue = 0;
    double totalCostValue = 0;
    for (var p in inventory.activeProducts) {
      final stock = p.stocks[selectedWarehouseId] ?? 0;
      totalSaleValue += (stock * p.price);
      totalCostValue += (stock * p.costPrice);
    }

    int crossAxisCount = width < 600 ? 1 : width < 1200 ? 3 : 5;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16.sp,
      mainAxisSpacing: 16.h,
      childAspectRatio: width < 600 ? 3.5 : (isShort ? 3.0 : 2.2),
      children: [
        _buildStatCard('Jami Mahsulotlar', totalProducts.toString(), Icons.inventory_2_rounded, Colors.indigo),
        _buildStatCard('Kam qolganlar', lowStockCount.toString(), Icons.warning_amber_rounded, Colors.orange),
        _buildStatCard('Sotuv qiymati', '${NumberFormat.compact(locale: 'uz_UZ').format(totalSaleValue)} so\'m', Icons.payments_rounded, Colors.green),
        _buildStatCard('Tan narxi qiymati', '${NumberFormat.compact(locale: 'uz_UZ').format(totalCostValue)} so\'m', Icons.account_balance_wallet_rounded, Colors.teal),
        _buildStatCard('Kirimlar (Bugun)', inventory.stockEntries.where((e) => e.date.day == DateTime.now().day).length.toString(), Icons.add_circle_outline_rounded, Colors.blue),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    final bool isShort = Responsive.isShort(context);
    return Container(
      padding: EdgeInsets.all(isShort ? 12.sp : 24.sp),
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
      padding: EdgeInsets.all(Responsive.isShort(context) ? 12.sp : 24.sp),
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
            '${AppFormatter.formatDouble(stock)} ${product.unit}',
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
      (entry) => 'Kirim #${entry.id.length > 8 ? entry.id.substring(0, 8) : entry.id}',
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
      (entry) => 'O\'tkazma #${entry.id.length > 8 ? entry.id.substring(0, 8) : entry.id}',
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
      (entry) => 'Vazvrat #${entry.id.length > 8 ? entry.id.substring(0, 8) : entry.id}',
      (entry) => 'Sotuv #${entry.saleId.length > 8 ? entry.saleId.substring(0, 8) : entry.saleId}',
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
      (entry) => 'Chiqit #${entry.id.length > 8 ? entry.id.substring(0, 8) : entry.id}',
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
      (entry) => 'Inventar #${entry.id.length > 8 ? entry.id.substring(0, 8) : entry.id}',
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
