import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/features/auth_provider.dart';
import '../../providers/features/settings_provider.dart';
import '../../providers/features/sync_provider.dart';
import '../../providers/features/inventory_provider.dart';
import '../../providers/features/sales_provider.dart';
import '../../providers/app_state.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final TextEditingController _codeController = TextEditingController();
  String? _error;
  bool _isRestoring = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final sync = context.watch<SyncProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  Theme.of(context).brightness == Brightness.dark ? 0.4 : 0.2,
                ),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Icon(
                  Icons.shopping_bag_rounded,
                  size: 100,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                'Dastur faollashtirilmagan',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Ushbu kompyuterda dasturdan foydalanish uchun litsenziya kodi talab qilinadi.',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Device ID Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SO\'ROV KODI (DEVICE ID):',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            letterSpacing: 1,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: auth.activationRequestCode),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Suro\'v kodi nusxalandi!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      auth.activationRequestCode,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'Aktivatsiya kodi',
                  hintText: 'SS-XXXX-OK',
                  errorText: _error,
                  prefixIcon: const Icon(Icons.vpn_key_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                ),
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                onChanged: (_) => setState(() => _error = null),
                enabled: !_isRestoring,
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isRestoring ? null : () async {
                    if (_codeController.text.isEmpty) {
                      setState(() => _error = 'Kodni kiriting!');
                      return;
                    }
                    
                    setState(() {
                      _isRestoring = true;
                      _error = null;
                    });
                    
                    try {
                      final code = _codeController.text.trim();
                      
                      // 1. Try restore from cloud FIRST (with override)
                      try {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                SizedBox(width: 12),
                                Text('Ma\'lumotlar yuklanmoqda...'),
                              ],
                            ),
                            duration: Duration(minutes: 1),
                          ),
                        );
                        
                        await sync.restoreDatabaseFromCloud(activationCodeOverride: code);
                        
                        // 2. Refresh providers (Reload data BEFORE nav)
                        if (mounted) {
                          final mainContext = context;
                          await mainContext.read<AppState>().loadSettings();
                          await mainContext.read<SettingsProvider>().loadSettings();
                          await mainContext.read<AuthProvider>().reloadUsers();
                          await mainContext.read<InventoryProvider>().reloadData();
                          await mainContext.read<SalesProvider>().reloadSalesData();
                        }
                      } catch (backupError) {
                        debugPrint('Auto-restore skipped or failed: $backupError');
                      }
                      
                      // 3. Commit Activation (this triggers nav to LoginScreen)
                      if (mounted) {
                        await auth.activate(code);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Faollashtirildi!'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      setState(() {
                         _error = e.toString().replaceAll('Exception: ', '');
                         _isRestoring = false;
                      });
                      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    }
                  },
                  child: _isRestoring 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text(
                        'FAOLLASHTIRISH',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                ),
              ),

              const SizedBox(height: 24),
              Text(
                'Kodni olish uchun Telegram botga murojaat qiling:',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '@SimpleSaleBot',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    await context.read<AppState>().resetTerminalMode();
                    if (context.mounted) {
                      await context.read<AuthProvider>().loadAuth();
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text(
                    'Ortga (Boshlang\'ich sozlamalarga qaytish)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
