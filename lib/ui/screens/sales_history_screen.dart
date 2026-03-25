import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../providers/features/sales_provider.dart';
import '../../providers/features/settings_provider.dart';
import '../../models/models.dart';
import '../../services/print_service.dart';

class SalesHistoryScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  const SalesHistoryScreen({super.key, this.onMenuPressed});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  DateTimeRange? _dateRange;
  String? _selectedRegisterId;

  @override
  Widget build(BuildContext context) {
    final salesProv = context.watch<SalesProvider>();
    final settingsProv = context.watch<SettingsProvider>();

    final filteredSales = salesProv.sales.where((s) {
      // Date filter
      bool matchesDate = true;
      if (_dateRange != null) {
        final date = DateTime(s.date.year, s.date.month, s.date.day);
        matchesDate =
            (date.isAtSameMomentAs(_dateRange!.start) ||
                date.isAfter(_dateRange!.start)) &&
            (date.isAtSameMomentAs(_dateRange!.end) ||
                date.isBefore(_dateRange!.end));
      }

      // Register filter
      bool matchesRegister = true;
      if (_selectedRegisterId != null) {
        matchesRegister = s.registerId == _selectedRegisterId;
      }

      return matchesDate && matchesRegister;
    }).toList();

    final totalAmount = filteredSales.fold<double>(
      0,
      (sum, item) {
        final isReturned = salesProv.returns.any((r) => r.saleId == item.id);
        return isReturned ? sum : sum + item.total;
      },
    );
    final totalProfit = filteredSales.fold<double>(
      0,
      (sum, sale) {
        final isReturned = salesProv.returns.any((r) => r.saleId == sale.id);
        return isReturned
            ? sum
            : sum + sale.items.fold(0, (iSum, item) => iSum + item.profit);
      },
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            children: [
              _buildHeader(settingsProv),
              if (filteredSales.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jami savdo:',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(totalAmount)} so\'m',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Foyda: ${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(totalProfit)} so\'m',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: filteredSales.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: filteredSales.length,
                        itemBuilder: (context, index) {
                          final sale = filteredSales[index];
                          return _buildSaleCard(sale, salesProv, settingsProv);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(SettingsProvider settingsProv) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/icon.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sotuvlar Tarixi',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Barcha amalga oshirilgan savdolarni ko\'rish va filtrlash',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onMenuPressed != null)
                IconButton(
                  icon: Icon(
                    Icons.menu_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  onPressed: widget.onMenuPressed,
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildFilterButton()),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: _selectedRegisterId != null
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : (Theme.of(context).cardColor),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedRegisterId != null
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.2)
                          : Theme.of(context).dividerColor,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedRegisterId,
                      hint: Text(
                        'Kassa bo\'yicha',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      isExpanded: true,
                      onChanged: (val) =>
                          setState(() => _selectedRegisterId = val),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text(
                            'Barcha kassalar',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        ...settingsProv.registers.map(
                          (r) => DropdownMenuItem(
                            value: r.id,
                            child: Text(r.name, style: TextStyle(fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    return InkWell(
      onTap: () => _showFilterSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _dateRange != null
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : (Theme.of(context).cardColor),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _dateRange != null
                ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: _dateRange != null
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).textTheme.bodySmall?.color,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                _dateRange == null
                    ? 'Sana bo\'yicha filter'
                    : '${DateFormat('dd.MM.yyyy').format(_dateRange!.start)} - ${DateFormat('dd.MM.yyyy').format(_dateRange!.end)}',
                style: TextStyle(
                  color: _dateRange != null
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_dateRange != null)
              IconButton(
                icon: Icon(Icons.close, size: 16),
                onPressed: () => setState(() => _dateRange = null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saralash davrini tanlang',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            _buildPresetTile(
              'Bugun',
              Icons.today,
              DateTimeRange(
                start: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
                end: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59),
              ),
            ),
            _buildPresetTile(
              'Kecha',
              Icons.history,
              DateTimeRange(
                start: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 1),
                end: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 1, 23, 59, 59),
              ),
            ),
            _buildPresetTile(
              'Oxirgi 7 kun',
              Icons.date_range,
              DateTimeRange(
                start: DateTime.now().subtract(const Duration(days: 6)),
                end: DateTime.now(),
              ),
            ),
            _buildPresetTile(
              'Shu oy',
              Icons.calendar_month,
              DateTimeRange(
                start: DateTime(DateTime.now().year, DateTime.now().month, 1),
                end: DateTime.now(),
              ),
            ),
            ListTile(
              leading: Icon(Icons.edit_calendar),
              title: Text('Tanlangan oraliq'),
              trailing: Icon(Icons.chevron_right),
              onTap: () async {
                Navigator.pop(context);
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: _dateRange,
                );
                if (picked != null) {
                  setState(() => _dateRange = picked);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetTile(String title, IconData icon, DateTimeRange range) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        setState(() => _dateRange = range);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildSaleCard(Sale sale, SalesProvider salesProv, SettingsProvider settingsProv) {
    final isReturned = salesProv.returns.any((r) => r.saleId == sale.id);
    final registerName = settingsProv.registers
            .where((r) => r.id == sale.registerId)
            .firstOrNull
            ?.name ??
        'Kassa';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isReturned
            ? (Theme.of(context).brightness == Brightness.dark
                ? Colors.red.withOpacity(0.05)
                : Colors.red.withOpacity(0.02))
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReturned
              ? Colors.red.withOpacity(0.3)
              : Theme.of(context).dividerColor,
        ),
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
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isReturned
                ? Colors.red.withOpacity(0.1)
                : Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isReturned ? Icons.assignment_return_rounded : Icons.receipt_long_rounded,
            color: isReturned ? Colors.red : Colors.green,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(
              'Sotuv #${sale.id.substring(0, 8).toUpperCase()}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                decoration: isReturned ? TextDecoration.lineThrough : null,
                color: isReturned ? Colors.grey : null,
              ),
            ),
            if (isReturned) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: const Text(
                  'VAZVRAT',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${DateFormat('dd.MM.yyyy, HH:mm').format(sale.date)} • $registerName',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color,
            fontSize: 12,
          ),
        ),
        trailing: Text(
          '${sale.total.toStringAsFixed(0)} so\'m',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: isReturned ? Colors.grey : Theme.of(context).colorScheme.onSurface,
            decoration: isReturned ? TextDecoration.lineThrough : null,
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                for (var item in sale.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${item.quantity} x ${item.price.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${(item.quantity * item.price).toStringAsFixed(0)} so\'m',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Jami:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${sale.total.toStringAsFixed(0)} so\'m',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          side: BorderSide(color: Theme.of(context).colorScheme.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => PrintService.printReceipt(
                          items: sale.items,
                          total: sale.total,
                          registerName: registerName,
                          printerName: settingsProv.selectedPrinterName,
                          ipAddress: settingsProv.networkPrinterIp,
                          orgName: settingsProv.organizationName,
                          orgAddress: settingsProv.organizationAddress,
                          instagram: settingsProv.instagramUsername,
                          logoPath: settingsProv.organizationLogoPath,
                          width: settingsProv.receiptWidth,
                          footerText: settingsProv.receiptFooterText,
                          showLogo: settingsProv.showLogoOnReceipt,
                          showInstagram: settingsProv.showInstagramOnReceipt,
                        ),
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: const Text(
                          'Chekni chiqarish',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isReturned ? Colors.grey : Colors.redAccent,
                          side: BorderSide(color: isReturned ? Colors.grey : Colors.redAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: isReturned ? null : () => _confirmReturn(context, salesProv, sale),
                        icon: Icon(isReturned ? Icons.check_circle_outline : Icons.assignment_return_outlined, size: 18),
                        label: Text(
                          isReturned ? 'Vazvrat qilingan' : 'Vazvrat qilish',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReturn(BuildContext context, SalesProvider salesProv, Sale sale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Vazvratni tasdiqlang'),
        content: Text(
          'Sotuv #${sale.id.substring(0, 8).toUpperCase()} uchun barcha mahsulotlarni omborga qaytarmoqchimisiz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final ret = SaleReturn(
                id: const Uuid().v4(),
                saleId: sale.id,
                date: DateTime.now(),
                total: sale.total,
                warehouseId: sale.warehouseId,
                items: sale.items
                    .map(
                      (i) => SaleReturnItem(
                        productId: i.productId,
                        productName: i.productName,
                        quantity: i.quantity,
                        price: i.price,
                      ),
                    )
                    .toList(),
              );
              await salesProv.addReturn(ret);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vazvrat muvaffaqiyatli amalga oshirildi'),
                  ),
                );
              }
            },
            child: const Text('Muvaffaqiyatli qaytarish'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 80, color: Colors.grey.shade300),
          SizedBox(height: 16),
          Text(
            'Sotuvlar topilmadi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          if (_dateRange != null)
            TextButton(
              onPressed: () => setState(() => _dateRange = null),
              child: Text('Filtrni tozalash'),
            ),
        ],
      ),
    );
  }
}
