import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/features/settings_provider.dart';
import '../../providers/features/auth_provider.dart';
import '../../providers/features/sync_provider.dart';
import '../../models/models.dart';
import 'package:simple_sale/core/utils/responsive.dart';

class AppStatusBar extends StatelessWidget {
  final SettingsProvider settings;
  final AuthProvider auth;
  final SyncProvider sync;
  final VoidCallback? onExit;

  const AppStatusBar({
    super.key,
    required this.settings,
    required this.auth,
    required this.sync,
    this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final bool isShort = Responsive.isShort(context);
    return Container(
      height: isShort ? 32.h : 44.h,
      padding: EdgeInsets.symmetric(horizontal: 12.sp),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.15),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Left side: Status indicators
          _buildStatusTag(
            context,
            icon: Icons.circle,
            iconSize: 8,
            iconColor: const Color(0xFF3B82F6), // Professional Blue
            label: settings.currentRegister?.name ?? 'Asosiy terminal (Master)',
            bgColor: const Color(0xFF3B82F6).withOpacity(0.08),
            textColor: const Color(0xFF1E40AF),
          ),
          const SizedBox(width: 10),
          _buildStatusTag(
            context,
            icon: auth.cloudStatus.contains('Bulut') ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            iconColor: auth.cloudStatus.contains('Bulut') ? const Color(0xFF0EA5E9) : Colors.orange,
            label: auth.cloudStatus,
            bgColor: (auth.cloudStatus.contains('Bulut') ? const Color(0xFF0EA5E9) : Colors.orange).withOpacity(0.08),
            textColor: auth.cloudStatus.contains('Bulut') ? const Color(0xFF075985) : Colors.orange.shade900,
          ),
          const SizedBox(width: 16),
          Icon(Icons.person_rounded, size: 16.sp, color: Colors.grey.shade600),
          SizedBox(width: 6.w),
          Text(
            auth.currentUser?.name ?? 'Admin',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              auth.currentUser?.role.toString().split('.').last.toUpperCase() ?? 'ADMIN',
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
          ),

          const Spacer(),

          // Right side: Sync and Quit
          Icon(
            sync.lastCloudSync != null ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, 
            size: 18, 
            color: sync.lastCloudSync != null ? const Color(0xFF3B82F6) : Colors.grey.shade600
          ),
          const SizedBox(width: 6),
          Text(
            'Zaxira: ${sync.lastCloudSync != null ? DateFormat('HH:mm').format(sync.lastCloudSync!) : 'Yo\'q'}',
            style: TextStyle(
              fontSize: 12,
              color: sync.lastCloudSync != null ? const Color(0xFF1E40AF) : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (auth.currentUser?.role == UserRole.admin) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Hozir sinxronlash',
              child: InkWell(
                onTap: sync.isSyncingCloud ? null : () => sync.performFullSync(context),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: sync.isSyncingCloud 
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.sync_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
          ],
          
          const SizedBox(width: 20),
          
          // Lock Screen button
          Tooltip(
            message: 'Ekranni qulflash',
            child: InkWell(
              onTap: onExit, // reuse logout logic as lock
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.lock_outline_rounded, size: 18.sp, color: Colors.blueGrey.shade700),
              ),
            ),
          ),

          if (onExit != null) ...[
            const SizedBox(width: 12),
            InkWell(
              onTap: onExit,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 16.sp, color: const Color(0xFFEF4444)), // Red 500
                    SizedBox(width: 6.w),
                    Text(
                      'Chiqish',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusTag(BuildContext context, {
    required IconData icon,
    double? iconSize,
    required Color iconColor,
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    final bool isShort = Responsive.isShort(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.sp, vertical: isShort ? 2.h : 6.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20.sp),
        border: Border.all(color: iconColor.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize != null ? iconSize.sp : 14.sp, color: iconColor),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
