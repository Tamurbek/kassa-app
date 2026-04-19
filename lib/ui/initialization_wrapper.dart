import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/update_service.dart';
import 'dialogs/app_update_dialog.dart';
import '../providers/app_state.dart';
import '../providers/features/auth_provider.dart';
import '../providers/features/settings_provider.dart';
import '../providers/features/sales_provider.dart';
import '../providers/features/navigation_provider.dart';
import '../models/models.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import 'screens/setup_screen.dart';
import 'screens/activation_screen.dart';
import 'screens/login_screen.dart';
import 'main_layout.dart';

class InitializationWrapper extends StatefulWidget {
  const InitializationWrapper({super.key});

  @override
  State<InitializationWrapper> createState() => _InitializationWrapperState();
}

class _InitializationWrapperState extends State<InitializationWrapper> {
  User? _lastUser;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  void _checkForUpdates() async {
    // 5 second delay to ensure the screen is fully loaded 
    // and don't compete with splashes or setup screens
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted) return;

    try {
      final updateData = await UpdateService.checkUpdate();
      if (updateData != null && mounted) {
        // If checkUpdate returned data, it means a newer version exists.
        // We don't need redundant string comparisons here anymore.
        
        if (!context.mounted) return;
        AppUpdateDialog.show(
          context,
          updateData['version'],
          updateData['url'],
          changelog: updateData['changelog'],
        );
      }
    } catch (e) {
      debugPrint('Professional Update: Error on startup check: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final authProvider = context.watch<AuthProvider>();

    // State preservation across logins is now enabled by default. 
    // The previous user's cart and screen index are maintained in memory 
    // to allow seamless resumption after a timeout or manual lock.
    _lastUser = authProvider.currentUser;

    if (!state.isInitialized || !authProvider.isInitialized) {
      return _buildSplashScreen(context, state);
    }

    if (state.initializationError != null) {
      return _buildErrorScreen(context, state);
    }

    if (state.isMaster == null) {
      return const SetupScreen();
    }

    if (state.isMaster == true && !authProvider.isActivated) {
      return const ActivationScreen();
    }

    if (state.isMaster == true && authProvider.isBlocked) {
      return _buildBlockedScreen(context, authProvider);
    }

    if (authProvider.currentUser == null) {
      return const LoginScreen();
    }

    return const MainLayout();
  }

  Widget _buildBlockedScreen(BuildContext context, AuthProvider auth) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block_rounded, color: Colors.red, size: 80),
            const SizedBox(height: 24),
            const Text(
              'Litsenziya bloklangan',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Ushbu terminal administrator tomonidan bloklangan. Iltimos, to\'lov yoki boshqa masalalar bo\'yicha administratorga murojaat qiling.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => auth.checkBlockingStatus(),
              child: const Text('Qayta tekshirish'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplashScreen(BuildContext context, AppState state) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius * 2),
                child: Container(
                  width: 96,
                  height: 96,
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  child: Image.asset(
                    'assets/icon.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                AppConstants.appName,
                style: GoogleFonts.outfit(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'PROFESSIONAL POS SYSTEM',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.4),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'v${state.appVersion}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              const SizedBox(height: 64),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(BuildContext context, AppState state) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.report_gmailerrorred_rounded,
                  color: Colors.redAccent,
                  size: 64,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "Ishga tushishda xatolik",
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                state.initializationError ?? "Dastur ma'lumotlarini yuklab bo'lmadi. Iltimos, qayta urinib ko'ring.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.6),
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => state.retryInitialization(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(
                    'Qayta urinish',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => state.resetTerminalMode(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white.withOpacity(0.7),
                    side: BorderSide(color: Colors.white.withOpacity(0.1)),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    ),
                  ),
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text(
                    'Dasturni qayta sozlash',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
