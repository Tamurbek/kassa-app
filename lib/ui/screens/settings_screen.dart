import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../../providers/features/settings_provider.dart';
import '../../providers/features/sync_provider.dart';
import '../../providers/features/auth_provider.dart';
import '../../providers/features/inventory_provider.dart';
import '../../providers/features/sales_provider.dart';
import '../../providers/app_state.dart';
import '../../models/models.dart';
import '../../services/print_service.dart';
import '../../services/sync_service.dart';
import '../../services/update_service.dart';
import '../dialogs/app_update_dialog.dart';
import 'terminal_management_screen.dart';
import 'warehouse_management_screen.dart';
import 'receipt_designer_screen.dart';

class SettingsScreen extends StatelessWidget {
  final VoidCallback? onMenuPressed;
  const SettingsScreen({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final sync = context.watch<SyncProvider>();
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.currentUser?.role == UserRole.admin;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (isAdmin)
                      _buildSection(
                        context,
                        'Asosiy Sozlamalar',
                        'Kassa va unga bog\'langan omborlarni sozlash',
                        [
                          _buildSettingsTile(
                            context,
                            icon: Icons.storefront,
                            color: Colors.blue,
                            title: 'Joriy Kassa',
                            subtitle: settings.currentRegister?.name ?? 'Tanlanmagan',
                            onTap: () => _showRegisterPicker(context, settings),
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.business_rounded,
                            color: Colors.blueGrey,
                            title: 'Tashkilot nomi',
                            subtitle: settings.organizationName ?? 'Simple Sale',
                            onTap: () => _showEditOrgInfoDialog(context, auth, settings, field: 'name'),
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.location_on_rounded,
                            color: Colors.orange,
                            title: 'Tashkilot manzili',
                            subtitle: settings.organizationAddress?.isEmpty ?? true
                                ? 'Kiritilmagan'
                                : settings.organizationAddress!,
                            onTap: () => _showEditOrgInfoDialog(context, auth, settings, field: 'address'),
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.camera_alt_rounded,
                            color: Colors.purple,
                            title: 'Instagram',
                            subtitle: settings.instagramUsername?.isEmpty ?? true
                                ? 'Kiritilmagan'
                                : '@${settings.instagramUsername}',
                            onTap: () => _showEditOrgInfoDialog(context, auth, settings, field: 'instagram'),
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.terminal_rounded,
                            color: Colors.indigo,
                            title: 'Kassa Terminallari',
                            subtitle: 'Terminallarni qo\'shish va tahrirlash',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TerminalManagementScreen(),
                              ),
                            ),
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.point_of_sale_rounded,
                            color: Colors.blueAccent,
                            title: 'Tanlangan Kassa Terminali',
                            subtitle: settings.currentRegister?.name ?? 'Tanlanmagan',
                            onTap: () => _showRegisterPicker(context, settings),
                          ),
                          _buildSettingsTile(
                            context,
                            icon: Icons.warehouse_rounded,
                            color: Colors.orange,
                            title: 'Omborlar',
                            subtitle: 'Omborlarni qo\'shish va tahrirlash',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WarehouseManagementScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (isAdmin) ...[
                      const SizedBox(height: 24),
                      _buildSection(
                        context,
                        'Ma\'lumotlar zaxirasi',
                        'Bulutli va lokal zaxira nusxalari',
                        [
                          _buildSettingsTile(
                            context,
                            icon: Icons.sync_rounded,
                            color: Colors.green,
                            title: 'Zaxira va Tiklash',
                            subtitle: 'Ma\'lumotlarni bulutga yoki faylga saqlash',
                            onTap: () => _showCloudDialog(context, sync),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    _buildSection(
                      context,
                      'Ko\'rinish va Rejimlar',
                      'Ilova ko\'rinishi va ishlash usulini sozlash',
                      [
                        _buildSettingsTile(
                          context,
                          icon: Icons.brightness_6_rounded,
                          color: Colors.amber,
                          title: 'Mavzu (Dark Mode)',
                          subtitle: settings.themeMode == ThemeMode.dark
                              ? 'Tungi rejim'
                              : settings.themeMode == ThemeMode.light
                                  ? 'Yorug\' rejim'
                                  : 'Tizim rejimi',
                          onTap: () => _showThemePicker(context, settings),
                        ),
                        _buildSettingsTile(
                          context,
                          icon: Icons.qr_code_scanner_rounded,
                          color: Colors.green,
                          title: 'Scan Rejimi (Klaviatura)',
                          subtitle: settings.isBarcodeScanMode ? 'Yoqilgan' : 'O\'chirilgan',
                          trailing: Switch(
                            value: settings.isBarcodeScanMode,
                            onChanged: (v) => settings.toggleBarcodeScanMode(),
                          ),
                          onTap: () => settings.toggleBarcodeScanMode(),
                        ),
                        _buildSettingsTile(
                          context,
                          icon: Icons.inventory_2_rounded,
                          color: Colors.orange,
                          title: 'Ombor ayirish rejimi (Sotuvda)',
                          subtitle: settings.shouldTrackInventory 
                              ? 'Yoqilgan (sotuvdan keyin ombordan ayriladi)' 
                              : 'O\'chirilgan (sotuvlar omborga ta\'sir qilmaydi)',
                          trailing: Switch(
                            value: settings.shouldTrackInventory,
                            activeColor: Colors.orange,
                            onChanged: (v) => settings.toggleInventoryTracking(),
                          ),
                          onTap: () => settings.toggleInventoryTracking(),
                        ),
                        _buildSettingsTile(
                          context,
                          icon: Icons.fullscreen_rounded,
                          color: Colors.blueGrey,
                          title: 'Butun ekran rejimi',
                          subtitle: settings.isFullScreen ? 'Yoqilgan' : 'O\'chirilgan',
                          trailing: Switch(
                            value: settings.isFullScreen,
                            onChanged: (v) => settings.toggleFullScreen(),
                          ),
                          onTap: () => settings.toggleFullScreen(),
                        ),
                      ],

                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      context,
                      'Printer va Cheklar',
                      'Chek chiqarish va printer sozlamalari',
                      [
                        _buildSettingsTile(
                          context,
                          icon: Icons.print_rounded,
                          color: Colors.blue,
                          title: 'Sotuv Prinfari',
                          subtitle: (settings.selectedPrinterName == 'Network' 
                              ? (settings.networkPrinterIp ?? 'IP kiritilmagan') 
                              : (settings.selectedPrinterName ?? 'Tanlanmagan')),
                          onTap: () => _showPrinterPicker(context, settings),
                        ),
                        _buildSettingsTile(
                          context,
                          icon: Icons.qr_code_scanner_rounded,
                          color: Colors.indigo,
                          title: 'Shtrix-kod Printeri',
                          subtitle: (settings.barcodePrinterName == 'Network' 
                              ? (settings.networkBarcodePrinterIp ?? 'IP kiritilmagan') 
                              : (settings.barcodePrinterName ?? 'Tanlanmagan')),
                          onTap: () => _showBarcodePrinterPicker(context, settings),
                        ),
                        _buildSettingsTile(
                          context,
                          icon: Icons.receipt_long_rounded,
                          color: Colors.deepPurple,
                          title: 'Chek o\'lchami',
                          subtitle: '${settings.receiptWidth} mm',
                          onTap: () => _showReceiptWidthPicker(context, settings),
                        ),
                        _buildSettingsTile(
                          context,
                          icon: Icons.design_services_rounded,
                          color: Colors.pink,
                          title: 'Chek Dizayneri',
                          subtitle: 'Chek ko\'rinishini sozlash',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ReceiptDesignerScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      context,
                      'Ilova haqida',
                      'Dastur haqida ma\'lumotlar',
                      [
                        _buildSettingsTile(
                          context,
                          icon: Icons.info_outline_rounded,
                          color: Colors.grey,
                          title: 'Versiya',
                          subtitle: 'V ${settings.appVersion}',
                          onTap: () => _checkUpdate(context),
                        ),
                      ],
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 24),
                      _buildSection(
                        context,
                        'Tizimni Tozalash',
                        'Dasturni boshlang\'ich holatga qaytarish',
                        [
                          _buildSettingsTile(
                            context,
                            icon: Icons.delete_forever_rounded,
                            color: Colors.red,
                            title: 'Barcha ma\'lumotlarni o\'chirish',
                            subtitle: 'Dasturni tozalash va qayta o\'rnatish holatiga keltirish',
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Diqqat!'),
                                  content: const Text(
                                    'Ushbu amal barcha ma\'lumotlarni (mahsulotlar, sotuvlar, sozlamalar) butunlay o\'chirib yuboradi. Dastur qayta o\'rnatilgan holatga qaytadi. Davom etasizmi?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Yo\'q'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                      child: const Text('Ha, hammasini o\'chirish'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await context.read<AppState>().resetTerminalMode();
                                if (context.mounted) {
                                  await context.read<AuthProvider>().loadAuth();
                                  await context.read<SettingsProvider>().loadSettings();
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Sozlamalar',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.menu_rounded, size: 28),
            onPressed: onMenuPressed,
            color: Theme.of(context).colorScheme.primary,
            tooltip: 'Menyu',
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String subtitle, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
      trailing: trailing ??
          Icon(
            Icons.chevron_right_rounded,
            color: Theme.of(context).dividerColor,
          ),
    );
  }


  void _showPrinterPicker(BuildContext context, SettingsProvider settings) async {
    final devices = await Printing.listPrinters();
    if (context.mounted) {
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
              const Text(
                'Printerni tanlang',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.wifi, color: Colors.blue),
                title: const Text('Network Printer (Direct IP)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(settings.networkPrinterIp ?? 'Hali kiritilmagan'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (settings.networkPrinterIp != null && settings.networkPrinterIp!.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.print_rounded, color: Colors.blue, size: 20),
                        tooltip: 'Test chop etish',
                        onPressed: () async {
                          try {
                            await PrintService.testPrint(
                              printerName: null,
                              ipAddress: settings.networkPrinterIp,
                              registerName: settings.currentRegister?.name ?? 'Kassa',
                              width: settings.receiptWidth,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Test cheki yuborildi'), backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                      ),
                    settings.selectedPrinterName == 'Network'
                        ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                        : const Icon(Icons.edit_note),
                  ],
                ),
                onTap: () {
                  _showIpInputDialog(context, settings, isBarcode: false);
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
                child: Text('Tizimdagi printerlar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              Expanded(
                child: ListView(
                  children: [
                    ...devices.map((d) => ListTile(
                          leading: const Icon(Icons.print),
                          title: Text(d.name),
                          trailing: settings.selectedPrinterName == d.name
                              ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                              : null,
                          onTap: () {
                            settings.updatePrinter(d.name);
                            Navigator.pop(context);
                          },
                        )),
                    if (devices.isEmpty)
                       const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(child: Text('Printerlar topilmadi', style: TextStyle(color: Colors.grey))),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showIpInputDialog(BuildContext context, SettingsProvider settings, {required bool isBarcode}) {
    final controller = TextEditingController(text: isBarcode ? settings.networkBarcodePrinterIp : settings.networkPrinterIp);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Printer IP manzilini kiriting'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '192.168.1.100',
            labelText: 'IP Manzil',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish')),
          ElevatedButton(
            onPressed: () {
              final ip = controller.text.trim();
              if (isBarcode) {
                settings.updateNetworkBarcodePrinterIp(ip);
                settings.updateBarcodePrinter('Network');
              } else {
                settings.updateNetworkPrinterIp(ip);
                settings.updatePrinter('Network');
              }
              Navigator.pop(ctx);
              Navigator.pop(context); // close bottom sheet
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }

  void _showBarcodePrinterPicker(BuildContext context, SettingsProvider settings) async {
    final devices = await Printing.listPrinters();
    if (context.mounted) {
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
              const Text(
                'Shtrix-kod printerni tanlang',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.wifi, color: Colors.blue),
                title: const Text('Network Printer (Direct IP)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(settings.networkBarcodePrinterIp ?? 'Hali kiritilmagan'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (settings.networkBarcodePrinterIp != null && settings.networkBarcodePrinterIp!.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.print_rounded, color: Colors.blue, size: 20),
                        tooltip: 'Test chop etish',
                        onPressed: () async {
                          try {
                            await PrintService.testPrint(
                              printerName: null,
                              ipAddress: settings.networkBarcodePrinterIp,
                              registerName: settings.currentRegister?.name ?? 'Kassa',
                              width: 80, // standardized test
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Test cheki yuborildi'), backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                      ),
                    settings.barcodePrinterName == 'Network'
                        ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                        : const Icon(Icons.edit_note),
                  ],
                ),
                onTap: () {
                  _showIpInputDialog(context, settings, isBarcode: true);
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
                child: Text('Tizimdagi printerlar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              Expanded(
                child: ListView(
                  children: [
                    ...devices.map((d) => ListTile(
                          leading: const Icon(Icons.qr_code_2),
                          title: Text(d.name),
                          trailing: settings.barcodePrinterName == d.name
                              ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                              : null,
                          onTap: () {
                            settings.updateBarcodePrinter(d.name);
                            Navigator.pop(context);
                          },
                        )),
                    if (devices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(child: Text('Printerlar topilmadi', style: TextStyle(color: Colors.grey))),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showCloudDialog(BuildContext context, SyncProvider sync) {
    // Capture parent context BEFORE dialog opens
    final parentContext = context;
    showDialog(
      context: context,
      builder: (dialogCtx) => Consumer<SyncProvider>(
        builder: (dialogCtx2, sync, child) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(Icons.cloud_sync_rounded, color: Theme.of(dialogCtx2).colorScheme.primary),
              const SizedBox(width: 12),
              const Text('Ma\'lumotlar zaxirasi'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sync.lastCloudSync != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Oxirgi sinxronizatsiya: ${sync.lastCloudSync!.toString().substring(0, 16)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ),
              if (sync.isSyncingCloud)
                 Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(sync.syncingStage.isNotEmpty ? sync.syncingStage : 'Sinxronizatsiya kutilmoqda...', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                )
              else ...[
                const Text('🔥 Bulutli xizmat (Cloud)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      shadowColor: Colors.blue.withOpacity(0.3),
                    ),
                    icon: const Icon(Icons.sync_rounded, size: 24),
                    label: const Text(
                      'Sinxronizatsiya qilish', 
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                    ),
                    onPressed: () => sync.performFullSync(parentContext),
                  ),
                ),
                const SizedBox(height: 24),

                // Section: Local File
                const Text('📁 Lokal fayl (Excel emas, Baza)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.file_open_rounded, size: 18),
                        label: const Text('Fayldan tiklash', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final confirm = await _showConfirmDialog(parentContext, 'Fayldan tiklash joriy ma\'lumotlarni butunlay O\'CHIRIB yuboradi. Davom etasizmi?');
                          if (confirm == true) {
                            try {
                               await sync.importDatabaseFromFile();
                               if (parentContext.mounted) {
                                 await parentContext.read<AppState>().loadSettings();
                                 await parentContext.read<AuthProvider>().loadAuth();
                                 await parentContext.read<SettingsProvider>().loadSettings();
                                 await parentContext.read<InventoryProvider>().reloadData();
                                 await parentContext.read<SalesProvider>().reloadSalesData();
                                 ScaffoldMessenger.of(parentContext).showSnackBar(const SnackBar(content: Text('✅ Fayldan muvaffaqiyatli tiklandi!'), backgroundColor: Colors.green));
                               }
                            } catch (e) {
                               if (parentContext.mounted) ScaffoldMessenger.of(parentContext).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade50,
                          foregroundColor: Colors.orange.shade900,
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: const Text('Faylga saqlash', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          try {
                             await sync.exportDatabaseToFile();
                             if (parentContext.mounted) ScaffoldMessenger.of(parentContext).showSnackBar(const SnackBar(content: Text('✅ Fayl saqlandi!'), backgroundColor: Colors.green));
                          } catch (e) {
                             if (parentContext.mounted) ScaffoldMessenger.of(parentContext).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            if (!sync.isSyncingCloud)
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx2),
                child: const Text('Yopish'),
              ),
          ],
        ),
      ),
    );
  }


  Future<bool?> _showConfirmDialog(BuildContext context, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Diqqat!'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Yo\'q')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Ha, davom etilsin'),
          ),
        ],
      ),
    );
  }

  void _showEditOrgInfoDialog(BuildContext context, AuthProvider auth, SettingsProvider settings, {required String field}) {
    if (auth.currentUser?.role != UserRole.admin) return;

    String title = '';
    String label = '';
    String initialValue = '';
    
    if (field == 'name') {
      title = 'Tashkilot nomini tahrirlash';
      label = 'Nomi';
      initialValue = settings.organizationName ?? '';
    } else if (field == 'address') {
      title = 'Tashkilot manzilini tahrirlash';
      label = 'Manzil';
      initialValue = settings.organizationAddress ?? '';
    } else if (field == 'instagram') {
      title = 'Instagram foydalanuvchi nomini kiritish';
      label = 'Foydalanuvchi nomi (@ siz)';
      initialValue = settings.instagramUsername ?? '';
    }

    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = controller.text.trim();
              Navigator.pop(context);
              if (field == 'name') {
                await settings.updateOrganizationInfo(name: val);
              } else if (field == 'address') {
                await settings.updateOrganizationInfo(address: val);
              } else if (field == 'instagram') {
                await settings.updateOrganizationInfo(instagram: val);
              }
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }


  void _checkUpdate(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final updateData = await UpdateService.checkUpdate();
    if (context.mounted) Navigator.pop(context);

    if (updateData != null) {
      if (context.mounted) {
        _showUpdateDialog(
          context, 
          updateData['version'], 
          updateData['url'],
          changelog: updateData['changelog'],
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sizda eng oxirgi versiya o\'rnatilgan.')),
        );
      }
    }
  }

  void _showUpdateDialog(BuildContext context, String version, String url, {String? changelog}) {
    AppUpdateDialog.show(context, version, url, changelog: changelog);
  }

  void _showReceiptWidthPicker(BuildContext context, SettingsProvider settings) {
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
            const Text(
              'Chek o\'lchamini tanlang',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.straighten),
              title: const Text('58 mm'),
              trailing: settings.receiptWidth == 58
                  ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                settings.updateReceiptSettings(width: 58);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.straighten),
              title: const Text('80 mm'),
              trailing: settings.receiptWidth == 80
                  ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                settings.updateReceiptSettings(width: 80);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRegisterPicker(BuildContext context, SettingsProvider settings) {
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
            const Text(
              'Kassa terminalini tanlang',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            if (settings.registers.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('Kassalar topilmadi. Avval kassa qo\'shing.'),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: settings.registers.length,
                  itemBuilder: (context, index) {
                    final reg = settings.registers[index];
                    final isSelected = settings.currentRegister?.id == reg.id;
                    return ListTile(
                      leading: Icon(Icons.point_of_sale_rounded, 
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
                      title: Text(reg.name),
                      subtitle: Text('ID: ${reg.id}'),
                      trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
                      onTap: () {
                        settings.updateCurrentRegister(reg);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${reg.name} tanlandi'), backgroundColor: Colors.green),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showThemePicker(BuildContext context, SettingsProvider settings) {
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
            const Text(
              'Mavzuni tanlang',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.brightness_auto_rounded),
              title: const Text('Tizim rejimi'),
              trailing: settings.themeMode == ThemeMode.system ? const Icon(Icons.check_circle, color: Colors.blue) : null,
              onTap: () {
                settings.setThemeMode(ThemeMode.system);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.light_mode_rounded),
              title: const Text('Yorug\' rejim'),
              trailing: settings.themeMode == ThemeMode.light ? const Icon(Icons.check_circle, color: Colors.blue) : null,
              onTap: () {
                settings.setThemeMode(ThemeMode.light);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode_rounded),
              title: const Text('Tungi rejim'),
              trailing: settings.themeMode == ThemeMode.dark ? const Icon(Icons.check_circle, color: Colors.blue) : null,
              onTap: () {
                settings.setThemeMode(ThemeMode.dark);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
