import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/features/sales_provider.dart';
import '../../providers/features/settings_provider.dart';
import '../../providers/features/auth_provider.dart';
import '../../providers/features/inventory_provider.dart';
import '../../providers/app_state.dart';
import '../../services/print_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String paymentMethod = 'Naqd';
  final TextEditingController receivedController = TextEditingController();
  final fmt = NumberFormat.currency(
    locale: 'uz_UZ',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    final sales = context.read<SalesProvider>();
    receivedController.text = sales.cartTotal.toStringAsFixed(0);
  }

  void onNumPressed(String val) {
    setState(() {
      if (val == 'C') {
        receivedController.clear();
      } else if (val == 'back') {
        if (receivedController.text.isNotEmpty) {
          receivedController.text = receivedController.text.substring(
            0,
            receivedController.text.length - 1,
          );
        }
      } else {
        receivedController.text += val;
      }
    });
  }

  void onQuickAdd(double amount) {
    setState(() {
      final current = double.tryParse(receivedController.text) ?? 0;
      receivedController.text = (current + amount).toStringAsFixed(0);
    });
  }

  Future<void> _executeSale(
    SalesProvider sales,
    SettingsProvider settings,
    AuthProvider auth,
  ) async {
    final receivedAmount = double.tryParse(receivedController.text) ?? 0;
    if (receivedAmount < sales.cartTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kiritilgan summa jami summadan kam!', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      if (settings.selectedPrinterName != null ||
          (settings.networkPrinterIp != null &&
              settings.networkPrinterIp!.isNotEmpty)) {
        await PrintService.printReceipt(
          items: sales.cart,
          total: sales.cartTotal,
          registerName: settings.currentRegister?.name ?? 'Kassa',
          printerName: settings.selectedPrinterName,
          ipAddress: settings.networkPrinterIp,
          orgName: settings.organizationName,
          orgAddress: settings.organizationAddress,
          instagram: settings.instagramUsername,
          width: settings.receiptWidth,
          footerText: settings.receiptFooterText,
          showInstagram: settings.showInstagramOnReceipt,
        );
      }

      final receivedAmount = double.tryParse(receivedController.text) ?? sales.cartTotal;

      final inventory = context.read<InventoryProvider>();
      final appState = context.read<AppState>();

      await sales.checkout(
        registerId: settings.currentRegister?.id,
        warehouseId: settings.currentRegister?.warehouseId,
      );

      // Force UI update for stock levels
      await inventory.reloadData();
      await appState.reloadData();

      if (mounted) {
        Navigator.pop(context); // close loader
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 64,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Sotuv yakunlandi!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Ombor yangilandi va chek chiqarildi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context); // close success dialog
                  Navigator.pop(context); // back to POS
                },
                child: Text(
                  'Davom Etish',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sales = context.watch<SalesProvider>();
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    
    final total = sales.cartTotal;
    final receivedStr = receivedController.text;
    final received = double.tryParse(receivedStr) ?? 0;
    final change = received - total;

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
                title: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/icon.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'To\'lovni Yakunlash',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: false,
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 950;

          if (isSmall) {
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildSummaryCard(total, change),
                        SizedBox(height: 20),
                        _buildPaymentMethods(),
                        SizedBox(height: 20),
                        _buildNumpadSection(total),
                      ],
                    ),
                  ),
                ),
                _buildSimpleFooter(sales, settings, auth),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSummaryCard(total, change),
                              const SizedBox(height: 24),
                              _buildPaymentMethods(),
                              const SizedBox(height: 24),
                              _buildBigDisplay(receivedStr),
                            ],
                          ),
                        ),
                      ),
                      _buildSimpleFooter(sales, settings, auth),
                    ],
                  ),
                ),
              ),
              Container(
                width: 450,
                color: Theme.of(context).cardColor,
                child: _buildNumpadSection(total),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(double total, double change) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'To\'lanishi kerak:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              Text(
                '${fmt.format(total)} so\'m',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          if (change > 0 && paymentMethod == 'Naqd') ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.5)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Qaytim:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary,
                  ),
                ),
                Text(
                  '${fmt.format(change)} so\'m',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.secondary,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 12),
          child: Text(
            'TO\'LOV USULI',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              letterSpacing: 1.5,
            ),
          ),
        ),
        Row(
          children: [
            _buildMethodBtn('Naqd', Icons.payments_rounded, AppColors.primary),
            const SizedBox(width: 16),
            _buildMethodBtn('Plastik', Icons.credit_card_rounded, Colors.lightBlue),
          ],
        ),
      ],
    );
  }

  Widget _buildMethodBtn(String method, IconData icon, Color color) {
    final isSelected = paymentMethod == method;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => paymentMethod = method),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? color : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : Theme.of(context).dividerColor.withOpacity(0.8),
              width: 2,
            ),
            boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))] : [],
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : color, size: 30),
              const SizedBox(height: 12),
              Text(
                method,
                style: TextStyle(
                  color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBigDisplay(String val) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KIRITILGAN SUMMA',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  val.isEmpty ? '0' : val,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'SO\'M',
                style: TextStyle(
                  color: Theme.of(context).dividerColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumpadSection(double total) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [5000, 10000, 20000, 50000, 100000, 200000].map((amount) {
              return InkWell(
                onTap: () => onQuickAdd(amount.toDouble()),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    '+${fmt.format(amount).trim()}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              for (var i = 1; i <= 9; i++) _buildNumBtn(i.toString()),
              _buildNumBtn('C', color: Colors.red.withOpacity(0.1), textColor: Colors.red),
              _buildNumBtn('0'),
              _buildNumBtn('back', icon: Icons.backspace_outlined),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: OutlinedButton(
            onPressed: () => setState(() => receivedController.text = total.toStringAsFixed(0)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
              side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
            ),
            child: const Text('ANIQ SUMMA', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }

  Widget _buildNumBtn(String val, {Color? color, Color? textColor, IconData? icon}) {
    return Material(
      color: color ?? Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => onNumPressed(val),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 28)
                : Text(
                    val,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: textColor ?? Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleFooter(SalesProvider sales, SettingsProvider settings, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(minimumSize: const Size(0, 64)),
              child: const Text('BEKOR QILISH', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => _executeSale(sales, settings, auth),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 64),
                shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                elevation: 8,
              ),
              child: const Text('TASDIQLASH', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }
}
