import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../providers/features/settings_provider.dart';
import '../../providers/features/auth_provider.dart';

class AppStatusBar extends StatelessWidget {
  final SettingsProvider settings;
  final AuthProvider auth;
  final VoidCallback? onExit;

  const AppStatusBar({
    super.key,
    required this.settings,
    required this.auth,
    this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
            icon: Icons.cloud_done_rounded,
            iconColor: const Color(0xFF0EA5E9), // Sky Blue
            label: 'Bulutga ulandi',
            bgColor: const Color(0xFF0EA5E9).withOpacity(0.08),
            textColor: const Color(0xFF075985),
          ),
          const SizedBox(width: 16),
          Icon(Icons.person_rounded, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            auth.currentUser?.name ?? 'Admin',
            style: TextStyle(
              fontSize: 13,
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
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
          ),

          const Spacer(),

          // Right side: Sync and Quit
          Icon(Icons.history_rounded, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            'Oxirgi sync: ${DateFormat('HH:mm').format(DateTime.now())}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 20),
          Icon(Icons.cloud_outlined, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            'Bulutli xizmat',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          if (onExit != null) ...[
            const SizedBox(width: 28),
            InkWell(
              onTap: onExit,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFEF4444)), // Red 500
                    const SizedBox(width: 6),
                    Text(
                      'Chiqish',
                      style: TextStyle(
                        fontSize: 13,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize ?? 15, color: iconColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
