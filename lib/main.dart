import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import 'providers/app_state.dart';
import 'providers/features/settings_provider.dart';
import 'providers/features/auth_provider.dart';
import 'providers/features/inventory_provider.dart';
import 'providers/features/sales_provider.dart';
import 'providers/features/sync_provider.dart';
import 'ui/initialization_wrapper.dart';
import 'core/theme/app_theme.dart';
import 'services/system_tray_service.dart';
import 'services/single_instance_service.dart';
import 'providers/features/navigation_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure only one instance is running
  await SingleInstanceService().ensureSingleInstance();

  // Initialize system tray and window management for Desktop
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    try {
      await SystemTrayService().init();
    } catch (e) {
      debugPrint('System Tray initialization failed: $e');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => SettingsProvider()..loadSettings(isInitialLoad: true)),
        ChangeNotifierProvider(create: (context) => AuthProvider()..loadAuth()),
        ChangeNotifierProvider(create: (context) => InventoryProvider()..reloadData()),
        ChangeNotifierProvider(create: (context) => SalesProvider()..reloadSalesData()),
        ChangeNotifierProxyProvider<AuthProvider, SyncProvider>(
          create: (context) => SyncProvider(),
          update: (context, auth, sync) {
            sync!.onRemoteLogout = () => auth.performRemoteLogout();
            if (!sync.isInitialized) {
              sync.loadSync();
              sync.isInitialized = true;
            }
            return sync;
          },
        ),
        ChangeNotifierProvider(create: (context) => NavigationProvider()),
        ChangeNotifierProvider(create: (context) => AppState()..loadSettings()),
      ],
      child: const SimpleSaleApp(),
    ),
  );
}

class SimpleSaleApp extends StatelessWidget {
  const SimpleSaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      title: 'Simple Sale POS',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const InitializationWrapper(),
      builder: (context, child) {
        return Container(
          color: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF262626) // Corrected to match darkBg
              : const Color(0xFFF1F5F9), // Slate 100 background for gutters
          child: Center(
            child: child!,
          ),
        );
      },
    );
  }
}
