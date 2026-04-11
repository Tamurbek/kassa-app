import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/features/sales_provider.dart';
import '../../providers/features/settings_provider.dart';
import '../../models/models.dart';
import 'pos_screen.dart';

class SalesSessionsScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  const SalesSessionsScreen({super.key, this.onMenuPressed});

  @override
  State<SalesSessionsScreen> createState() => _SalesSessionsScreenState();
}

class _SalesSessionsScreenState extends State<SalesSessionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sales = context.watch<SalesProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(context, sales),
          _buildTabBar(context),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUnfinishedSales(context, sales),
                _buildCompletedSales(context, sales),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          sales.clearCart();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => POSScreen(onMenuPressed: widget.onMenuPressed),
            ),
          );
        },
        icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
        label: const Text('YANGI SAVDO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 8,
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SalesProvider sales) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      color: Theme.of(context).cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Savdo bo\'limi',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              Text(
                'Tugallangan va kutilayotgan savdolar nazorati',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          if (widget.onMenuPressed != null)
            IconButton(
              icon: const Icon(Icons.menu_rounded, size: 28),
              onPressed: widget.onMenuPressed,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      child: TabBar(
        controller: _tabController,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Theme.of(context).colorScheme.primary,
        indicatorWeight: 4,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        tabs: const [
          Tab(text: 'Kutayotgan savdolar'),
          Tab(text: 'Oxirgi sotuvlar'),
        ],
      ),
    );
  }

  Widget _buildUnfinishedSales(BuildContext context, SalesProvider sales) {
    if (sales.suspendedSales.isEmpty) {
      return _buildEmptyState(
        context,
        Icons.pause_circle_outline_rounded,
        'Kutayotgan savdolar yo\'q',
        'Yangi savdo boshlash uchun + tugmasini bosing',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: sales.suspendedSales.length,
      itemBuilder: (context, index) {
        final s = sales.suspendedSales[index];
        return _buildSessionCard(
          context,
          title: s.note != null && s.note!.isNotEmpty ? s.note! : 'Nomsiz savdo #${s.id.substring(s.id.length - 4)}',
          subtitle: '${s.items.length} ta mahsulot • ${DateFormat('HH:mm').format(s.date)}',
          amount: s.total,
          isSuspended: true,
          onTap: () async {
            await sales.resumeSuspendedSale(s);
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => POSScreen(onMenuPressed: widget.onMenuPressed),
                ),
              );
            }
          },
          onDelete: () => _confirmDelete(context, sales, s.id),
        );
      },
    );
  }

  Widget _buildCompletedSales(BuildContext context, SalesProvider sales) {
    final now = DateTime.now();
    final todaySales = sales.sales.where((s) => 
      s.date.year == now.year && s.date.month == now.month && s.date.day == now.day
    ).toList();

    if (todaySales.isEmpty) {
      return _buildEmptyState(
        context,
        Icons.history_rounded,
        'Bugun hali savdo qilinmadi',
        'Tugallangan savdolar shu yerda ko\'rinadi',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: todaySales.length,
      itemBuilder: (context, index) {
        final s = todaySales[index];
        return _buildSessionCard(
          context,
          title: 'Sotuv #${s.id.length > 8 ? s.id.substring(0, 8) : s.id}',
          subtitle: '${s.items.length} ta mahsulot • ${DateFormat('HH:mm').format(s.date)}',
          amount: s.total,
          isSuspended: false,
          onTap: () {
            // View details or print
          },
        );
      },
    );
  }

  Widget _buildSessionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required double amount,
    required bool isSuspended,
    required VoidCallback onTap,
    VoidCallback? onDelete,
  }) {
    final fmt = NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: (isSuspended ? Colors.orange : Colors.green).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuspended ? Icons.pause_rounded : Icons.check_circle_outline_rounded,
                  color: isSuspended ? Colors.orange : Colors.green,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${fmt.format(amount)} s',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: isSuspended ? Colors.orange.shade700 : Colors.green.shade700,
                    ),
                  ),
                  if (isSuspended && onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.withOpacity(0.2)),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, SalesProvider sales, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Savdoni o\'chirish'),
        content: const Text('Ushbu kutilayotgan savdoni o\'chirib yubormoqchimisiz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bekor qilish')),
          TextButton(
            onPressed: () {
              sales.deleteSuspendedSale(id);
              Navigator.pop(context);
            },
            child: const Text('O\'chirish', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
