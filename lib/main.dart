import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/app_state.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/pos_screen.dart';
import 'ui/screens/warehouse_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/catalog_screen.dart';
import 'ui/screens/setup_screen.dart';
import 'ui/screens/employee_screen.dart';
import 'ui/screens/sales_history_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/trash_screen.dart';
import 'ui/screens/activation_screen.dart';
import 'ui/screens/returns_history_screen.dart';
import 'ui/screens/write_offs_history_screen.dart';
import 'models/models.dart';
import 'services/system_tray_service.dart';
import 'services/single_instance_service.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure only one instance is running
  await SingleInstanceService().ensureSingleInstance();

  // Initialize system tray and window management for Desktop
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    await SystemTrayService().init();
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const SimpleSaleApp(),
    ),
  );
}

class SimpleSaleApp extends StatelessWidget {
  const SimpleSaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return MaterialApp(
      title: 'Simple Sale POS',
      debugShowCheckedModeBanner: false,
      themeMode: state.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(
          0xFFF8F9FA,
        ), // Clean, professional light grey
        cardColor: Colors.white,
        dividerColor: const Color(0xFFE9ECEF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D2D2D), // Neutral primary
          primary: const Color(0xFF4F46E5),
          onPrimary: Colors.white,
          surface: const Color(0xFFF8F9FA),
          onSurface: const Color(0xFF212529),
          background: const Color(0xFFF8F9FA),
          onBackground: const Color(0xFF212529),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
        cardTheme: CardThemeData(
          elevation: 0, // Flat design with slim borders like in the image
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              4,
            ), // Slightly more square/professional
            side: const BorderSide(color: Color(0xFFE9ECEF)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF2D2D2D),
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF2D2D2D)),
          titleTextStyle: TextStyle(
            color: Color(0xFF2D2D2D),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A), // Deep charcoal black
        cardColor: const Color(
          0xFF262626,
        ), // Slightly lighter charcoal for layers
        dividerColor: Colors.white.withOpacity(0.08),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF818CF8),
          brightness: Brightness.dark,
          primary: const Color(
            0xFF818CF8,
          ), // Brighter indigo for actions and prices
          onPrimary: Colors.white,
          surface: const Color(0xFF1A1A1A),
          onSurface: const Color(0xFFE9ECEF),
          background: const Color(0xFF1A1A1A),
          onBackground: const Color(0xFFE9ECEF),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF262626),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const InitializationWrapper(),
    );
  }
}

class InitializationWrapper extends StatefulWidget {
  const InitializationWrapper({super.key});

  @override
  State<InitializationWrapper> createState() => _InitializationWrapperState();
}

class _InitializationWrapperState extends State<InitializationWrapper> {
  User? _lastUser;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // If user was logged in and now is not, clear any open dialogs/screens
    if (_lastUser != null && state.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }
    _lastUser = state.currentUser;

    if (!state.isInitialized) {
      return _buildSplashScreen(context, state);
    }

    if (state.initializationError != null) {
      return _buildErrorScreen(context, state);
    }

    if (state.isMaster == null) {
      return const SetupScreen();
    }

    if (state.isMaster == true && !state.isActivated) {
      return const ActivationScreen();
    }

    if (state.isMaster == true && state.isBlocked) {
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
                onPressed: () => state.checkBlockingStatus(),
                child: const Text('Qayta tekshirish'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.currentUser == null) {
      return const LoginScreen();
    }

    return const MainLayout();
  }

