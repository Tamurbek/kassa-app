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
          logoPath: settings.organizationLogoPath,
          width: settings.receiptWidth,
          footerText: settings.receiptFooterText,
          showLogo: settings.showLogoOnReceipt,
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
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSummaryCard(total, change),
                              SizedBox(height: 32),
                              _buildPaymentMethods(),
                              SizedBox(height: 32),
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
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.03,
            ),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
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
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              Text(
                '${fmt.format(total)} so\'m',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          if (change > 0 && paymentMethod == 'Naqd') ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Divider(height: 1, color: Theme.of(context).dividerColor),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Qaytim:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
                Text(
                  '${fmt.format(change)} so\'m',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.green,
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
        Text(
          '  TO\'LOV USULI',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).textTheme.bodySmall?.color,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            _buildMethodBtn(
              'Naqd',
              Icons.payments_rounded,
              Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: 16),
            _buildMethodBtn(
              'Plastik',
              Icons.credit_card_rounded,
              Colors.lightBlue,
            ),
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
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: isSelected ? color : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : Theme.of(context).dividerColor,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : color, size: 28),
              SizedBox(height: 12),
              Text(
                method,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
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
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Theme.of(context).dividerColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OLINGAN SUMMA',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  val.isEmpty ? '0' : val,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'SO\'M',
                style: TextStyle(
                  color: Theme.of(context).dividerColor,
                  fontSize: 24,
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
        SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [1000, 5000, 10000, 20000, 50000, 100000, 200000].map((
              amount,
            ) {
              return InkWell(
                onTap: () => onQuickAdd(amount.toDouble()),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Text(
                    '+${fmt.format(amount).trim()}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: 24),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                for (var i = 1; i <= 9; i++) _buildNumBtn(i.toString()),
                _buildNumBtn(
                  'C',
                  color: Colors.red.withOpacity(0.1),
                  textColor: Colors.red,
                ),
                _buildNumBtn('0'),
                _buildNumBtn(
                  'back',
                  icon: Icons.backspace_rounded,
                  color: Theme.of(context).colorScheme.surface,
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(24),
          child: ElevatedButton(
            onPressed: () => setState(
              () => receivedController.text = total.toStringAsFixed(0),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              minimumSize: const Size.fromHeight(60),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'ANIQ SUMMA',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumBtn(
    String val, {
    Color? color,
    Color? textColor,
    IconData? icon,
  }) {
    return Material(
      color: color ?? (Theme.of(context).cardColor),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => onNumPressed(val),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Center(
            child: icon != null
                ? Icon(
                    icon,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 28,
                  )
                : Text(
                    val,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color:
                          textColor ?? Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleFooter(SalesProvider sales, SettingsProvider settings, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Bekor qilish',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => _executeSale(sales, settings, auth),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(64),
                elevation: 8,
                shadowColor: Theme.of(
                  context,
                ).colorScheme.primary.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                'TASDIQLASH VA BOSISH',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
