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
import '../../providers/features/navigation_provider.dart';
import 'stock_transfer_screen.dart';
import '../../core/utils/formatter.dart';

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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: LayoutBuilder(
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
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SettingsProvider settings, SalesProvider sales, InventoryProvider inventory, double width, List<Sale> filteredSales) {
    final bool showChip = width > 1100;
    final bool showSubtitle = width > 700;

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
                  if (showSubtitle)
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
              const SizedBox(width: 8),
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
              const SizedBox(width: 8),
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
              if (showChip) ...[
                const SizedBox(width: 12),
                Chip(
                  label: Text(
                    'Bugun: ${DateFormat('dd MMMM').format(DateTime.now())}',
                  ),
                  avatar: Icon(
                    Icons.calendar_today,
                    size: 14,
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

    int crossAxisCount = width < 600 ? 1 : width < 1200 ? 2 : 4;
    final fmt = NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: width < 600 ? 1.8 : (width < 1200 ? 1.5 : 1.4),
      children: [
        _buildStatCard(
          context,
          'Bugungi Savdo',
          '${fmt.format(todayTotal)} s',
          Icons.payments_rounded,
          Colors.green,
          'Live',
          subValue: 'Bugungi umumiy tushum',
          trendData: [0.1, 0.4, 0.3, 0.7, 0.5, 0.9, 0.8], 
        ),
        _buildStatCard(
          context,
          'Cheklar soni',
          '$todayCount ta',
          Icons.receipt_long_rounded,
          Colors.blue,
          'Live',
          subValue: 'Qaytarilgan: ${todayReturns.length} ta',
          trendData: [0.2, 0.3, 0.5, 0.4, 0.6, 0.3, 0.5],
        ),
        _buildStatCard(
          context,
          'O\'rtacha chek',
          '${fmt.format(avgCheck)} s',
          Icons.analytics_rounded,
          Colors.orange,
          'Live',
          subValue: 'Savdo samaradorligi',
          trendData: [0.4, 0.4, 0.5, 0.5, 0.4, 0.6, 0.7],
        ),
        _buildStatCard(
          context,
          'Bugungi Foyda',
          '${fmt.format(todayProfit)} s',
          Icons.trending_up_rounded,
          Colors.teal,
          'Live',
          subValue: 'Sof tushum (foyda)',
          trendData: [0.1, 0.2, 0.4, 0.6, 0.5, 0.8, 1.0],
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
    String status, {
    String? subValue,
    List<double>? trendData,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background Trend Sparkline
            if (trendData != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 45,
                child: CustomPaint(
                  painter: SparklinePainter(
                    data: trendData,
                    color: color.withOpacity(0.15),
                  ),
                ),
              ),
            
            LayoutBuilder(
              builder: (context, constraints) {
                final bool isShort = constraints.maxHeight < 155;
                final bool hideSub = constraints.maxHeight < 145;
                
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16, 
                    vertical: isShort ? 6 : 12
                  ),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: EdgeInsets.all(isShort ? 5 : 8),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(isShort ? 8 : 12),
                              ),
                              child: Icon(icon, color: color, size: isShort ? 16 : 20),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: status == 'Live' ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (status == 'Live')
                                    Container(
                                      width: 4,
                                      height: 4,
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  Text(
                                    status,
                                    style: TextStyle(
                                      color: status == 'Live' ? Colors.green : Colors.blue,
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: isShort ? 10 : 20),
                        
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            title,
                            style: TextStyle(
                              color: theme.disabledColor,
                              fontSize: isShort ? 11 : 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: isShort ? 22 : 26,
                              fontWeight: FontWeight.w900,
                              color: theme.textTheme.bodyLarge?.color,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                        if (subValue != null && !hideSub) ...[
                          const SizedBox(height: 1),
                          Text(
                            subValue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.disabledColor.withOpacity(0.6),
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }
            ),
          ],
        ),
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
                          '${AppFormatter.formatDouble(entry.value)} ta',
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
              onTap: () async {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('X-Hisobot chop etilmoqda...')));
                _printDailyReport(settings, sales);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined, color: Colors.orange),
              title: const Text('Mahsulotlar Qoldig\'i'),
              subtitle: const Text('Ombordagi kam qolgan va umumiy mahsulotlar'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ombor hisoboti chop etilmoqda...')));
                _printInventoryReport(settings, inventory);
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_outline, color: Colors.purple),
              title: const Text('Top Mahsulotlar'),
              subtitle: const Text('Eng ko\'p sotilgan mahsulotlar reytingi'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Top mahsulotlar hisoboti chop etilmoqda...')));
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
            'value': '${AppFormatter.formatDouble(p.stocks[settings.currentRegister?.warehouseId] ?? 0)} ${p.unit ?? 'ta'}'
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
            'value': '${AppFormatter.formatDouble(e.value)} ta'
          }).toList(),
        }
      ],
    );
  }
}

class SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final double stepX = size.width / (data.length - 1);
    
    for (int i = 0; i < data.length; i++) {
      final double x = i * stepX;
      final double y = size.height - (data[i] * size.height * 0.8);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Fill area below
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
