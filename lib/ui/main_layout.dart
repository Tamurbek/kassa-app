import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../providers/features/auth_provider.dart';
import '../providers/features/settings_provider.dart';
import '../providers/features/inventory_provider.dart';
import '../providers/features/sales_provider.dart';
import '../providers/features/sync_provider.dart';
import '../models/models.dart';
import '../services/update_service.dart';
import 'dialogs/app_update_dialog.dart';
import '../providers/app_state.dart';
import 'screens/dashboard_screen.dart';
import 'screens/pos_screen.dart';
import 'screens/warehouse_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/employee_screen.dart';
import 'screens/sales_history_screen.dart';
import 'screens/trash_screen.dart';
import 'screens/returns_history_screen.dart';
import 'screens/write_offs_history_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  ThemeData get theme => Theme.of(context);
  bool get isDark => theme.brightness == Brightness.dark;

  Timer? _inactivityTimer;
  static const inactivityTimeout = Duration(minutes: 5);

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(inactivityTimeout, () {
      if (mounted) {
        context.read<AuthProvider>().logout();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _resetInactivityTimer();
    _checkForUpdates();
  }

  void _checkForUpdates() async {
    // Small delay to ensure navigator is ready
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    try {
      final updateData = await UpdateService.checkUpdate();
      if (updateData != null && mounted) {
        if (context.mounted) {
           AppUpdateDialog.show(
            context,
            updateData['version'],
            updateData['url'],
            changelog: updateData['changelog'],
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  List<Widget> get _screens => [
        POSScreen(onMenuPressed: () => _scaffoldKey.currentState?.openEndDrawer()),
        DashboardScreen(
          onMenuPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
        ),
        SalesHistoryScreen(
          onMenuPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
        ),
        WarehouseScreen(
          onMenuPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
        ),
        CatalogScreen(
          onMenuPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
        ),
        EmployeeScreen(
          onMenuPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
        ),
        TrashScreen(
          onMenuPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
        ),
        SettingsScreen(
          onMenuPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
        ),
        ReturnsHistoryScreen(
          onMenuPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
        ),
        WriteOffsHistoryScreen(
          onMenuPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
        ),
      ];

  bool _canAccess(int index, UserRole? role) {
    if (role == UserRole.admin) return true;
    return index == 0 || index == 7;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final sync = context.watch<SyncProvider>();
    
    return Listener(
      onPointerDown: (_) => _resetInactivityTimer(),
      onPointerMove: (_) => _resetInactivityTimer(),
      behavior: HitTestBehavior.translucent,
      child: Focus(
        onKeyEvent: (node, event) {
          _resetInactivityTimer();
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          key: _scaffoldKey,
          endDrawer: Drawer(width: 280, child: _buildSidebar(context, auth, settings, sync, false)),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 700;
              final isMedium =
                  constraints.maxWidth >= 700 && constraints.maxWidth < 1200;

              const bool showPermanentSidebar = false;

              return Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (showPermanentSidebar) _buildSidebar(context, auth, settings, sync, isMedium),
                        if (showPermanentSidebar)
                          const VerticalDivider(
                            thickness: 1,
                            width: 1,
                            color: Color(0xFFF1F5F9),
                          ),
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1400),
                              child: IndexedStack(
                                index: _selectedIndex,
                                children: _screens,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                        child: _buildStatusFooter(context, auth, settings, sync),
                    ),
                  ),
                  if (isSmall) _buildBottomNav(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, AuthProvider auth, SettingsProvider settings, SyncProvider sync, bool isMedium) {
    final Map<int, String> titles = {
      0: 'Savdo bo\'limi (POS)',
      1: 'Statistika (Dashboard)',
      2: 'Sotuvlar tarixi',
      3: 'Omborxona',
      4: 'Katalog va Mahsulotlar',
      5: 'Sotuvchilar (Xodimlar)',
      8: 'Qaytarilgan tovarlar',
      9: 'Spisaniya tarixi',
      6: 'Chiqitlar (Savatcha)',
      7: 'Sozlamalar',
    };

    final Map<int, IconData> icons = {
      0: Icons.point_of_sale_rounded,
      1: Icons.dashboard_customize_rounded,
      2: Icons.history_rounded,
      3: Icons.inventory_2_rounded,
      4: Icons.category_rounded,
      5: Icons.people_alt_rounded,
      8: Icons.keyboard_return_rounded,
      9: Icons.remove_circle_outline_rounded,
      6: Icons.auto_delete_rounded,
      7: Icons.settings_suggest_rounded,
    };

    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: isDark ? AppTheme.darkBg : Colors.white,
      child: Column(
        children: [
          _buildSidebarHeader(isMedium, settings, isDark),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                ...titles.entries.where((e) => _canAccess(e.key, auth.currentUser?.role)).map((e) {
                  final isSelected = _selectedIndex == e.key;
                  return _buildSidebarItem(
                    e.key,
                    e.value,
                    icons[e.key]!,
                    isSelected,
                    isMedium,
                    isDark,
                  );
                }),
              ],
            ),
          ),
          _buildSidebarFooter(isMedium, isDark),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(bool isCollapsed, SettingsProvider settings, bool isDark) {
    return Container(
      padding: EdgeInsets.all(isCollapsed ? 12 : 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightBg,
        border: Border(
            bottom: BorderSide(
                color: theme.dividerColor.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment:
            isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shopping_bag_rounded,
                color: Colors.white, size: 20),
          ),
          if (!isCollapsed) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppConstants.appName,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    settings.organizationName ?? 'Savdo Tizimi',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                settings.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 20,
              ),
              onPressed: () {
                if (settings.themeMode == ThemeMode.dark) {
                  settings.setThemeMode(ThemeMode.light);
                } else {
                  settings.setThemeMode(ThemeMode.dark);
                }
              },
              tooltip: 'Mavzuni almashtirish',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, String title, IconData icon,
      bool isSelected, bool isCollapsed, bool isDark) {
    final theme = Theme.of(context);
    final Color activeColor = AppTheme.primaryColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () {
          setState(() => _selectedIndex = index);
          if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
            Navigator.pop(context);
          }
        },
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: 12, vertical: isCollapsed ? 12 : 10),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withOpacity(isDark ? 0.15 : 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            border: Border.all(
              color: isSelected && !isDark
                  ? activeColor.withOpacity(0.12)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.grey[400] : AppColors.slateGrey),
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? activeColor
                          : theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter(bool isCollapsed, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.1))),
      ),
      child: isCollapsed
          ? const Icon(Icons.bolt, color: Colors.amber, size: 18)
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.bolt, color: Colors.amber, size: 14),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Premium Version',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFooterInfoItem(BuildContext context, {required IconData icon, required String label, bool isDark = false, bool isMono = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.grey[500] : Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[300] : Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildFooterBadge(String label, {bool isDark = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFooterActionButton(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap, bool isActive = true, bool isLoading = false, bool isDark = false, bool isDanger = false}) {
    final Color color = isDanger ? Colors.red : (isDark ? Colors.grey[300]! : Colors.grey[800]!);
    
    return InkWell(
      onTap: isActive && !isLoading ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFooter(BuildContext context, AuthProvider auth, SettingsProvider settings, SyncProvider sync) {
    if (sync.isMaster == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color statusColor = sync.isMaster == true
        ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
        : (sync.isConnected
            ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))
            : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(isDark ? 0.08 : 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  sync.isMaster == true
                      ? 'Asosiy terminal (Master)'
                      : (sync.isConnected
                          ? 'Asosiy terminalga ulangan'
                          : 'Aloqa yo\'q'),
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Professional Cloud Sync Status
          if (auth.isActivated && auth.currentUser?.role == UserRole.admin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Icon(
                     auth.cloudStatus.contains('Bulut') ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                     size: 12, 
                     color: auth.cloudStatus.contains('Bulut') ? Colors.blue : Colors.orange,
                   ),
                   const SizedBox(width: 6),
                   Text(
                     'Cloud: ${auth.cloudStatus}',
                     style: TextStyle(
                       fontSize: 10,
                       fontWeight: FontWeight.w700,
                       color: auth.cloudStatus.contains('Bulut') ? Colors.blue[isDark ? 300 : 700] : Colors.orange[isDark ? 300 : 700],
                     ),
                   ),
                ],
              ),
            ),
          const SizedBox(width: 24),
          _buildFooterInfoItem(
            context,
            icon: Icons.person_rounded,
            label: '${auth.currentUser?.name ?? 'Noma\'lum'}',
            isDark: isDark,
          ),
          if (auth.currentUser?.role != null) ...[
            const SizedBox(width: 16),
            _buildFooterBadge(
              auth.currentUser!.role == UserRole.admin ? 'Admin' : 'Sotuvchi',
              isDark: isDark,
            ),
          ],
          const Spacer(),
          if (sync.lastCloudSync != null)
            _buildFooterInfoItem(
              context,
              icon: Icons.access_time_rounded,
              label: 'Oxirgi sync: ${intl.DateFormat('HH:mm').format(sync.lastCloudSync!)}',
              isDark: isDark,
            ),
          if (auth.currentUser?.role == UserRole.admin) ...[
            const SizedBox(width: 12),
            _buildFooterActionButton(
              context,
              icon: Icons.cloud_outlined,
              label: 'Bulutli xizmat',
              onTap: () => _showCloudSyncDialog(context, sync),
              isActive: auth.isActivated,
              isLoading: sync.isSyncingCloud,
              isDark: isDark,
            ),
          ],
          const SizedBox(width: 8),
          if (sync.isMaster == false && sync.masterAddress != null) ...[
             _buildFooterActionButton(
              context,
              icon: Icons.sync_rounded,
              label: 'Yangilash',
              onTap: () async {
                try {
                  await sync.syncWithMaster();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ma\'lumotlar yangilandi')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Xatolik: $e')),
                  );
                }
              },
              isActive: sync.isConnected,
              isDark: isDark,
            ),
            const SizedBox(width: 12),
          ],
          _buildFooterActionButton(
            context,
            icon: Icons.logout_rounded,
            label: 'Chiqish',
            onTap: () => auth.logout(),
            isActive: true,
            isDark: isDark,
            isDanger: true,
          ),
        ],
      ),
    );
  }

  void _confirmRestoreFromCloud(BuildContext context, SyncProvider sync) {
    // Capture parent context BEFORE showing dialog
    final parentContext = context;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(dialogCtx).cardColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Diqqat!'),
        content: const Text(
          'Bulutdan zaxirani tiklash joriq barcha ma\'lumotlaringizni o\'chirib yuborada va bulutdagi nusqa bilan almashtiradi. Davom etasizmi?',
          style: TextStyle(color: Colors.redAccent),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx); // close confirm dialog
              try {
                await sync.restoreDatabaseFromCloud();
                
                // Use parentContext (still valid, part of main layout tree)
                if (parentContext.mounted) {
                  // Show loading snackbar while reloading
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          SizedBox(width: 12),
                          Text('Ma\'lumotlar yangilanmoqda...'),
                        ],
                      ),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  
                  // Reload all providers with parent context
                  await parentContext.read<AppState>().loadSettings();
                  await parentContext.read<AuthProvider>().loadAuth();
                  await parentContext.read<SettingsProvider>().loadSettings();
                  await parentContext.read<InventoryProvider>().reloadData();
                  await parentContext.read<SalesProvider>().reloadSalesData();
                  
                  if (parentContext.mounted) {
                    ScaffoldMessenger.of(parentContext).hideCurrentSnackBar();
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Ma\'lumotlar bulutdan muvaffaqiyatli tiklandi!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (parentContext.mounted) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Ha, Tiklash'),
          ),
        ],
      ),
    );
  }

  void _showCloudSyncDialog(BuildContext context, SyncProvider sync) {
    // CRITICAL: capture main layout context BEFORE dialog opens.
    // Builder callbacks rebind 'context' to the dialog's context,
    // which becomes invalid after Navigator.pop(). We need the parent context
    // to reload providers correctly after restore.
    final mainContext = context;

    showDialog(
      context: mainContext,
      builder: (dialogCtx) => Consumer<SyncProvider>(
        builder: (_, sync, __) => AlertDialog(
          backgroundColor: Theme.of(dialogCtx).cardColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.cloud_sync_rounded, color: Colors.blue),
              SizedBox(width: 12),
              Text('Ma\'lumotlar zaxirasi'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sync.lastCloudSync != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Oxirgi sinxronizatsiya: ${intl.DateFormat('yyyy-MM-dd HH:mm').format(sync.lastCloudSync!)}',
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
                    onPressed: () => sync.performFullSync(mainContext),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bu tugma barcha terminalardagi o\'zgarishlarni birlashtiradi va saqlaydi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ],
          ),
          actions: [
            if (!sync.isSyncingCloud)
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Yopish'),
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex % 4, // simplistic
      onTap: (index) => setState(() => _selectedIndex = index),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'POS'),
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Stats'),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Sotuvlar'),
        BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Ombor'),
      ],
    );
  }
}
