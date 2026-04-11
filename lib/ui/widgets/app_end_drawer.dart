import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/features/auth_provider.dart';
import '../../providers/features/settings_provider.dart';
import '../../providers/features/sync_provider.dart';
import '../../models/models.dart';

class AppEndDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onIndexChanged;
  final bool isMedium;

  const AppEndDrawer({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
    this.isMedium = false,
  });

  bool _canAccess(int index, UserRole? role) {
    if (role == UserRole.admin) return true;
    // Standard access logic: Savdo Bo'limi (0), POS (1) and Settings (8) for sellers
    return index == 0 || index == 1 || index == 8;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Map<int, String> titles = {
      0: 'Savdo Bo\'limi',
      1: 'Savdo (POS)',
      2: 'Dashboard',
      3: 'Savdo Tarixi',
      4: 'Ombor',
      5: 'Katalog',
      6: 'Hodimlar',
      7: 'Savat',
      8: 'Sozlamalar',
      9: 'Qaytaruvlar',
      10: 'Chiqitlar',
    };

    final Map<int, IconData> icons = {
      0: Icons.timer_rounded,
      1: Icons.point_of_sale_rounded,
      2: Icons.dashboard_rounded,
      3: Icons.history_rounded,
      4: Icons.inventory_2_rounded,
      5: Icons.category_rounded,
      6: Icons.people_rounded,
      7: Icons.delete_outline_rounded,
      8: Icons.settings_rounded,
      9: Icons.assignment_return_rounded,
      10: Icons.remove_shopping_cart_rounded,
    };

    return Container(
      color: isDark ? AppTheme.darkSurface : Colors.white,
      child: Column(
        children: [
          _buildHeader(context, settings, isDark),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                ...titles.entries
                    .where((e) => _canAccess(e.key, auth.currentUser?.role))
                    .map((e) {
                  final isSelected = selectedIndex == e.key;
                  return _buildItem(
                    context,
                    e.key,
                    e.value,
                    icons[e.key]!,
                    isSelected,
                    isDark,
                  );
                }),
              ],
            ),
          ),
          _buildFooter(context, isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SettingsProvider settings, bool isDark) {
    return Container(
      padding: EdgeInsets.all(isMedium ? 12 : 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightBg,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: isMedium ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 20),
          ),
          if (!isMedium) ...[
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
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index, String title, IconData icon, bool isSelected, bool isDark) {
    final Color activeColor = AppTheme.primaryColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => onIndexChanged(index),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: isMedium ? 12 : 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(isDark ? 0.15 : 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            border: Border.all(
              color: isSelected && !isDark ? activeColor.withOpacity(0.12) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: isMedium ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? activeColor : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
              ),
              if (!isMedium) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? activeColor : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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

  Widget _buildFooter(BuildContext context, bool isDark) {
    final settings = context.watch<SettingsProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: Colors.amber, size: 14),
              const SizedBox(width: 8),
              if (!isMedium)
                const Text(
                  'Premium',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.amber,
                  ),
                ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  settings.isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  size: 20,
                  color: settings.isFullScreen ? Colors.green : Colors.blueGrey,
                ),
                onPressed: () => settings.toggleFullScreen(),
                tooltip: settings.isFullScreen ? 'Oynali rejim' : 'Butun ekran',
              ),
              IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  size: 20,
                  color: isDark ? Colors.amber : Colors.blueGrey,
                ),
                onPressed: () {
                  settings.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
                },
                tooltip: isDark ? 'Yorug\' rejim' : 'Tungi rejim',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
