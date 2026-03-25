import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../../providers/app_state.dart';
import '../../models/models.dart';
import 'stock_entry_screen.dart';
import 'return_screen.dart';
import 'write_off_screen.dart';
import 'inventory_screen.dart';
import 'barcode_print_screen.dart';
import 'stock_transfer_screen.dart';
import '../../services/print_service.dart';

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
    final state = context.read<AppState>();
    if (state.warehouses.isNotEmpty) {
      selectedWarehouseId = state.mainWarehouse?.id;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final searchQuery = _searchController.text.toLowerCase();
    
    // Auto-select if currently null
    if (selectedWarehouseId == null && state.warehouses.isNotEmpty) {
      selectedWarehouseId = state.mainWarehouse?.id;
    }

    final filteredProducts = state.activeProducts.where((p) {
      final matchesSearch =
          p.name.toLowerCase().contains(searchQuery) ||
          p.barcode.contains(searchQuery);
      return matchesSearch;
    }).toList();

    return DefaultTabController(
      length: 5,
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
                    _buildHeader(state, isNarrow),
                    TabBar(
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor: Colors.grey.shade400,
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      tabs: [
                        Tab(text: 'Qoldiqlar'),
                        Tab(text: 'Kirimlar'),
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
                                _buildStatsRow(state, constraints.maxWidth),
                                SizedBox(height: 24),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Theme.of(context).dividerColor,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 15,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Mahsulotlar Qoldig\'i',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              _buildWarehouseSelector(state),
                                            ],
                                          ),
                                        ),
                                        const Divider(height: 1),
                                        Expanded(
                                          child: filteredProducts.isEmpty
                                              ? _buildEmptySearch()
                                              : _buildProductsList(
                                                  state,
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
                          // TAB 2: Stock History (Inputs)
                          _buildHistoryList(state),
                          // TAB 3: Returns History
                          _buildReturnsList(state),
                          // TAB 4: Write-offs History
                          _buildWriteOffsList(state),
                          // TAB 5: Inventory History
                          _buildInventoriesList(state),
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

  Widget _buildWarehouseSelector(AppState state) {
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
        items: state.warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
        onChanged: (val) => setState(() => selectedWarehouseId = val),
      ),
    );
  }

  Widget _buildHeader(AppState state, bool isNarrow) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        children: [
          Row(
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
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tizim faol: ${DateFormat('HH:mm').format(DateTime.now())}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                          ),
                        ),
                      ],
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
                  icon: Icons.swap_horiz_rounded,
                  label: 'O\'tkazma',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const StockTransferScreen())),
                  color: Colors.indigo,
                ),
                const SizedBox(width: 8),
                _buildModernAction(
                  icon: Icons.qr_code_2_rounded,
                  label: 'Shtrix-kod',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const BarcodePrintScreen())),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                _buildModernAction(
                  icon: Icons.refresh_rounded,
                  onTap: () => state.reloadData(),
                  color: Theme.of(context).dividerColor.withOpacity(0.05),
                  iconColor: Theme.of(context).colorScheme.primary,
                ),
                if (widget.onMenuPressed != null) ...[
                  const SizedBox(width: 8),
                  _buildModernAction(
                    icon: Icons.menu_rounded,
                    onTap: widget.onMenuPressed!,
                    color: Theme.of(context).dividerColor.withOpacity(0.05),
                    iconColor: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ],
            ],
          ),
          if (isNarrow) ...[
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildModernAction(
                    icon: Icons.add_rounded,
                    label: 'Kirim',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const StockEntryScreen())),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  _buildModernAction(
                    icon: Icons.undo_rounded,
                    label: 'Vazvrat',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ReturnScreen())),
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  _buildModernAction(
                    icon: Icons.remove_circle_rounded,
                    label: 'Chiqarish',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const WriteOffScreen())),
                    color: Colors.red,
                  ),
                ],
              ),
            ),
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
    Color? iconColor,
  }) {
    final bool isDark = color.computeLuminance() < 0.5;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: label != null ? 18 : 14, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isDark ? [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor ?? (isDark ? Colors.white : Theme.of(context).colorScheme.onSurface), size: 22),
            if (label != null) ...[
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(AppState state, double width) {
    final totalProducts = state.activeProducts.length;
    final lowStockCount = state.activeProducts.where((p) {
      final stock = p.stocks[selectedWarehouseId] ?? 0;
      return stock <= 5;
    }).length;

    double totalSaleValue = 0;
    double totalCostValue = 0;

    for (var p in state.activeProducts) {
      final stock = p.stocks[selectedWarehouseId] ?? 0;
      if (stock > 0) {
        totalSaleValue += (stock * p.price);
        totalCostValue += (stock * (p.costPrice));
      }
    }

    int crossAxisCount = width < 600 ? 1 : width < 1200 ? 2 : 4;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 24,
      mainAxisSpacing: 24,
      childAspectRatio: 2.2,
      children: [
        _buildStatCard(
          'Jami Mahsulotlar',
          totalProducts.toString(),
          Icons.inventory_2_rounded,
          const [Color(0xFF6366F1), Color(0xFF4338CA)],
        ),
        _buildStatCard(
          'Kam qolganlar',
          lowStockCount.toString(),
          Icons.warning_amber_rounded,
          const [Color(0xFFF59E0B), Color(0xFFD97706)],
        ),
        _buildStatCard(
          'Zaxira (Sotuv)',
          '${NumberFormat.compact(locale: 'uz_UZ').format(totalSaleValue)} so\'m',
          Icons.payments_rounded,
          const [Color(0xFF10B981), Color(0xFF059669)],
          subtitle: 'Sotuv narxi bo\'yicha',
        ),
        _buildStatCard(
          'Zaxira (Tannarx)',
          '${NumberFormat.compact(locale: 'uz_UZ').format(totalCostValue)} so\'m',
          Icons.account_balance_rounded,
          const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          subtitle: 'Tannarx bo\'yicha',
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, List<Color> gradient, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.9), size: 24),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList(AppState state, List<Product> products, bool isNarrow) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: products.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = products[index];
        final stock = product.stocks[selectedWarehouseId] ?? 0;
        final isLow = stock <= 5;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: product.imagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(product.imagePath!), fit: BoxFit.cover),
                    )
                  : Icon(Icons.shopping_bag_outlined, color: Theme.of(context).colorScheme.primary),
            ),
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            subtitle: Text(
              product.barcode,
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLow ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${stock.toStringAsFixed(0)} ${product.unit}',
                    style: TextStyle(
                      color: isLow ? Colors.red : Colors.green[700],
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(product.price)} so\'m',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptySearch() => Center(
    child: Text('Mahsulot topilmadi', style: TextStyle(color: Colors.grey)),
  );

  Widget _buildHistoryList(AppState state) {
    if (state.stockEntries.isEmpty) {
      return Center(
        child: Text(
          'Kirim hujjatlari mavjud emas',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: state.stockEntries.length,
      itemBuilder: (context, index) {
        final entry = state.stockEntries[index];
        final warehouse = state.warehouses.firstWhere(
          (w) => w.id == entry.warehouseId,
          orElse: () => Warehouse(id: '', name: 'Noma\'lum'),
        );

        return _buildLogCard(
          'Kirim #${entry.id.substring(0, 8)}',
          '${warehouse.name} • ${entry.date.toString().substring(0, 16)}',
          entry.items.length.toString(),
          Theme.of(context).colorScheme.primary,
          [
            if (entry.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      entry.description,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            const Divider(),
            ...entry.items.map(
              (item) => ListTile(
                title: Text(item.productName),
                trailing: Text(
                  '+${item.quantity}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
          ],
          onDelete: () => _confirmDelete(
            context,
            'Kirimni bekor qilmoqchimisiz?',
            () => state.deleteStockEntry(entry.id),
          ),
          onEdit: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => StockEntryScreen(entry: entry)),
          ),
        );
      },
    );
  }

  Widget _buildReturnsList(AppState state) {
    if (state.returns.isEmpty) {
      return Center(
        child: Text(
          'Vazvratlar mavjud emas',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: state.returns.length,
      itemBuilder: (context, index) {
        final ret = state.returns[index];
        return _buildLogCard(
          'Vazvrat #${ret.id.substring(0, 8)}',
          'Sotuv #${ret.saleId.substring(0, 8)} • ${ret.date.toString().substring(0, 16)}',
          ret.items.length.toString(),
          Colors.orange,
          ret.items
              .map(
                (i) => ListTile(
                  title: Text(i.productName),
                  trailing: Text('${i.quantity} x ${i.price}'),
                ),
              )
              .toList(),
          onDelete: () => _confirmDelete(
            context,
            'Vazvratni bekor qilmoqchimisiz?',
            () => state.deleteReturn(ret.id),
          ),
          onEdit: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ReturnScreen(saleReturn: ret)),
          ),
        );
      },
    );
  }

  Widget _buildWriteOffsList(AppState state) {
    if (state.writeOffs.isEmpty) {
      return Center(
        child: Text(
          'Hisobdan chiqarishlar mavjud emas',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: state.writeOffs.length,
      itemBuilder: (context, index) {
        final wo = state.writeOffs[index];
        return _buildLogCard(
          'Hisobdan chiqarish #${wo.id.substring(0, 8)}',
          wo.date.toString().substring(0, 16),
          wo.items.length.toString(),
          Colors.redAccent,
          wo.items
              .map(
                (i) => ListTile(
                  title: Text(i.productName),
                  trailing: Text('-${i.quantity}'),
                ),
              )
              .toList(),
          onDelete: () => _confirmDelete(
            context,
            'Hisobdan chiqarishni bekor qilmoqchimisiz?',
            () => state.deleteWriteOff(wo.id),
          ),
          onEdit: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => WriteOffScreen(writeOff: wo)),
          ),
        );
      },
    );
  }

  Widget _buildInventoriesList(AppState state) {
    if (state.inventories.isEmpty) {
      return Center(
        child: Text(
          'Inventarizatsiyalar mavjud emas',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: state.inventories.length,
      itemBuilder: (context, index) {
        final inv = state.inventories[index];
        return _buildLogCard(
          'Inventarizatsiya #${inv.id.substring(0, 8)}',
          inv.date.toString().substring(0, 16),
          inv.items.length.toString(),
          Colors.teal,
          inv.items
              .map(
                (i) => ListTile(
                  title: Text(i.productName),
                  subtitle: Text('Kutilgan: ${i.expectedQuantity}'),
                  trailing: Text(
                    'Haqiqiy: ${i.actualQuantity}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              )
              .toList(),
          onDelete: () => _confirmDelete(
            context,
            'Inventarizatsiyani bekor qilmoqchimisiz?',
            () => state.deleteInventory(inv.id),
          ),
          onEdit: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => InventoryScreen(inventory: inv)),
          ),
        );
      },
    );
  }

  Widget _buildLogCard(
    String title,
    String subtitle,
    String count,
    Color color,
    List<Widget> items, {
    VoidCallback? onDelete,
    VoidCallback? onEdit,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.02,
            ),
            blurRadius: 10,
          ),
        ],
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(Icons.description, color: color, size: 20),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count ta tur',
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(width: 8),
            if (onEdit != null)
              IconButton(
                icon: Icon(Icons.edit_note_rounded, color: Colors.blue.shade700, size: 22),
                onPressed: onEdit,
                tooltip: 'Tahrirlash',
              ),
            if (onDelete != null)
              IconButton(
                icon: Icon(Icons.delete_sweep_rounded, color: Colors.red.shade400, size: 22),
                onPressed: onDelete,
                tooltip: 'O\'chirish',
              ),
          ],
        ),
        children: items,
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    String message,
    Future<void> Function() action,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tasdiqlash'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Yo\'q'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await action();
              if (mounted) Navigator.pop(context);
            },
            child: Text('Ha, bekor qilinsin'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppState state) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildActionButton(
          'Kirim',
          Icons.add,
          Theme.of(context).colorScheme.primary,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StockEntryScreen()),
          ),
        ),
        _buildActionButton(
          'Vazvrat',
          Icons.settings_backup_restore_rounded,
          Colors.orange,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReturnScreen()),
          ),
        ),
        _buildActionButton(
          'Chiqarish',
          Icons.remove_circle_outline,
          Colors.redAccent,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WriteOffScreen()),
          ),
        ),
        _buildActionButton(
          'Inventar',
          Icons.fact_check_outlined,
          Colors.teal,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InventoryScreen()),
          ),
        ),
        _buildActionButton(
          'O\'tkazma',
          Icons.swap_horiz_rounded,
          Colors.indigo,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StockTransferScreen()),
          ),
        ),
        _buildActionButton(
          'Shtrix-kod',
          Icons.qr_code_2_rounded,
          Theme.of(context).colorScheme.primary,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BarcodePrintScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
