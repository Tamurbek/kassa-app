import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/features/sales_provider.dart';
import '../../providers/features/inventory_provider.dart';
import '../../providers/features/settings_provider.dart';
import '../../models/models.dart';
import '../../services/update_service.dart';
import '../../services/print_service.dart';
import '../dialogs/app_update_dialog.dart';
import 'stock_transfer_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  const DashboardScreen({super.key, this.onMenuPressed});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? selectedRegisterId; // null means "All Registers"

  @override
  void initState() {
    super.initState();
  }



  @override
  Widget build(BuildContext context) {
    final sales = context.watch<SalesProvider>();
    final inventory = context.watch<InventoryProvider>();
    final settings = context.watch<SettingsProvider>();

    // Filter sales by register if selected
    final filteredSales = selectedRegisterId == null
        ? sales.sales
        : sales.sales.where((s) => s.registerId == selectedRegisterId).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              _buildHeader(context, settings, sales, inventory, constraints.maxWidth, filteredSales),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildStatsSummary(context, sales, inventory, filteredSales, constraints.maxWidth),
                    const SizedBox(height: 24),
                    if (isNarrow) ...[
                      _buildRecentSales(context, filteredSales),
                      const SizedBox(height: 24),
                      _buildTopProducts(context, filteredSales),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildRecentSales(context, filteredSales),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 1,
                            child: _buildTopProducts(context, filteredSales),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, SettingsProvider settings, SalesProvider sales, InventoryProvider inventory, double width, List<Sale> filteredSales) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Theme.of(context).cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard_customize_rounded, color: Theme.of(context).colorScheme.primary, size: 32),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.organizationName ?? 'Dashboard',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'Savdo va ko\'rsatkichlar tahlili',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              // Register Filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: selectedRegisterId,
                    hint: const Text('Barcha kassalar'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Barcha kassalar'),
                      ),
                      ...settings.registers.map((r) {
                        return DropdownMenuItem<String?>(
                          value: r.id,
                          child: Text(r.name),
                        );
                      }),
                    ],
                    onChanged: (val) => setState(() => selectedRegisterId = val),
                    icon: Icon(
                      Icons.filter_list_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockTransferScreen())),
                icon: const Icon(Icons.swap_horiz_rounded),
                tooltip: 'Omborlararo ko\'chirish',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.indigo.withOpacity(0.1),
                  foregroundColor: Colors.indigo,
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _showReportsMenu(context, settings, sales, inventory),
                icon: const Icon(Icons.print_outlined),
                tooltip: 'Hisobotlarni chop etish',
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (width > 800) ...[
                const SizedBox(width: 16),
                Chip(
                  label: Text(
                    'Bugun: ${DateFormat('dd MMMM, yyyy').format(DateTime.now())}',
                  ),
                  avatar: Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                ),
              ],
            ],
          ),
          IconButton(
            icon: const Icon(Icons.menu_rounded, size: 28),
            onPressed: widget.onMenuPressed,
            color: Theme.of(context).colorScheme.primary,
            tooltip: 'Menyu',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(
    BuildContext context,
    SalesProvider sales,
    InventoryProvider inventory,
    List<Sale> filteredSales,
    double width,
  ) {
    final now = DateTime.now();
    final todaySales = filteredSales.where((s) {
      return s.date.year == now.year &&
          s.date.month == now.month &&
          s.date.day == now.day;
    }).toList();

    final todayReturns = sales.returns.where((r) {
      return r.date.year == now.year &&
          r.date.month == now.month &&
          r.date.day == now.day;
    }).toList();

    final todayTotal = todaySales.fold(0.0, (sum, s) => sum + s.total) - 
                       todayReturns.fold(0.0, (sum, r) => sum + r.totalAmount);
    
    final todayProfit = todaySales.fold(0.0, (sum, s) => sum + s.items.fold(0.0, (iSum, item) => iSum + item.profit)) -
                        todayReturns.fold(0.0, (sum, r) => sum + r.items.fold(0.0, (iSum, item) => iSum + (item.quantity * (item.price - item.costPrice))));
    
    final todayCount = todaySales.length - todayReturns.length;
    final avgCheck = todayCount <= 0 ? 0.0 : todayTotal / todayCount;

    int crossAxisCount = width < 600
        ? 1
        : width < 1200
        ? 2
        : 5;
    final fmt = NumberFormat.currency(
      locale: 'uz_UZ',
      symbol: '',
      decimalDigits: 0,
    );

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 24,
      mainAxisSpacing: 24,
      childAspectRatio: width < 1400 ? 1.3 : 1.6,
      children: [
        _buildStatCard(
          context,
          'Bugungi Savdo',
          '${fmt.format(todayTotal)} so\'m',
          Icons.payments_outlined,
          Colors.green,
          'Live',
        ),
        _buildStatCard(
          context,
          'Cheklar soni',
          '$todayCount ta',
          Icons.receipt_long_outlined,
          Colors.blue,
          'Live',
        ),
        _buildStatCard(
          context,
          'O\'rtacha chek',
          '${fmt.format(avgCheck)} so\'m',
          Icons.analytics_outlined,
          Colors.orange,
          'Live',
        ),
        _buildStatCard(
          context,
          'Bugungi Foyda',
          '${fmt.format(todayProfit)} so\'m',
          Icons.trending_up_rounded,
          Colors.teal,
          'Live',
        ),
        _buildStatCard(
          context,
          'Mahsulotlar',
          '${inventory.products.length} turda',
          Icons.inventory_2_outlined,
          Colors.purple,
          'Baza',
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    String status,
  ) {
    final isBaza = status == 'Baza';
    final statusColor = isBaza ? Colors.blue : Colors.green;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.02,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSales(
    BuildContext context,
    List<Sale> filteredSales,
  ) {
    final recentSales = filteredSales.take(10).toList();
    final fmt = NumberFormat.currency(
      locale: 'uz_UZ',
      symbol: '',
      decimalDigits: 0,
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Oxirgi Sotuvlar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.arrow_forward_rounded, size: 20),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (recentSales.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Hozircha sotuvlar yo\'q',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            for (var sale in recentSales)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sotuv #${sale.id.substring(0, 5)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            DateFormat('HH:mm').format(sale.date),
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${fmt.format(sale.total)} so\'m',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildTopProducts(
    BuildContext context,
    List<Sale> filteredSales,
  ) {
    final now = DateTime.now();
    final todaySales = filteredSales.where(
      (s) =>
          s.date.year == now.year &&
          s.date.month == now.month &&
          s.date.day == now.day,
    );

    final Map<String, double> topMap = {};
    for (var sale in todaySales) {
      for (var item in sale.items) {
        topMap[item.productName] =
            (topMap[item.productName] ?? 0.0) + item.quantity;
      }
    }

    final sorted = topMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topProducts = sorted.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Mahsulotlar (Bugun)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 24),
          if (topProducts.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Bugun sotuv bo\'lmadi',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            for (var entry in topProducts)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${entry.value.toStringAsFixed(0)} ta',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    LinearProgressIndicator(
                      value:
                          entry.value /
                          (topProducts.first.value == 0
                              ? 1
                              : topProducts.first.value),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.05),
                      color: Theme.of(context).colorScheme.primary,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  void _showReportsMenu(BuildContext context, SettingsProvider settings, SalesProvider sales, InventoryProvider inventory) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hisobotni tanlang',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.today, color: Colors.green),
              title: const Text('Kunlik X-Hisobot (Umumiy)'),
              subtitle: const Text('Bugungi savdo va cheklar xulosasi'),
              onTap: () {
                Navigator.pop(context);
                _printDailyReport(settings, sales);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined, color: Colors.orange),
              title: const Text('Mahsulotlar Qoldig\'i'),
              subtitle: const Text('Ombordagi kam qolgan va umumiy mahsulotlar'),
              onTap: () {
                Navigator.pop(context);
                _printInventoryReport(settings, inventory);
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_outline, color: Colors.purple),
              title: const Text('Top Mahsulotlar'),
              subtitle: const Text('Eng ko\'p sotilgan mahsulotlar reytingi'),
              onTap: () {
                Navigator.pop(context);
                _printTopProductsReport(settings, sales);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _printDailyReport(SettingsProvider settings, SalesProvider sales) {
    final now = DateTime.now();
    final todaySales = sales.sales.where((s) {
      return s.date.year == now.year &&
          s.date.month == now.month &&
          s.date.day == now.day;
    }).toList();

    double total = todaySales.fold(0.0, (sum, s) => sum + s.total);
    double profit = todaySales.fold(0.0, (sum, s) => sum + s.items.fold(0.0, (iSum, item) => iSum + item.profit));
    int count = todaySales.length;
    double avg = count == 0 ? 0 : total / count;

    final fmt = NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0);

    PrintService.printReport(
      reportTitle: 'Kunlik Savdo Hisoboti',
      orgName: settings.organizationName,
      printerName: settings.selectedPrinterName,
      ipAddress: settings.networkPrinterIp,
      width: settings.receiptWidth,
      sections: [
        {
          'title': 'Umumiy Ko\'rsatkichlar',
          'rows': [
            {'label': 'Sotuvlar soni:', 'value': '$count ta'},
            {'label': 'Jami tushum:', 'value': '${fmt.format(total)} so\'m'},
            {'label': 'Jami foyda:', 'value': '${fmt.format(profit)} so\'m'},
            {'label': 'O\'rtacha chek:', 'value': '${fmt.format(avg)} so\'m'},
          ],
        },
        {
          'title': 'Kassalar bo\'yicha',
          'rows': settings.registers.map((r) {
            final regSales = todaySales.where((s) => s.registerId == r.id);
            final regTotal = regSales.fold(0.0, (sum, s) => sum + s.total);
            return {'label': r.name, 'value': '${fmt.format(regTotal)} s'};
          }).toList(),
        }
      ],
    );
  }

  void _printInventoryReport(SettingsProvider settings, InventoryProvider inventory) {
    final lowStock = inventory.activeProducts.where((p) => (p.stocks[settings.currentRegister?.warehouseId] ?? 0) <= 5).take(10).toList();
    final totalInventoryValue = inventory.activeProducts.fold(0.0, (sum, p) => sum + ((p.stocks[settings.currentRegister?.warehouseId] ?? 0) * p.price));
    
    final fmt = NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0);

    PrintService.printReport(
      reportTitle: 'Ombor Qoldig\'i Hisoboti',
      orgName: settings.organizationName,
      printerName: settings.selectedPrinterName,
      ipAddress: settings.networkPrinterIp,
      width: settings.receiptWidth,
      sections: [
        {
          'title': 'Umumiy Holat',
          'rows': [
            {'label': 'Mahsulot turlari:', 'value': '${inventory.activeProducts.length} ta'},
            {'label': 'Umumiy qiymat:', 'value': '${fmt.format(totalInventoryValue)} so\'m'},
          ],
        },
        if (lowStock.isNotEmpty) {
          'title': 'Kam qolgan mahsulotlar',
          'rows': lowStock.map((p) => {
            'label': p.name,
            'value': '${(p.stocks[settings.currentRegister?.warehouseId] ?? 0).toStringAsFixed(1)} ${p.unit ?? 'ta'}'
          }).toList(),
        }
      ],
    );
  }

  void _printTopProductsReport(SettingsProvider settings, SalesProvider sales) {
    final now = DateTime.now();
    final todaySales = sales.sales.where((s) => 
      s.date.year == now.year && s.date.month == now.month && s.date.day == now.day
    );

    final Map<String, double> topMap = {};
    for (var sale in todaySales) {
      for (var item in sale.items) {
        topMap[item.productName] = (topMap[item.productName] ?? 0.0) + item.quantity;
      }
    }

    final sorted = topMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topProducts = sorted.take(15).toList();

    PrintService.printReport(
      reportTitle: 'Top Mahsulotlar (Bugun)',
      orgName: settings.organizationName,
      printerName: settings.selectedPrinterName,
      ipAddress: settings.networkPrinterIp,
      width: settings.receiptWidth,
      sections: [
        {
          'title': 'Eng ko\'p sotilganlar',
          'rows': topProducts.map((e) => {
            'label': e.key,
            'value': '${e.value.toStringAsFixed(1)} ta'
          }).toList(),
        }
      ],
    );
  }
}
