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
                    
                    // Capture providers before any async work
                    final appState = context.read<AppState>();
                    final auth = context.read<AuthProvider>();
                    final settings = context.read<SettingsProvider>();
                    final inventory = context.read<InventoryProvider>();
                    final sales = context.read<SalesProvider>();
                    final sync = context.read<SyncProvider>();

                    setState(() {
                      _isRestoring = true;
                      _error = null;
                    });
                    
                      try {
                        final code = _codeController.text.trim();
                        
                        // 1. Try restore from cloud FIRST (with override)
                        try {
                          if (mounted) {
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
                          }
                          
                          await sync.restoreDatabaseFromCloud(activationCodeOverride: code);
                        } catch (backupError) {
                          debugPrint('Auto-restore skipped or failed: $backupError');
                        }
                        
                        // 2. Refresh ALL providers (Crucial for memory management)
                        // Note: We don't check 'mounted' here for reloads because providers are independent of the widget,
                        // and we want them to finish even if the screen is being unmounted by a state change.
                        await appState.loadSettings();
                        await settings.loadSettings();
                        await auth.reloadUsers();
                        await inventory.reloadData(forceRecalculate: true); // Force once after cloud restore
                        await sales.reloadSalesData();
                        await sync.loadSync();

                        // 3. Commit Activation (This triggers the UI switch via notifyListeners)
                        if (mounted) {
                          await auth.activate(code);
                          
                          // Final UI polish
                          if (mounted) {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('✅ Faollashtirildi!'), backgroundColor: Colors.green),
                            );
                          }
                        }
                      } catch (e) {
                      if (mounted) {
                        setState(() {
                           _error = e.toString().replaceAll('Exception: ', '');
                           _isRestoring = false;
                        });
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      }
                    }
                  },
                ),
              ),

              if (_error != null && _error!.contains('Aloqa mavjud emas'))
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextButton.icon(
                    onPressed: () async {
                      final ok = await context.read<AppState>().fixNetworkConnection();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok 
                              ? 'Tarmoq sozlamalari to\'g\'rilandi! Endi qayta urinib ko\'ring.' 
                              : 'Sozlamalar yangilandi, lekin hali ham internetga ulanib bo\'lmayapti.'),
                            backgroundColor: ok ? Colors.green : Colors.orange,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.build_circle_rounded, size: 20),
                    label: const Text('Tarmoqni tekshirish va tuzatish'),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
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