  Widget _buildSplashScreen(BuildContext context, AppState state) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/icon.png',
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'SimpleSale',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Savdo tizimini tayyorlamoqda...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: Color(0xFF6366F1),
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(BuildContext context, AppState state) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orangeAccent,
                  size: 56,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Ishga tushishda xatolik",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Dastur ma'lumotlarini yuklab bo'lmadi. Internet yoki mahalliy tarmoq ulanishini tekshiring.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.55),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => state.retryInitialization(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.settings_backup_restore_rounded),
                  label: const Text(
                    'Boshlang\'ich sozlamalarga qaytish',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _inactivityTimer;
  static const inactivityTimeout = Duration(minutes: 5);

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(inactivityTimeout, () {
      if (mounted) {
        context.read<AppState>().logout();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _resetInactivityTimer();
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
    // Cashier can only access POS (0) and Settings (7)
    return index == 0 || index == 7;
  }

  @override
  Widget build(BuildContext context) {
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
          endDrawer: Drawer(width: 250, child: _buildSidebar(false)),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 700;
              final isMedium =
                  constraints.maxWidth >= 700 && constraints.maxWidth < 1200;

              // Disable permanent sidebar everywhere, just like POS
              const bool showPermanentSidebar = false;

              final state = context.watch<AppState>();
              return Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (showPermanentSidebar) _buildSidebar(isMedium),
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
                  _buildStatusFooter(state),
                  if (isSmall) _buildBottomNav(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFooter(AppState state) {
    if (state.isMaster == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: state.isMaster == true
                  ? Colors.blue
                  : (state.isConnected ? Colors.green : Colors.red),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (state.isMaster == true
                          ? Colors.blue
                          : (state.isConnected ? Colors.green : Colors.red))
                      .withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            state.isMaster == true
                ? 'Asosiy terminal (Master)'
                : (state.isConnected
                    ? 'Asosiy terminalga ulangan'
                    : 'Asosiy terminal bilan aloqa yo\'q'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: state.isMaster == true
                  ? Colors.blue
                  : (state.isConnected ? Colors.green : Colors.red),
            ),
          ),
          const SizedBox(width: 16),
          const VerticalDivider(width: 1, thickness: 1, indent: 4, endIndent: 4),
          const SizedBox(width: 16),
          Icon(
            Icons.person_outline_rounded,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 6),
          Text(
            'Hodim: ${state.currentUser?.name ?? 'Noma\'lum'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const Spacer(),
          if (state.isMaster == false && state.masterAddress != null) ...[
            Text(
              'IP: ${state.masterAddress}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 16),
          ],
          IconButton(
            icon: Icon(
              Icons.logout_rounded,
              size: 18,
              color: Colors.grey.shade500,
            ),
            onPressed: () => state.logout(),
            tooltip: 'Chiqish',
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
          if (state.isMaster == false && state.masterAddress != null) ...[
            const SizedBox(width: 16),
            InkWell(
              onTap: () async {
                try {
                  await state.syncWithMaster();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ma\'lumotlar yangilandi')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Xatolik: $e')),
                  );
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sync_rounded,
                      size: 16,
                      color: state.isConnected ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Yangilash',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: state.isConnected ? Colors.green : Colors.grey,
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

  Widget _buildSidebar(bool slim) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: slim ? 80 : 250,
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          _buildLogo(slim),
          _buildThemeToggle(slim),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(
                  0,
                  Icons.shopping_cart_outlined,
                  Icons.shopping_cart_rounded,
                  'Sotuv',
                  slim,
                ),
                if (_canAccess(1, state.currentUser?.role))
                  _buildNavItem(
                    1,
                    Icons.grid_view_outlined,
                    Icons.grid_view_rounded,
                    'Dashboard',
                    slim,
                  ),
                if (_canAccess(2, state.currentUser?.role))
                  _buildNavItem(
                    2,
                    Icons.history_rounded,
                    Icons.history_rounded,
                    'Sotuvlar Tarixi',
                    slim,
                  ),
                if (_canAccess(3, state.currentUser?.role))
                  _buildNavItem(
                    3,
                    Icons.inventory_2_outlined,
                    Icons.inventory_2_rounded,
                    'Ombor',
                    slim,
                  ),
                if (_canAccess(4, state.currentUser?.role))
                  _buildNavItem(
                    4,
                    Icons.category_outlined,
                    Icons.category_rounded,
                    'Katalog',
                    slim,
                  ),
                if (_canAccess(5, state.currentUser?.role))
                  _buildNavItem(
                    5,
                    Icons.people_outline,
                    Icons.people_rounded,
                    'Hodimlar',
                    slim,
                  ),
                if (_canAccess(6, state.currentUser?.role))
                  _buildNavItem(
                    6,
                    Icons.delete_outline_rounded,
                    Icons.delete_rounded,
                    'Savat',
                    slim,
                  ),
                if (_canAccess(7, state.currentUser?.role))
                  _buildNavItem(
                    7,
                    Icons.settings_outlined,
                    Icons.settings_rounded,
                    'Sozlamalar',
                    slim,
                  ),
                const Divider(),
                if (_canAccess(8, state.currentUser?.role))
                  _buildNavItem(
                    8,
                    Icons.assignment_return_outlined,
                    Icons.assignment_return_rounded,
                    'Vazvratlar',
                    slim,
                  ),
                if (_canAccess(9, state.currentUser?.role))
                  _buildNavItem(
                    9,
                    Icons.remove_circle_outline_rounded,
                    Icons.remove_circle_rounded,
                    'Chiqarishlar',
                    slim,
                  ),
              ],
            ),
          ),
          _buildUserAvatar(slim),
        ],
      ),
    );
  }

  Widget _buildThemeToggle(bool slim) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => state.toggleTheme(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: 10,
            horizontal: slim ? 0 : 16,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: slim
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                color: isDark ? Colors.amber : Colors.blueGrey,
              ),
              if (!slim) const SizedBox(width: 16),
              if (!slim)
                Expanded(
                  child: Text(
                    isDark ? 'Yorug\' rejim' : 'Tungi rejim',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final state = context.watch<AppState>();
    final isAdmin = state.currentUser?.role == UserRole.admin;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex >= (isAdmin ? 8 : 1) ? 0 : _selectedIndex,
        onTap: (index) {
          if (!isAdmin && index > 0) return;
          setState(() => _selectedIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).cardColor,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart_rounded),
            label: 'Sotuv',
          ),
          if (isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: 'Dash',
            ),
          if (isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              activeIcon: Icon(Icons.history_rounded),
              label: 'Tarix',
            ),
          if (isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2_rounded),
              label: 'Ombor',
            ),
          if (isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.category_outlined),
              activeIcon: Icon(Icons.category_rounded),
              label: 'Kat',
            ),
          if (isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.people_outlined),
              activeIcon: Icon(Icons.people_rounded),
              label: 'Hodim',
            ),
          if (isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.delete_outline_rounded),
              activeIcon: Icon(Icons.delete_rounded),
              label: 'Savat',
            ),
          if (isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: 'Soz',
            ),
        ],
      ),
    );
  }

  Widget _buildLogo(bool slim) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/icon.png',
              width: 45,
              height: 45,
              fit: BoxFit.cover,
            ),
          ),
          if (!slim) const SizedBox(width: 12),
          if (!slim)
            const Text(
              'SimpleSale',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
    bool slim,
  ) {
    final isSelected = _selectedIndex == index;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () {
          setState(() => _selectedIndex = index);
          if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
            Navigator.pop(context);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            vertical: 12,
            horizontal: slim ? 0 : 16,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: slim
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? primaryColor : Colors.grey.shade500,
                size: 24,
              ),
              if (!slim) const SizedBox(width: 16),
              if (!slim)
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected ? primaryColor : Colors.grey.shade600,
                    ),
                  ),
                ),
              if (!slim && isSelected)
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(bool slim) {
    final state = context.watch<AppState>();
    final user = state.currentUser;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: EdgeInsets.all(slim ? 8 : 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.shade100,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: primaryColor.withOpacity(0.1),
              child: Text(
                user?.name[0].toUpperCase() ?? '?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
            if (!slim) const SizedBox(width: 12),
            if (!slim)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user?.name ?? 'Tizimda yo\'q',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      user?.role == UserRole.admin ? 'Administrator' : 'Kassir',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            if (!slim)
              IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Colors.grey,
                  size: 18,
                ),
                onPressed: () => state.logout(),
              ),
          ],
        ),
      ),
    );
  }

}
