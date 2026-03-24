import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/sync_service.dart';
import '../services/database_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppState extends ChangeNotifier {
  List<Warehouse> warehouses = [];
  List<Register> registers = [];
  List<Category> categories = [];
  List<Product> products = [];
  List<StockEntry> stockEntries = [];
  List<User> users = [];
  List<Sale> sales = [];
  List<SaleReturn> returns = [];
  List<WriteOff> writeOffs = [];
  List<InventoryEntry> inventories = [];
  User? currentUser;
  String? masterPassword;

  Register? currentRegister;
  List<SaleItem> cart = [];
  String? selectedPrinterName;
  String? barcodePrinterName;
  String? networkPrinterIp;
  String? networkBarcodePrinterIp;
  int receiptWidth = 80; // 58 or 80
  String receiptFooterText = 'Xaridingiz uchun rahmat!';
  bool showLogoOnReceipt = true;
  bool showInstagramOnReceipt = true;

  bool? isMaster;
  String? masterAddress;
  String? deviceId;
  bool isInitialized = false;
  String? initializationError;
  bool isActivated = false;
  bool isBlocked = false;
  String? activationCode;
  String? organizationName;
  String? organizationAddress;
  String? instagramUsername;
  String? organizationLogoPath;
  Timer? _syncTimer;
  WebSocketChannel? _wsChannel;
  Timer? _wsPingTimer;
  bool _isConnectingWs = false;
  bool _isConnected = false;
  bool get isConnected => isMaster == true ? true : _isConnected;
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool _isBarcodeScanMode = false;
  bool get isBarcodeScanMode => _isBarcodeScanMode;
  bool _showProductImages = true;
  bool get showProductImages => _showProductImages;
  String appVersion = '1.10.0';

  double get todaySalesTotal {
    final now = DateTime.now();
    return sales
        .where(
          (s) =>
              s.date.year == now.year &&
              s.date.month == now.month &&
              s.date.day == now.day,
        )
        .fold(0.0, (sum, s) => sum + s.total);
  }

  double get todayProfitTotal {
    final now = DateTime.now();
    return sales
        .where(
          (s) =>
              s.date.year == now.year &&
              s.date.month == now.month &&
              s.date.day == now.day,
        )
        .fold(0.0, (sum, s) => sum + s.items.fold(0.0, (iSum, item) => iSum + item.profit));
  }

  int get todaySalesCount {
    final now = DateTime.now();
    return sales
        .where(
          (s) =>
              s.date.year == now.year &&
              s.date.month == now.month &&
              s.date.day == now.day,
        )
        .length;
  }

  double get averageCheck {
    final count = todaySalesCount;
    return count == 0 ? 0 : todaySalesTotal / count;
  }

  List<MapEntry<String, double>> get topSellingProducts {
    final now = DateTime.now();
    final todaySales = sales.where(
      (s) =>
          s.date.year == now.year &&
          s.date.month == now.month &&
          s.date.day == now.day,
    );

    final Map<String, double> topMap = {};
    for (var sale in todaySales) {
      for (var item in sale.items) {
        topMap[item.productName] =
            (topMap[item.productName] ?? 0.0) + item.quantity;
      }
    }

    final sorted = topMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).toList();
  }

  // Active items (not deleted)
  List<Category> get activeCategories =>
      categories.where((c) => !c.isDeleted).toList();
  List<Product> get activeProducts =>
      products.where((p) => !p.isDeleted).toList();
  List<User> get activeUsers => users.where((u) => !u.isDeleted).toList();

  // Deleted items (Trash)
  List<Category> get deletedCategories =>
      categories.where((c) => c.isDeleted).toList();
  List<Product> get deletedProducts =>
      products.where((p) => p.isDeleted).toList();
  List<User> get deletedUsers => users.where((u) => u.isDeleted).toList();

  Future<String?> get localIp async {
    try {
      final interfaces = await NetworkInterface.list();
      List<String> allIps = [];

      for (var interface in interfaces) {
        // Skip common virtual/docker interfaces
        if (interface.name.contains('utun') ||
            interface.name.contains('docker') ||
            interface.name.contains('vboxnet')) {
          continue;
        }

        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            allIps.add(addr.address);
          }
        }
      }

      if (allIps.isEmpty) return null;

      // Prioritize common local network patterns
      try {
        return allIps.firstWhere(
          (ip) =>
              ip.startsWith('192.168.') ||
              ip.startsWith('10.0.') ||
              ip.startsWith('172.'),
          orElse: () => allIps.first,
        );
      } catch (e) {
        return allIps.first;
      }
    } catch (e) {
      return null;
    }
  }

  AppState() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final master = prefs.getBool('isMaster');
      final ip = prefs.getString('masterAddress');
      masterPassword = prefs.getString('masterPassword');

      isMaster = master;
      masterAddress = ip;
      deviceId = prefs.getString('deviceId') ?? Uuid().v4();
      await prefs.setString('deviceId', deviceId!);
      isActivated = prefs.getBool('isActivated') ?? false;
      isBlocked = prefs.getBool('isBlocked') ?? false;
      activationCode = prefs.getString('activationCode');
      organizationName = prefs.getString('organizationName') ?? 'test';
      organizationAddress = prefs.getString('organizationAddress') ?? 'O\'zbekiston, Toshkent';
      instagramUsername = prefs.getString('instagramUsername') ?? '@simplesale';
      organizationLogoPath = prefs.getString('organizationLogoPath');

      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = packageInfo.version;
      } catch (_) {}

      final savedTheme = prefs.getString('themeMode');
      if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      } else if (savedTheme == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }

      _isBarcodeScanMode = prefs.getBool('isBarcodeScanMode') ?? false;
      _showProductImages = prefs.getBool('showProductImages') ?? true;
      networkPrinterIp = prefs.getString('networkPrinterIp');
      networkBarcodePrinterIp = prefs.getString('networkBarcodePrinterIp');
      selectedPrinterName = prefs.getString('selectedPrinterName');
      barcodePrinterName = prefs.getString('barcodePrinterName');
      receiptWidth = prefs.getInt('receiptWidth') ?? 80;
      receiptFooterText = prefs.getString('receiptFooterText') ?? 'Xaridingiz uchun rahmat!';
      showLogoOnReceipt = prefs.getBool('showLogoOnReceipt') ?? true;
      showInstagramOnReceipt = prefs.getBool('showInstagramOnReceipt') ?? true;

      // Load settings from DB (overrides SharedPreferences if exists)
      final dbSettings = await DatabaseService.getAllSettings();
      if (dbSettings.containsKey('receiptFooterText')) receiptFooterText = dbSettings['receiptFooterText']!;
      if (dbSettings.containsKey('showLogoOnReceipt')) showLogoOnReceipt = dbSettings['showLogoOnReceipt'] == 'true';
      if (dbSettings.containsKey('showInstagramOnReceipt')) showInstagramOnReceipt = dbSettings['showInstagramOnReceipt'] == 'true';
      if (dbSettings.containsKey('organizationName')) organizationName = dbSettings['organizationName']!;
      if (dbSettings.containsKey('organizationAddress')) organizationAddress = dbSettings['organizationAddress']!;
      if (dbSettings.containsKey('instagramUsername')) instagramUsername = dbSettings['instagramUsername']!;
      if (dbSettings.containsKey('barcodePrinterName')) barcodePrinterName = dbSettings['barcodePrinterName']!;

      // Load data from DB
      await _loadFromDb();

      // Safety check: ensure no nulls
      categories = categories.whereType<Category>().toList();
      products = products.whereType<Product>().toList();
      warehouses = warehouses.whereType<Warehouse>().toList();
      registers = registers.whereType<Register>().toList();
      users = users.whereType<User>().toList();

      // If master and empty and NOT activated, add dummy data for trial demonstration
      if (isMaster == true && products.isEmpty && categories.isEmpty && !isActivated) {
        await _initializeDummyData();
        await _loadFromDb();
      }

      final savedRegId = prefs.getString('currentRegisterId');
      if (savedRegId != null) {
        final matching = registers.where((r) => r.id == savedRegId).toList();
        if (matching.isNotEmpty && matching.first.activeDeviceId == deviceId) {
          currentRegister = matching.first;
        }
      }

      if (isMaster == true) {
        _startServer();
        // Automatic Windows Firewall rule add (if on Windows)
        if (Platform.isWindows) {
          _addWindowsFirewallRule();
        }
      } else if (isMaster == false && masterAddress != null) {
        try {
          await syncWithMaster();
          _connectRealtime();
        } catch (e) {
          // Agar master bilan ulanib bo'lmasa ham, dastur ishlashini davom ettiradi
          print('Master bilan ulanishda xatolik (offline rejim): $e');
        }
      }

      // License and remote logout check
      if (isActivated && activationCode != null) {
        checkBlockingStatus(); // Initial check
        // Periodically check every 5 minutes (for both Master and Clients)
        Timer.periodic(const Duration(minutes: 5), (timer) {
          if (!isBlocked) {
            checkBlockingStatus();
          }
        });
      }
    } catch (e) {
      // Har qanday kutilmagan xato bo'lsa ham, dastur ishlashini davom ettiradi
      initializationError = e.toString();
      print('loadSettings xatosi: $e');
    } finally {
      // Har doim initialized qilimiz – loading ekranda qotib qolmasin
      isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> retryInitialization() async {
    initializationError = null;
    isInitialized = false;
    notifyListeners();
    await loadSettings();
  }


  Future<void> _loadFromDb() async {
    // Load settings from DB (overrides SharedPreferences if exists)
    final dbSettings = await DatabaseService.getAllSettings();
    if (dbSettings.containsKey('receiptFooterText')) receiptFooterText = dbSettings['receiptFooterText']!;
    if (dbSettings.containsKey('showLogoOnReceipt')) showLogoOnReceipt = dbSettings['showLogoOnReceipt'] == 'true';
    if (dbSettings.containsKey('showInstagramOnReceipt')) showInstagramOnReceipt = dbSettings['showInstagramOnReceipt'] == 'true';
    if (dbSettings.containsKey('organizationName')) organizationName = dbSettings['organizationName']!;
    if (dbSettings.containsKey('organizationAddress')) organizationAddress = dbSettings['organizationAddress']!;
    if (dbSettings.containsKey('instagramUsername')) instagramUsername = dbSettings['instagramUsername']!;
    if (dbSettings.containsKey('barcodePrinterName')) barcodePrinterName = dbSettings['barcodePrinterName']!;

    categories = await DatabaseService.getCategories();
    products = await DatabaseService.getProducts();
    warehouses = await DatabaseService.getWarehouses();
    registers = await DatabaseService.getRegisters();
    stockEntries = await DatabaseService.getStockEntries();
    users = await DatabaseService.getUsers();
    sales = await DatabaseService.getSales();
    returns = await DatabaseService.getReturns();
    writeOffs = await DatabaseService.getWriteOffs();
    inventories = await DatabaseService.getInventories();

    if (users.isEmpty && isMaster == true) {
      final admin = User(
        id: 'admin',
        name: 'Admin',
        pin: '1234',
        role: UserRole.admin,
      );
      final seller1 = User(
        id: 'seller1',
        name: 'Sotuvchi 1',
        pin: '1111',
        role: UserRole.seller,
      );
      final seller2 = User(
        id: 'seller2',
        name: 'Sotuvchi 2',
        pin: '2222',
        role: UserRole.seller,
      );
      await DatabaseService.saveUser(admin);
      await DatabaseService.saveUser(seller1);
      await DatabaseService.saveUser(seller2);
      users.addAll([admin, seller1, seller2]);
    }
  }

  Future<void> _initializeDummyData() async {
    // 1. Categories
    final c1 = Category(id: 'c1', name: 'Energetiklar');
    final c2 = Category(id: 'c2', name: 'Salqin Ichimliklar');
    final c3 = Category(id: 'c3', name: 'Snacks (Yeguliklar)');
    final c4 = Category(id: 'c4', name: 'Tezkor Taomlar');
    final c5 = Category(id: 'c5', name: 'Shirinliklar');

    await DatabaseService.saveCategory(c1);
    await DatabaseService.saveCategory(c2);
    await DatabaseService.saveCategory(c3);
    await DatabaseService.saveCategory(c4);
    await DatabaseService.saveCategory(c5);

    // 2. Warehouses
    final w1 = Warehouse(id: 'w1', name: 'Asosiy Ombor (Klub)');
    final w2 = Warehouse(id: 'w2', name: 'Zaxira Ombor');

    await DatabaseService.saveWarehouse(w1);
    await DatabaseService.saveWarehouse(w2);

    // 3. Registers
    await DatabaseService.saveRegister(
      Register(id: 'r1', name: 'Kassa 1 (Bar)', warehouseId: 'w1'),
    );
    await DatabaseService.saveRegister(
      Register(id: 'r2', name: 'Kassa 2 (Vip)', warehouseId: 'w2'),
    );

    // 4. Products - Energy Drinks
    await DatabaseService.saveProduct(
      Product(
        id: 'p1',
        name: 'Adrenaline Rush 0.5',
        price: 25000,
        costPrice: 18000,
        categoryId: 'c1',
        barcode: '111100',
        stocks: {'w1': 50, 'w2': 100},
      ),
    );
    await DatabaseService.saveProduct(
      Product(
        id: 'p2',
        name: 'Flash Up 0.5',
        price: 13000,
        costPrice: 9000,
        categoryId: 'c1',
        barcode: '111101',
        stocks: {'w1': 100, 'w2': 200},
      ),
    );
    await DatabaseService.saveProduct(
      Product(
        id: 'p3',
        name: 'Gorilla 0.5',
        price: 15000,
        costPrice: 11000,
        categoryId: 'c1',
        barcode: '111102',
        stocks: {'w1': 80, 'w2': 150},
      ),
    );

    // 5. Products - Beverages
    await DatabaseService.saveProduct(
      Product(
        id: 'p4',
        name: 'Coca-Cola 0.5L',
        price: 8000,
        costPrice: 5000,
        categoryId: 'c2',
        barcode: '222200',
        stocks: {'w1': 120, 'w2': 300},
      ),
    );
    await DatabaseService.saveProduct(
      Product(
        id: 'p5',
        name: 'Fanta 0.5L',
        price: 8000,
        costPrice: 5000,
        categoryId: 'c2',
        barcode: '222201',
        stocks: {'w1': 100, 'w2': 200},
      ),
    );
    await DatabaseService.saveProduct(
      Product(
        id: 'p6',
        name: 'Pepsi 0.5L',
        price: 8000,
        costPrice: 5000,
        categoryId: 'c2',
        barcode: '222202',
        stocks: {'w1': 100, 'w2': 200},
      ),
    );
    await DatabaseService.saveProduct(
      Product(
        id: 'p7',
        name: 'Mineral suv (Chortoq)',
        price: 4000,
        costPrice: 2000,
        categoryId: 'c2',
        barcode: '222203',
        stocks: {'w1': 200, 'w2': 500},
      ),
    );

    // 6. Products - Snacks
    await DatabaseService.saveProduct(
      Product(
        id: 'p8',
        name: 'Lays 120g (Classic)',
        price: 18000,
        costPrice: 13000,
        categoryId: 'c3',
        barcode: '333300',
        stocks: {'w1': 30, 'w2': 60},
      ),
    );
    await DatabaseService.saveProduct(
      Product(
        id: 'p9',
        name: 'Pringles 165g',
        price: 35000,
        costPrice: 28000,
        categoryId: 'c3',
        barcode: '333301',
        stocks: {'w1': 20, 'w2': 40},
      ),
    );
    await DatabaseService.saveProduct(
      Product(
        id: 'p10',
        name: 'Semochka (Oltin)',
        price: 7000,
        costPrice: 4000,
        categoryId: 'c3',
        barcode: '333302',
        stocks: {'w1': 100, 'w2': 200},
      ),
    );
    await DatabaseService.saveProduct(
      Product(
        id: 'p11',
        name: 'Kurut (Dona)',
        price: 1500,
        costPrice: 800,
        categoryId: 'c3',
        barcode: '333303',
        stocks: {'w1': 500, 'w2': 1000},
      ),
    );

    // 7. Products - Fast Food
    await DatabaseService.saveProduct(
      Product(
        id: 'p12',
        name: 'Burger (Maxi)',
        price: 28000,
        costPrice: 18000,
        categoryId: 'c4',
        barcode: '444400',
        stocks: {'w1': 20, 'w2': 0},
      ),
    );
    await DatabaseService.saveProduct(
      Product(
        id: 'p13',
        name: 'Hot-Dog (Sosiskali)',
        price: 12000,
        costPrice: 6000,
        categoryId: 'c4',
        barcode: '444401',
        stocks: {'w1': 30, 'w2': 0},
      ),
    );
    await DatabaseService.saveProduct(
      Product(
        id: 'p14',
        name: 'Sendvich (Go\'shtli)',
        price: 18000,
        costPrice: 11000,
        categoryId: 'c4',
        barcode: '444402',
        stocks: {'w1': 25, 'w2': 0},
      ),
    );

    // 8. Products - Sweets
    await DatabaseService.saveProduct(
      Product(
        id: 'p15',
        name: 'Snickers 50g',
        price: 8000,
        costPrice: 5500,
        categoryId: 'c5',
        barcode: '555500',
        stocks: {'w1': 100, 'w2': 200},
      ),
    );
    await DatabaseService.saveProduct(
      Product(
        id: 'p16',
        name: 'Twix 50g',
        price: 8000,
        costPrice: 5500,
        categoryId: 'c5',
        barcode: '555501',
        stocks: {'w1': 100, 'w2': 200},
      ),
    );
    await DatabaseService.saveProduct(
      Product(
        id: 'p17',
        name: 'Orbit Sugarloss',
        price: 5000,
        costPrice: 3500,
        categoryId: 'c5',
        barcode: '555502',
        stocks: {'w1': 200, 'w2': 400},
      ),
    );
  }

  Future<void> syncWithMaster() async {
    if (isMaster != false || masterAddress == null) return;

    try {
      final data = await SyncService.fetchFullState(masterAddress!);
      if (data != null) {
        final newCategories = (data['categories'] as List)
            .map((c) => Category.fromJson(c))
            .toList();
        final newProducts = (data['products'] as List)
            .map((p) => Product.fromJson(p))
            .toList();
        final newWarehouses = (data['warehouses'] as List)
            .map((w) => Warehouse.fromJson(w))
            .toList();
        final newRegisters = (data['registers'] as List)
            .map((r) => Register.fromJson(r))
            .toList();
        final newUsers = data['users'] != null
            ? (data['users'] as List).map((u) => User.fromJson(u)).toList()
            : <User>[];

        await DatabaseService.clearAllAndReplace(
          categories: newCategories.whereType<Category>().toList(),
          products: newProducts.whereType<Product>().toList(),
          warehouses: newWarehouses.whereType<Warehouse>().toList(),
          registers: newRegisters.whereType<Register>().toList(),
          users: newUsers.whereType<User>().toList(),
        );

        // Sync settings
        if (data['settings'] != null) {
          final Map<String, dynamic> remoteSettings = data['settings'];
          for (var entry in remoteSettings.entries) {
            await DatabaseService.saveSetting(entry.key, entry.value.toString());
          }
        }

        await _loadFromDb(); // Reload data and settings from DB

        final prefs = await SharedPreferences.getInstance();
        final savedRegId = prefs.getString('currentRegisterId');
        
        if (currentRegister != null) {
          final existingId = currentRegister!.id;
          final matching = registers.where((r) => r.id == existingId).toList();
          if (matching.isNotEmpty) {
            currentRegister = matching.first;
          } else if (registers.isNotEmpty) {
            currentRegister = registers.first;
          } else {
            currentRegister = null;
          }
        } else if (savedRegId != null) {
          final matching = registers.where((r) => r.id == savedRegId).toList();
          if (matching.isNotEmpty && matching.first.activeDeviceId == deviceId) {
            currentRegister = matching.first;
          }
        }

        if (data['organizationName'] != null) organizationName = data['organizationName'];
        if (data['organizationAddress'] != null) organizationAddress = data['organizationAddress'];
        if (data['instagramUsername'] != null) instagramUsername = data['instagramUsername'];
        
        // Logo sync
        if (data['logoPath'] != null) {
          try {
            final logoResponse = await http.get(Uri.parse('http://$masterAddress:8080/logo'));
            if (logoResponse.statusCode == 200) {
              final appDir = await getApplicationDocumentsDirectory();
              final localLogoFile = File('${appDir.path}/master_logo.png');
              await localLogoFile.writeAsBytes(logoResponse.bodyBytes);
              organizationLogoPath = localLogoFile.path;
              
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('organizationLogoPath', organizationLogoPath!);
              await prefs.setString('organizationName', organizationName!);
              await prefs.setString('organizationAddress', organizationAddress!);
              await prefs.setString('instagramUsername', instagramUsername!);
            }
          } catch (e) {
            print('Logo sync error: $e');
          }
        }

        // Product images sync
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory('${appDir.path}/product_images');
        if (!await imagesDir.exists()) await imagesDir.create();

        for (var pData in data['products']) {
          final pId = pData['id'];
          final remotePath = pData['imagePath'];
          
          if (remotePath != null && remotePath.isNotEmpty) {
            final localPath = '${imagesDir.path}/$pId.jpg';
            final localFile = File(localPath);
            
            if (!await localFile.exists()) {
              try {
                final imgResponse = await http.get(Uri.parse('http://$masterAddress:8080/product-image/$pId'));
                if (imgResponse.statusCode == 200) {
                  await localFile.writeAsBytes(imgResponse.bodyBytes);
                  // Update local state and DB (if you have it)
                  await DatabaseService.updateProductImagePath(pId, localPath);
                }
              } catch (e) {
                print('Product image sync error ($pId): $e');
              }
            }
          }
        }

        notifyListeners();
      } else {
        throw Exception(
          'Asosiy kompyuterga ulanib bo\'lmadi. IP manzilni tekshiring.',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> setTerminalMode(
    bool master, {
    String? ip,
    String? password,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (master == false) {
      // For secondary, try to sync first
      if (ip == null || ip.isEmpty) throw Exception('IP manzilni kiriting');

      final oldIp = masterAddress;
      final oldMaster = isMaster;

      masterAddress = ip;
      isMaster = false;

      try {
        await syncWithMaster();
        // If sync success, save everything
        await prefs.setBool('isMaster', false);
        await prefs.setString('masterAddress', ip);
        await prefs.setBool(
          'isActivated',
          true,
        ); // Secondary terminals follow Master activation
        isActivated = true;
      } catch (e) {
        // Rollback
        masterAddress = oldIp;
        isMaster = oldMaster;
        rethrow;
      }
    } else {
      // For Master
      await prefs.setBool('isMaster', true);
      if (password != null) {
        await prefs.setString('masterPassword', password);
        masterPassword = password;
      }
      isMaster = true;
      isActivated = false; // Always require activation on Master setup
      activationCode = null;
      _startServer();
    }

    notifyListeners();
    if (isMaster == false) _connectRealtime();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.toString().split('.').last);
    notifyListeners();
  }

  Future<void> toggleBarcodeScanMode() async {
    _isBarcodeScanMode = !_isBarcodeScanMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isBarcodeScanMode', _isBarcodeScanMode);
    notifyListeners();
  }

  void toggleShowProductImages() async {
    _showProductImages = !_showProductImages;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showProductImages', _showProductImages);
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }

  void _connectRealtime() {
    _syncTimer?.cancel();
    _wsPingTimer?.cancel();
    if (isMaster != false || masterAddress == null || _isConnectingWs) return;

    _isConnectingWs = true;
    try {
      final wsUrl = 'ws://$masterAddress:8080/ws';
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Set up heartbeat
      _wsPingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        try {
          _wsChannel?.sink.add(jsonEncode({'type': 'ping'}));
        } catch (e) {
          timer.cancel();
        }
      });

      _wsChannel!.stream.listen(
        (message) async {
          if (!_isConnected) {
            _isConnected = true;
            notifyListeners();
          }
          final data = jsonDecode(message);
          if (data['type'] == 'pong') return; // Ignore heartbeat responses
          await _handleRemoteUpdate(data['type'], data['data']);
        },
        onDone: () {
          _isConnectingWs = false;
          _isConnected = false;
          _wsPingTimer?.cancel();
          _reconnectRealtime();
          notifyListeners();
        },
        onError: (err) {
          _isConnectingWs = false;
          _isConnected = false;
          _wsPingTimer?.cancel();
          _reconnectRealtime();
          notifyListeners();
        },
      );
      print('WebSocket ulandi: $wsUrl');
    } catch (e) {
      _isConnectingWs = false;
      _reconnectRealtime();
    }

    // Fallback polling for register status check
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (isMaster == false && masterAddress != null) {
        try {
          // Check if current register is still ours (lightweight check)
          final data = await SyncService.fetchFullState(masterAddress!);
          if (data != null && data['registers'] != null) {
            final regs = (data['registers'] as List)
                .map((r) => Register.fromJson(r))
                .toList();
            if (currentRegister != null) {
              final latest = regs.firstWhere(
                (r) => r.id == currentRegister!.id,
                orElse: () => currentRegister!,
              );
              if (latest.activeDeviceId != deviceId) {
                currentRegister = null;
                notifyListeners();
              }
            }
          }
        } catch (e) {}
      } else {
        timer.cancel();
      }
    });
  }

  void _reconnectRealtime() {
    Future.delayed(const Duration(seconds: 5), () {
      if (isMaster == false) _connectRealtime();
    });
  }

  Future<void> _handleRemoteUpdate(
    String type,
    Map<String, dynamic> data,
  ) async {
    await _applyRemoteUpdate(type, data);
  }

  Future<void> _applyRemoteUpdate(
    String type,
    Map<String, dynamic> data,
  ) async {
    print('Applying remote update: $type');
    try {
      switch (type) {
        case 'category':
          await DatabaseService.saveCategory(Category.fromJson(data));
          break;
        case 'product':
          await DatabaseService.saveProduct(Product.fromJson(data));
          break;
        case 'warehouse':
          await DatabaseService.saveWarehouse(Warehouse.fromJson(data));
          break;
        case 'register':
          await DatabaseService.saveRegister(Register.fromJson(data));
          break;
        case 'user':
          await DatabaseService.saveUser(User.fromJson(data));
          break;
        case 'stock_entry':
        case 'stock_entry_update':
          final entry = StockEntry.fromJson(data);
          await DatabaseService.deleteStockEntry(entry.id);
          await DatabaseService.saveStockEntry(entry);
          // Update stocks locally
          for (var item in entry.items) {
            await _applyStockAdjustment(item.productId, entry.warehouseId, item.quantity);
          }
          break;
        case 'sale':
          final sale = Sale.fromJson(data);
          if (sales.any((s) => s.id == sale.id)) return;
          await DatabaseService.saveSale(sale);
          // Update stocks locally
          for (var item in sale.items) {
            await _applyStockAdjustment(item.productId, sale.warehouseId, -item.quantity);
          }
          break;
        case 'return':
        case 'return_update':
          final ret = SaleReturn.fromJson(data);
          await DatabaseService.saveReturn(ret);
          // Update stocks locally
          for (var item in ret.items) {
            await _applyStockAdjustment(item.productId, ret.warehouseId, item.quantity);
          }
          break;
        case 'write_off':
        case 'write_off_update':
          final wo = WriteOff.fromJson(data);
          await DatabaseService.saveWriteOff(wo);
          // Update stocks locally
          for (var item in wo.items) {
            await _applyStockAdjustment(item.productId, wo.warehouseId, -item.quantity);
          }
          break;
        case 'inventory':
        case 'inventory_update':
          final inv = InventoryEntry.fromJson(data);
          await DatabaseService.saveInventory(inv);
          // Update stocks locally to exact values
          for (var item in inv.items) {
            await DatabaseService.updateStock(item.productId, inv.warehouseId, item.actualQuantity);
          }
          break;
        case 'warehouse_delete':
          await DatabaseService.deleteWarehouse(data['id']);
          break;
        case 'register_delete':
          await DatabaseService.deleteRegister(data['id']);
          break;
        case 'return_delete':
          await DatabaseService.deleteReturn(data['id']);
          break;
        case 'write_off_delete':
          await DatabaseService.deleteWriteOff(data['id']);
          break;
        case 'stock_entry_delete':
          await DatabaseService.deleteStockEntry(data['id']);
          break;
        case 'inventory_delete':
          await DatabaseService.deleteInventory(data['id']);
          break;
        case 'setting':
          await DatabaseService.saveSetting(data['key'], data['value'].toString());
          // Update local state if it matches cached settings
          if (data['key'] == 'receiptFooterText') receiptFooterText = data['value'];
          if (data['key'] == 'showLogoOnReceipt') showLogoOnReceipt = data['value'] == 'true';
          if (data['key'] == 'showInstagramOnReceipt') showInstagramOnReceipt = data['value'] == 'true';
          if (data['key'] == 'barcodePrinterName') barcodePrinterName = data['value'];
          break;
      }
      
      // Every remote update should trigger a database reload to ensure consistency
      await _loadFromDb();
      notifyListeners();
      print('Remote update applied successfully: $type');
    } catch (e, stack) {
      print('Error applying remote update ($type): $e');
      print(stack);
    }
  }

  Future<void> _applyStockAdjustment(String productId, String warehouseId, double delta) async {
    final pIdx = products.indexWhere((p) => p.id == productId);
    if (pIdx >= 0) {
      final p = products[pIdx];
      if (p.trackStock) {
        final current = p.stocks[warehouseId] ?? 0;
        final news = current + delta;
        p.stocks[warehouseId] = news;
        await DatabaseService.updateStock(productId, warehouseId, news);
      }
    }
  }

  Future<void> setReceiptWidth(int width) async {
    receiptWidth = width;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('receiptWidth', width);
    notifyListeners();
  }

  Future<void> updateReceiptSettings({
    String? footerText,
    bool? showLogo,
    bool? showInstagram,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (footerText != null) {
      receiptFooterText = footerText;
      await prefs.setString('receiptFooterText', footerText);
      await DatabaseService.saveSetting('receiptFooterText', footerText);
      await _sendUpdate('setting', {'key': 'receiptFooterText', 'value': footerText});
    }
    if (showLogo != null) {
      showLogoOnReceipt = showLogo;
      await prefs.setBool('showLogoOnReceipt', showLogo);
      await DatabaseService.saveSetting('showLogoOnReceipt', showLogo.toString());
      await _sendUpdate('setting', {'key': 'showLogoOnReceipt', 'value': showLogo.toString()});
    }
    if (showInstagram != null) {
      showInstagramOnReceipt = showInstagram;
      await prefs.setBool('showInstagramOnReceipt', showInstagram);
      await DatabaseService.saveSetting('showInstagramOnReceipt', showInstagram.toString());
      await _sendUpdate('setting', {'key': 'showInstagramOnReceipt', 'value': showInstagram.toString()});
    }
    notifyListeners();
  }

  Future<void> resetTerminalMode() async {
    await clearAllData();
    SyncService.stopServer();
    initializationError = null;
    isInitialized = true;
    notifyListeners();
  }

  void _addWindowsFirewallRule() async {
    try {
      // Command to add firewall rule for port 8080
      // Requires admin privileges implicitly or by user prompt depending on OS settings
      await Process.run('netsh', [
        'advfirewall',
        'firewall',
        'add',
        'rule',
        'name=SimpleSaleServer',
        'dir=in',
        'action=allow',
        'protocol=TCP',
        'localport=8080',
      ]);
      print('Firewall rule added or already exists.');
    } catch (e) {
      print('Failed to add firewall rule: $e');
    }
  }

  void _startServer() {
    SyncService.startServer(
      onSaleReceived: (saleData) async {
        final sale = Sale.fromJson(saleData);
        if (sales.any((s) => s.id == sale.id)) return;
        
        await DatabaseService.saveSale(sale);
        sales.insert(0, sale);

        for (var item in sale.items) {
          final productIndex = products.indexWhere(
            (p) => p.id == item.productId,
          );
          if (productIndex >= 0) {
            final product = products[productIndex];
            if (product.trackStock) {
              final newStock =
                  (product.stocks[sale.warehouseId] ?? 0) - item.quantity;
              product.stocks[sale.warehouseId] = newStock;
              await DatabaseService.updateStock(
                item.productId,
                sale.warehouseId,
                newStock,
              );
            }
          }
        }
        SyncService.broadcast('sale', saleData);
        notifyListeners();
      },
      onUpdateReceived: (type, data) async {
        await _applyRemoteUpdate(type, data);
        SyncService.broadcast(type, data);
      },
      onSyncRequested: () {
        // Run synchronously but we need a way to get settings
        // Since onSyncRequested is currently synchronous in the SinkService call,
        // we might have some trouble getting settings if we don't cache them.
        // But AppState usually has them in memory.
        return {
          'categories': categories.map((c) => c.toJson()).toList(),
          'products': products.map((p) => p.toJson()).toList(),
          'warehouses': warehouses.map((w) => w.toJson()).toList(),
          'registers': registers.map((r) => r.toJson()).toList(),
          'users': users.map((u) => u.toJson()).toList(),
          'returns': returns.map((r) => r.toJson()).toList(),
          'writeOffs': writeOffs.map((w) => w.toJson()).toList(),
          'inventories': inventories.map((i) => i.toJson()).toList(),
          'organizationName': organizationName,
          'organizationAddress': organizationAddress,
          'instagramUsername': instagramUsername,
          'logoPath': organizationLogoPath,
          'settings': {
            'receiptFooterText': receiptFooterText,
            'showLogoOnReceipt': showLogoOnReceipt.toString(),
            'showInstagramOnReceipt': showInstagramOnReceipt.toString(),
            'barcodePrinterName': barcodePrinterName ?? '',
          }
        };
      },
      onRegisterSelectionRequested: (registerId, rDeviceId, force) async {
        if (registerId == null || rDeviceId == null) {
          return {
            'status': 'error',
            'message': 'Kassa yoki Qurilma ID topilmadi',
          };
        }
        final regIndex = registers.indexWhere((r) => r.id == registerId);
        if (regIndex < 0) {
          return {'status': 'error', 'message': 'Kassa topilmadi'};
        }

        final reg = registers[regIndex];
        if (!force &&
            reg.activeDeviceId != null &&
            reg.activeDeviceId != rDeviceId) {
          return {
            'status': 'error',
            'message':
                'Ushbu kassa hozirda boshqa qurilmada (${reg.activeDeviceId}) band!',
          };
        }

        // Clear ANY device from this register if force is true
        if (force &&
            reg.activeDeviceId != null &&
            reg.activeDeviceId != rDeviceId) {
          // If we are forcing, we just take over.
          // Clear other device's reference if they have it (optional but good)
        }

        // Clear THIS device from any other register
        for (int i = 0; i < registers.length; i++) {
          if (registers[i].activeDeviceId == rDeviceId) {
            final cleared = Register(
              id: registers[i].id,
              name: registers[i].name,
              warehouseId: registers[i].warehouseId,
              activeDeviceId: null,
            );
            await DatabaseService.saveRegister(cleared);
            registers[i] = cleared;
          }
        }

        // Clear the target register from OTHER devices if forcing
        if (force) {
          // It's already cleared from THIS device above.
          // Now just overwrite the target register's device ID.
        }

        final updated = Register(
          id: reg.id,
          name: reg.name,
          warehouseId: reg.warehouseId,
          activeDeviceId: rDeviceId,
        );
        await DatabaseService.saveRegister(updated);
        final finalIdx = registers.indexWhere((r) => r.id == registerId);
        if (finalIdx >= 0) registers[finalIdx] = updated;

        notifyListeners();
        return {'status': 'success'};
      },
    );
  }

  Future<void> _sendUpdate(String type, Map<String, dynamic> data) async {
    if (isMaster == true) {
      SyncService.broadcast(type, data);
    } else if (isMaster == false && masterAddress != null) {
      final success = await SyncService.sendUpdateToMaster(
        masterAddress!,
        type,
        data,
      );
      if (!success) {
        throw Exception('Ma\'lumotlarni serverga yuborib bo\'lmadi');
      }
    }
  }

  // --- Category CRUD ---
  Future<void> addCategory(String name) async {
    final category = Category.create(name);
    await DatabaseService.saveCategory(category);
    await _sendUpdate('category', category.toJson());
    categories.add(category);
    notifyListeners();
  }

  Future<void> updateCategory(String id, String newName) async {
    final category = Category(id: id, name: newName);
    await DatabaseService.saveCategory(category);
    await _sendUpdate('category', category.toJson());
    final index = categories.indexWhere((c) => c.id == id);
    if (index >= 0) {
      categories[index] = category;
      notifyListeners();
    }
  }

  Future<void> deleteCategory(String id) async {
    final index = categories.indexWhere((c) => c.id == id);
    if (index >= 0) {
      final updated = Category(
        id: categories[index].id,
        name: categories[index].name,
        isDeleted: true,
      );
      await DatabaseService.saveCategory(updated);
      await _sendUpdate('category', updated.toJson());
      categories[index] = updated;
      notifyListeners();
    }
  }

  Future<void> restoreCategory(String id) async {
    final index = categories.indexWhere((c) => c.id == id);
    if (index >= 0) {
      final updated = Category(
        id: categories[index].id,
        name: categories[index].name,
        isDeleted: false,
      );
      await DatabaseService.saveCategory(updated);
      await _sendUpdate('category', updated.toJson());
      categories[index] = updated;
      notifyListeners();
    }
  }

  // --- Product CRUD ---
  Future<void> addProduct(Product product) async {
    await DatabaseService.saveProduct(product);
    await _sendUpdate('product', product.toJson());
    products.add(product);
    notifyListeners();
  }

  Future<void> updateProduct(Product updatedProduct) async {
    await DatabaseService.saveProduct(updatedProduct);
    await _sendUpdate('product', updatedProduct.toJson());
    final index = products.indexWhere((p) => p.id == updatedProduct.id);
    if (index >= 0) {
      products[index] = updatedProduct;
      notifyListeners();
    }
  }

  Future<void> deleteProduct(String id) async {
    final index = products.indexWhere((p) => p.id == id);
    if (index >= 0) {
      final updated = products[index].copyWith(isDeleted: true);
      await DatabaseService.saveProduct(updated);
      await _sendUpdate('product', updated.toJson());
      products[index] = updated;
      notifyListeners();
    }
  }

  Future<void> restoreProduct(String id) async {
    final index = products.indexWhere((p) => p.id == id);
    if (index >= 0) {
      final updated = products[index].copyWith(isDeleted: false);
      await DatabaseService.saveProduct(updated);
      await _sendUpdate('product', updated.toJson());
      products[index] = updated;
      notifyListeners();
    }
  }

  // --- Register & Cart ---
  Future<void> setRegister(Register register) async {
    final isAdmin = currentUser?.role == UserRole.admin;

    if (isMaster == true) {
      if (!isAdmin &&
          register.activeDeviceId != null &&
          register.activeDeviceId != deviceId) {
        throw Exception('Ushbu kassa hozirda boshqa qurilmada band!');
      }

      // Clear THIS device from others
      for (int i = 0; i < registers.length; i++) {
        if (registers[i].activeDeviceId == deviceId) {
          final cleared = Register(
            id: registers[i].id,
            name: registers[i].name,
            warehouseId: registers[i].warehouseId,
            activeDeviceId: null,
          );
          await DatabaseService.saveRegister(cleared);
          registers[i] = cleared;
        }
      }

      final updated = Register(
        id: register.id,
        name: register.name,
        warehouseId: register.warehouseId,
        activeDeviceId: deviceId,
      );
      await DatabaseService.saveRegister(updated);
      final idx = registers.indexWhere((r) => r.id == register.id);
      if (idx >= 0) registers[idx] = updated;
      currentRegister = updated;
    } else if (isMaster == false && masterAddress != null) {
      final res = await SyncService.selectRegisterOnMaster(
        masterAddress!,
        register.id,
        deviceId!,
        isAdmin,
      );
      if (res != null && res['status'] == 'success') {
        final updated = Register(
          id: register.id,
          name: register.name,
          warehouseId: register.warehouseId,
          activeDeviceId: deviceId,
        );
        currentRegister = updated;
      } else {
        throw Exception(res?['message'] ?? 'Kassani tanlab bo\'lmadi');
      }
    } else {
      currentRegister = register;
    }

    final prefs = await SharedPreferences.getInstance();
    if (currentRegister != null) {
      await prefs.setString('currentRegisterId', currentRegister!.id);
    } else {
      await prefs.remove('currentRegisterId');
    }

    notifyListeners();
  }

  void addToCart(Product product) {
    if (currentRegister == null) return;
    final warehouseId = currentRegister!.warehouseId;
    final stock = product.stocks[warehouseId] ?? 0;

    final existingIndex = cart.indexWhere(
      (item) => item.productId == product.id,
    );
    double currentQty = 0;
    if (existingIndex >= 0) {
      currentQty = cart[existingIndex].quantity;
    }

    if (product.trackStock && currentQty + 1 > stock) {
      throw Exception(
        'Omborda yetarli mahsulot yo\'q! (Mavjud: ${stock.toInt()})',
      );
    }

    if (existingIndex >= 0) {
      final item = cart[existingIndex];
      cart[existingIndex] = SaleItem(
        productId: product.id,
        productName: product.name,
        quantity: item.quantity + 1,
        price: product.price,
        costPrice: product.costPrice,
      );
    } else {
      cart.add(
        SaleItem(
          productId: product.id,
          productName: product.name,
          quantity: 1,
          price: product.price,
          costPrice: product.costPrice,
        ),
      );
    }
    notifyListeners();
  }

  void updateCartQuantity(String productId, double quantity) {
    if (currentRegister == null) return;
    final warehouseId = currentRegister!.warehouseId;

    final product = products.firstWhere((p) => p.id == productId);
    final stock = product.stocks[warehouseId] ?? 0;

    if (product.trackStock && quantity > stock) {
      throw Exception(
        'Omborda yetarli mahsulot yo\'q! (Mavjud: ${stock.toInt()})',
      );
    }

    final index = cart.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        cart.removeAt(index);
      } else {
        final item = cart[index];
        cart[index] = SaleItem(
          productId: item.productId,
          productName: item.productName,
          quantity: quantity,
          price: item.price,
          costPrice: item.costPrice,
        );
      }
      notifyListeners();
    }
  }

  void addToCartByBarcode(String barcode) {
    final product = products.firstWhere(
      (p) => p.barcode == barcode || p.additionalBarcodes.contains(barcode),
      orElse: () => throw Exception('Mahsulot topilmadi'),
    );
    addToCart(product);
  }

  void removeFromCart(String productId) {
    cart.removeWhere((item) => item.productId == productId);
    notifyListeners();
  }

  void decrementInCart(String productId) {
    final index = cart.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      if (cart[index].quantity > 1) {
        final item = cart[index];
        cart[index] = SaleItem(
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity - 1,
          price: item.price,
          costPrice: item.costPrice,
        );
      } else {
        cart.removeAt(index);
      }
      notifyListeners();
    }
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
  }

  double get cartTotal => cart.fold(0, (sum, item) => sum + item.subtotal);

  Future<void> processSale() async {
    if (currentRegister == null || cart.isEmpty) return;

    final saleData = {
      'id': Uuid().v4(),
      'date': DateTime.now().toIso8601String(),
      'items': cart.map((i) => i.toJson()).toList(),
      'total': cartTotal,
      'registerId': currentRegister!.id,
      'warehouseId': currentRegister!.warehouseId,
    };

    final sale = Sale.fromJson(saleData);
    await DatabaseService.saveSale(sale);
    sales.insert(0, sale);

    await _sendUpdate('sale', saleData);

    final warehouseId = currentRegister!.warehouseId;
    for (var item in cart) {
      final productIndex = products.indexWhere((p) => p.id == item.productId);
      if (productIndex >= 0) {
        final product = products[productIndex];
        if (product.trackStock) {
          final currentStock = product.stocks[warehouseId] ?? 0;
          final newStock = currentStock - item.quantity;
          product.stocks[warehouseId] = newStock;
          await DatabaseService.updateStock(product.id, warehouseId, newStock);
        }
      }
    }

    clearCart();
    notifyListeners();
  }

  // --- Stock Entries ---
  Future<void> addStockEntry(StockEntry entry) async {
    await DatabaseService.saveStockEntry(entry);
    await _sendUpdate('stock_entry', entry.toJson());

    // Update local stocks
    for (var item in entry.items) {
      final productIndex = products.indexWhere((p) => p.id == item.productId);
      if (productIndex >= 0) {
        final product = products[productIndex];
        final currentStock = product.stocks[entry.warehouseId] ?? 0;
        final newStock = currentStock + item.quantity;
        product.stocks[entry.warehouseId] = newStock;
        await DatabaseService.updateStock(
          product.id,
          entry.warehouseId,
          newStock,
        );
      }
    }

    stockEntries.insert(0, entry);
    notifyListeners();
  }

  Future<void> updatePrinter(String name) async {
    selectedPrinterName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedPrinterName', name);
    notifyListeners();
  }

  Future<void> updateBarcodePrinter(String name) async {
    barcodePrinterName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('barcodePrinterName', name);
    await DatabaseService.saveSetting('barcodePrinterName', name);
    await _sendUpdate('setting', {'key': 'barcodePrinterName', 'value': name});
    notifyListeners();
  }

  Future<void> updateNetworkPrinterIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    networkPrinterIp = ip;
    if (ip.isEmpty) {
      await prefs.remove('networkPrinterIp');
    } else {
      await prefs.setString('networkPrinterIp', ip);
    }
    notifyListeners();
  }
  
  Future<void> updateNetworkBarcodePrinterIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    networkBarcodePrinterIp = ip;
    if (ip.isEmpty) {
      await prefs.remove('networkBarcodePrinterIp');
    } else {
      await prefs.setString('networkBarcodePrinterIp', ip);
    }
    notifyListeners();
  }

  // --- User Management ---
  Future<void> addUser(User user) async {
    await DatabaseService.saveUser(user);
    await _sendUpdate('user', user.toJson());
    users.add(user);
    notifyListeners();
  }

  Future<void> deleteUser(String id) async {
    final index = users.indexWhere((u) => u.id == id);
    if (index >= 0) {
      final updated = User(
        id: users[index].id,
        name: users[index].name,
        pin: users[index].pin,
        role: users[index].role,
        isDeleted: true,
      );
      await DatabaseService.saveUser(updated);
      await _sendUpdate('user', updated.toJson());
      users[index] = updated;
      notifyListeners();
    }
  }

  Future<void> restoreUser(String id) async {
    final index = users.indexWhere((u) => u.id == id);
    if (index >= 0) {
      final updated = User(
        id: users[index].id,
        name: users[index].name,
        pin: users[index].pin,
        role: users[index].role,
        isDeleted: false,
      );
      await DatabaseService.saveUser(updated);
      await _sendUpdate('user', updated.toJson());
      users[index] = updated;
      notifyListeners();
    }
  }

  void login(String pin) {
    final user = users.firstWhere(
      (u) => u.pin == pin,
      orElse: () => throw Exception('PIN xato!'),
    );
    currentUser = user;
    notifyListeners();
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }

  // --- Warehouse Management ---
  Future<void> addWarehouse(String name) async {
    final warehouse = Warehouse.create(name);
    await DatabaseService.saveWarehouse(warehouse);
    await _sendUpdate('warehouse', warehouse.toJson());
    warehouses.add(warehouse);
    notifyListeners();
  }

  Future<void> updateWarehouse(String id, String newName) async {
    final warehouse = Warehouse(id: id, name: newName);
    await DatabaseService.saveWarehouse(warehouse);
    await _sendUpdate('warehouse', warehouse.toJson());
    final index = warehouses.indexWhere((w) => w.id == id);
    if (index >= 0) {
      warehouses[index] = warehouse;
      notifyListeners();
    }
  }

  Future<void> deleteWarehouse(String id) async {
    await DatabaseService.deleteWarehouse(id);
    await _sendUpdate('warehouse_delete', {
      'id': id,
    }); // Generic update for delete
    warehouses.removeWhere((w) => w.id == id);
    notifyListeners();
  }

  // --- Register Management ---
  Future<void> addRegister(String name, String warehouseId) async {
    final register = Register.create(name, warehouseId);
    await DatabaseService.saveRegister(register);
    await _sendUpdate('register', register.toJson());
    registers.add(register);
    notifyListeners();
  }

  Future<void> updateRegister(
    String id,
    String name,
    String warehouseId,
  ) async {
    final register = Register(id: id, name: name, warehouseId: warehouseId);
    await DatabaseService.saveRegister(register);
    await _sendUpdate('register', register.toJson());
    final index = registers.indexWhere((r) => r.id == id);
    if (index >= 0) {
      registers[index] = register;
      notifyListeners();
    }
  }

  // --- NEW: Returns, Write-offs, Inventories ---
  Future<void> addReturn(SaleReturn ret) async {
    await DatabaseService.saveReturn(ret);
    await _sendUpdate('return', ret.toJson());

    // Update stock (Return increases stock if tracked)
    for (var item in ret.items) {
      final pIdx = products.indexWhere((p) => p.id == item.productId);
      if (pIdx >= 0) {
        final p = products[pIdx];
        if (p.trackStock) {
          final current = p.stocks[ret.warehouseId] ?? 0;
          final news = current + item.quantity;
          p.stocks[ret.warehouseId] = news;
          await DatabaseService.updateStock(p.id, ret.warehouseId, news);
        }
      }
    }
    returns.insert(0, ret);
    notifyListeners();
  }

  Future<void> addWriteOff(WriteOff wo) async {
    await DatabaseService.saveWriteOff(wo);
    await _sendUpdate('write_off', wo.toJson());

    // Update stock (Write off decreases stock if tracked)
    for (var item in wo.items) {
      final pIdx = products.indexWhere((p) => p.id == item.productId);
      if (pIdx >= 0) {
        final p = products[pIdx];
        if (p.trackStock) {
          final current = p.stocks[wo.warehouseId] ?? 0;
          final news = current - item.quantity;
          p.stocks[wo.warehouseId] = news;
          await DatabaseService.updateStock(p.id, wo.warehouseId, news);
        }
      }
    }
    writeOffs.insert(0, wo);
    notifyListeners();
  }

  Future<void> addInventory(InventoryEntry inv) async {
    await DatabaseService.saveInventory(inv);
    await _sendUpdate('inventory', inv.toJson());

    // Update stock (Inventory sets stock to actual count)
    for (var item in inv.items) {
      final pIdx = products.indexWhere((p) => p.id == item.productId);
      if (pIdx >= 0) {
        final p = products[pIdx];
        if (p.trackStock) {
          p.stocks[inv.warehouseId] = item.actualQuantity;
          await DatabaseService.updateStock(
            p.id,
            inv.warehouseId,
            item.actualQuantity,
          );
        }
      }
    }
    inventories.insert(0, inv);
    notifyListeners();
  }

  Future<void> deleteReturn(String id) async {
    final index = returns.indexWhere((r) => r.id == id);
    if (index >= 0) {
      final ret = returns[index];
      // Revert stock (Return increased it, so we decrease it back)
      for (var item in ret.items) {
        final pIdx = products.indexWhere((p) => p.id == item.productId);
        if (pIdx >= 0) {
          final p = products[pIdx];
          if (p.trackStock) {
            final current = p.stocks[ret.warehouseId] ?? 0;
            final news = current - item.quantity;
            p.stocks[ret.warehouseId] = news;
            await DatabaseService.updateStock(p.id, ret.warehouseId, news);
          }
        }
      }
      await DatabaseService.deleteReturn(id);
      await _sendUpdate('return_delete', {'id': id});
      returns.removeAt(index);
      notifyListeners();
    }
  }

  Future<void> deleteWriteOff(String id) async {
    final index = writeOffs.indexWhere((w) => w.id == id);
    if (index >= 0) {
      final wo = writeOffs[index];
      // Revert stock (Write-off decreased it, so we increase it back)
      for (var item in wo.items) {
        final pIdx = products.indexWhere((p) => p.id == item.productId);
        if (pIdx >= 0) {
          final p = products[pIdx];
          if (p.trackStock) {
            final current = p.stocks[wo.warehouseId] ?? 0;
            final news = current + item.quantity;
            p.stocks[wo.warehouseId] = news;
            await DatabaseService.updateStock(p.id, wo.warehouseId, news);
          }
        }
      }
      await DatabaseService.deleteWriteOff(id);
      await _sendUpdate('write_off_delete', {'id': id});
      writeOffs.removeAt(index);
      notifyListeners();
    }
  }

  Future<void> deleteStockEntry(String id) async {
    final index = stockEntries.indexWhere((e) => e.id == id);
    if (index >= 0) {
      final entry = stockEntries[index];
      // Revert stock (Entry increased it, so we decrease it back)
      for (var item in entry.items) {
        final pIdx = products.indexWhere((p) => p.id == item.productId);
        if (pIdx >= 0) {
          final p = products[pIdx];
          if (p.trackStock) {
            final current = p.stocks[entry.warehouseId] ?? 0;
            final news = current - item.quantity;
            p.stocks[entry.warehouseId] = news;
            await DatabaseService.updateStock(p.id, entry.warehouseId, news);
          }
        }
      }
      await DatabaseService.deleteStockEntry(id);
      await _sendUpdate('stock_entry_delete', {'id': id});
      stockEntries.removeAt(index);
      notifyListeners();
    }
  }

  Future<void> deleteRegister(String id) async {
    await DatabaseService.deleteRegister(id);
    await _sendUpdate('register_delete', {'id': id});
    registers.removeWhere((r) => r.id == id);
    if (currentRegister?.id == id) {
      currentRegister = registers.isNotEmpty ? registers.first : null;
    }
    notifyListeners();
  }

  Future<void> exportDatabase() async {
    final path = await DatabaseService.getDatabasePath();
    final file = File(path);
    if (await file.exists()) {
      final xFile = XFile(path);
      await Share.shareXFiles([xFile], text: 'Simple Sale Baza Zaxira Nusxasi');
    }
  }

  Future<void> importDatabase() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      File file = File(result.files.single.path!);
      await DatabaseService.replaceDatabase(file);
      await loadSettings(); // Refresh everything
      notifyListeners();
    }
  }

  Future<void> deleteInventory(String id) async {
    final index = inventories.indexWhere((i) => i.id == id);
    if (index >= 0) {
      final inv = inventories[index];
      // Revert stock back to expected quantity before the inventory change
      for (var item in inv.items) {
        final pIdx = products.indexWhere((p) => p.id == item.productId);
        if (pIdx >= 0) {
          final p = products[pIdx];
          if (p.trackStock) {
            p.stocks[inv.warehouseId] = item.expectedQuantity;
            await DatabaseService.updateStock(
              p.id,
              inv.warehouseId,
              item.expectedQuantity,
            );
          }
        }
      }
      await DatabaseService.deleteInventory(id);
      await _sendUpdate('inventory_delete', {'id': id});
      inventories.removeAt(index);
      notifyListeners();
    }
  }

  Future<void> updateStockEntry(StockEntry newEntry) async {
    final index = stockEntries.indexWhere((e) => e.id == newEntry.id);
    if (index >= 0) {
      final oldEntry = stockEntries[index];
      // 1. Revert Old
      for (var item in oldEntry.items) {
        final pIdx = products.indexWhere((p) => p.id == item.productId);
        if (pIdx >= 0 && products[pIdx].trackStock) {
          final p = products[pIdx];
          p.stocks[oldEntry.warehouseId] =
              (p.stocks[oldEntry.warehouseId] ?? 0) - item.quantity;
          await DatabaseService.updateStock(
            p.id,
            oldEntry.warehouseId,
            p.stocks[oldEntry.warehouseId]!,
          );
        }
      }
      // 2. Apply New
      for (var item in newEntry.items) {
        final pIdx = products.indexWhere((p) => p.id == item.productId);
        if (pIdx >= 0 && products[pIdx].trackStock) {
          final p = products[pIdx];
          p.stocks[newEntry.warehouseId] =
              (p.stocks[newEntry.warehouseId] ?? 0) + item.quantity;
          await DatabaseService.updateStock(
            p.id,
            newEntry.warehouseId,
            p.stocks[newEntry.warehouseId]!,
          );
        }
      }
      await DatabaseService.deleteStockEntry(newEntry.id);
      await DatabaseService.saveStockEntry(newEntry);
      await _sendUpdate('stock_entry', newEntry.toJson());
      stockEntries[index] = newEntry;
      notifyListeners();
    }
  }

  Future<void> updateReturn(SaleReturn newReturn) async {
    final index = returns.indexWhere((r) => r.id == newReturn.id);
    if (index >= 0) {
      final oldReturn = returns[index];
      // 1. Revert Old
      for (var item in oldReturn.items) {
        final pIdx = products.indexWhere((p) => p.id == item.productId);
        if (pIdx >= 0 && products[pIdx].trackStock) {
          final p = products[pIdx];
          p.stocks[oldReturn.warehouseId] =
              (p.stocks[oldReturn.warehouseId] ?? 0) - item.quantity;
          await DatabaseService.updateStock(
            p.id,
            oldReturn.warehouseId,
            p.stocks[oldReturn.warehouseId]!,
          );
        }
      }
      // 2. Apply New
      for (var item in newReturn.items) {
        final pIdx = products.indexWhere((p) => p.id == item.productId);
        if (pIdx >= 0 && products[pIdx].trackStock) {
          final p = products[pIdx];
          p.stocks[newReturn.warehouseId] =
              (p.stocks[newReturn.warehouseId] ?? 0) + item.quantity;
          await DatabaseService.updateStock(
            p.id,
            newReturn.warehouseId,
            p.stocks[newReturn.warehouseId]!,
          );
        }
      }
      await DatabaseService.deleteReturn(newReturn.id);
      await DatabaseService.saveReturn(newReturn);
      await _sendUpdate('return', newReturn.toJson());
      returns[index] = newReturn;
      notifyListeners();
    }
  }

  Future<void> updateWriteOff(WriteOff newWo) async {
    final index = writeOffs.indexWhere((w) => w.id == newWo.id);
    if (index >= 0) {
      final oldWo = writeOffs[index];
      // 1. Revert Old (it decreased stock, so we increase)
      for (var item in oldWo.items) {
        final pIdx = products.indexWhere((p) => p.id == item.productId);
        if (pIdx >= 0 && products[pIdx].trackStock) {
          final p = products[pIdx];
          p.stocks[oldWo.warehouseId] =
              (p.stocks[oldWo.warehouseId] ?? 0) + item.quantity;
          await DatabaseService.updateStock(
            p.id,
            oldWo.warehouseId,
            p.stocks[oldWo.warehouseId]!,
          );
        }
      }
      // 2. Apply New (it decreases stock)
      for (var item in newWo.items) {
        final pIdx = products.indexWhere((p) => p.id == item.productId);
        if (pIdx >= 0 && products[pIdx].trackStock) {
          final p = products[pIdx];
          p.stocks[newWo.warehouseId] =
              (p.stocks[newWo.warehouseId] ?? 0) - item.quantity;
          await DatabaseService.updateStock(
            p.id,
            newWo.warehouseId,
            p.stocks[newWo.warehouseId]!,
          );
        }
      }
      await DatabaseService.deleteWriteOff(newWo.id);
      await DatabaseService.saveWriteOff(newWo);
      await _sendUpdate('write_off', newWo.toJson());
      writeOffs[index] = newWo;
      notifyListeners();
    }
  }

  Future<void> updateInventory(InventoryEntry newInv) async {
    final index = inventories.indexWhere((i) => i.id == newInv.id);
    if (index >= 0) {
      final oldInv = inventories[index];
      // 1. Revert Old (restore to its expectedQuantity)
      for (var item in oldInv.items) {
        final pIdx = products.indexWhere((p) => p.id == item.productId);
        if (pIdx >= 0 && products[pIdx].trackStock) {
          final p = products[pIdx];
          p.stocks[oldInv.warehouseId] = item.expectedQuantity;
          await DatabaseService.updateStock(
            p.id,
            oldInv.warehouseId,
            item.expectedQuantity,
          );
        }
      }
      // 2. Apply New (set to new actualQuantity)
      for (var item in newInv.items) {
        final pIdx = products.indexWhere((p) => p.id == item.productId);
        if (pIdx >= 0 && products[pIdx].trackStock) {
          final p = products[pIdx];
          // Notice: expectedQuantity might have changed if stock changed meantime,
          // but we just trust newInv.items which has the fresh recalculation.
          p.stocks[newInv.warehouseId] = item.actualQuantity;
          await DatabaseService.updateStock(
            p.id,
            newInv.warehouseId,
            item.actualQuantity,
          );
        }
      }
      await DatabaseService.deleteInventory(newInv.id);
      await DatabaseService.saveInventory(newInv);
      await _sendUpdate('inventory', newInv.toJson());
      inventories[index] = newInv;
      notifyListeners();
    }
  }

  // --- Activation System ---
  String get activationRequestCode {
    if (deviceId == null) return "Unknown";
    // Generate a shorter, user-friendly request code from deviceId
    return deviceId!.substring(0, 8).toUpperCase();
  }

  bool checkActivationCode(String code) {
    if (deviceId == null) return false;
    // Simple secret algorithm:
    // Take first 8 chars of deviceId, reverse them, and add a secret suffix
    final secret = deviceId!.substring(0, 8).split('').reversed.join('');
    final expected = "SS-$secret-OK".toUpperCase();
    return code.toUpperCase() == expected;
  }

  Future<void> activate(String code, {bool online = true}) async {
    final prefs = await SharedPreferences.getInstance();

    if (online) {
      const backendUrl = "https://web-production-d2ed7.up.railway.app/verify";
      try {
        final response = await http
            .post(
              Uri.parse(backendUrl),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({
                "device_id": deviceId,
                "activation_code": code,
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          isActivated = true;
          activationCode = code;
          organizationName = data['organization_name'] ?? 'Simple Sale';
          organizationAddress = data['organization_address'] ?? '';
          instagramUsername = data['instagram'] ?? '';
          isBlocked = false;
          await prefs.setBool('isActivated', true);
          await prefs.setString('activationCode', code);
          await prefs.setString('organizationName', organizationName!);
          await prefs.setString('organizationAddress', organizationAddress!);
          await prefs.setString('instagramUsername', instagramUsername!);
          
          // Yangi tashkilotga o'tilganda eski ma'lumotlarni o'chirib tashlaymiz
          await DatabaseService.clearAllData();
          await _loadFromDb(); // Xotirani ham tozalaymiz

          // Attempt cloud restore after activation (professional: don't fail if no backup exists yet)
          try {
            await restoreDatabaseFromCloud();
          } catch (e) {
            debugPrint("Initial cloud restore (no backup yet): $e");
          }

          notifyListeners();
        } else if (response.statusCode == 403) {
          final data = jsonDecode(response.body);
          final detail = data['detail'] ?? "Aktivatsiya xatosi";
          if (detail.toString().contains("bloklangan")) {
            isBlocked = true;
            notifyListeners();
          }
          throw Exception(detail);
        } else {
          throw Exception("Server xatosi: ${response.statusCode}");
        }
      } catch (e) {
        if (e.toString().contains("bloklangan")) rethrow;
        throw Exception("Internet ulanishini tekshiring: $e");
      }
    } else {
      // Offline fallback
      if (checkActivationCode(code)) {
        isActivated = true;
        activationCode = code;
        await prefs.setBool('isActivated', true);
        await prefs.setString('activationCode', code);
        notifyListeners();
      } else {
        throw Exception("Noto'g'ri aktivatsiya kodi");
      }
    }
  }

  Future<void> checkBlockingStatus() async {
    if (!isActivated || activationCode == null) return;

    try {
      const backendUrl = "https://web-production-d2ed7.up.railway.app/verify";
      final response = await http
          .post(
            Uri.parse(backendUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "device_id": deviceId,
              "activation_code": activationCode,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        if (data['detail']?.toString().contains("bloklangan") == true) {
          isBlocked = true;
          notifyListeners();
        }
      } else if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Update name if different
        bool changed = false;
        final prefs = await SharedPreferences.getInstance();
        
        if (data['organization_name'] != null && data['organization_name'] != organizationName) {
          organizationName = data['organization_name'];
          await prefs.setString('organizationName', organizationName!);
          changed = true;
        }
        if (data['organization_address'] != null && data['organization_address'] != organizationAddress) {
          organizationAddress = data['organization_address'];
          await prefs.setString('organizationAddress', organizationAddress!);
          changed = true;
        }
        if (data['instagram'] != null && data['instagram'] != instagramUsername) {
          instagramUsername = data['instagram'];
          await prefs.setString('instagramUsername', instagramUsername!);
          changed = true;
        }

        if (changed) notifyListeners();

        if (data['force_logout'] == true) {
          debugPrint("Remote kick triggered. Backing up and clearing data...");
          try {
            // 1. Try to backup data first
            await uploadDatabaseToCloud();
          } catch (e) {
            debugPrint("Backup before kick failed: $e");
          }
          // 2. Clear all local data and reset app state (fresh install state)
          await clearAllData();
          return; // No need to continue
        }
        if (isBlocked) {
          isBlocked = false;
          notifyListeners();
        }
      }
    } catch (e) {
      // Ignore network errors for background check, just keep current state
      debugPrint("Blocking check failed: $e");
    }
  }

  Future<void> uploadDatabaseToCloud() async {
    if (!isActivated || activationCode == null) {
      throw Exception('Dastur faollashtirilmagan');
    }

    final dbPath = await DatabaseService.getDatabasePath();
    final file = File(dbPath);
    if (!await file.exists()) throw Exception('Baza fayli topilmadi');

    const uploadUrl = "https://web-production-d2ed7.up.railway.app/backup";

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$uploadUrl?activation_code=$activationCode'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', dbPath));

      var response = await request.send().timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw Exception('Zaxira yuklashda xatolik: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Serverga ulanib bo\'lmadi: $e');
    }
  }

  Future<void> restoreDatabaseFromCloud() async {
    if (!isActivated || activationCode == null) {
      throw Exception('Dastur faollashtirilmagan');
    }

    final downloadUrl = "https://web-production-d2ed7.up.railway.app/backup/$activationCode";
    debugPrint("Restoring from cloud: $downloadUrl");

    try {
      final response = await http
          .get(Uri.parse(downloadUrl))
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        if (response.bodyBytes.isEmpty) {
           throw Exception('Serverdan bo\'sh fayl keldi');
        }
        
        final supportDir = await getApplicationSupportDirectory();
        final tempFile = File(join(supportDir.path, 'cloud_restore_temp.db'));
        
        // Ensure directory exists
        if (!await supportDir.exists()) {
          await supportDir.create(recursive: true);
        }
        
        await tempFile.writeAsBytes(response.bodyBytes);
        debugPrint("Cloud backup downloaded, size: ${response.bodyBytes.length} bytes");
        
        await DatabaseService.replaceDatabase(tempFile);
        
        // Cleanup temp file
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        
        await loadSettings();
        notifyListeners();
        debugPrint("Cloud restore successful");
      } else if (response.statusCode == 404) {
        debugPrint('Cloud backup not found for this account (ignore if brand new)');
      } else {
        throw Exception('Bulutdan zaxirani yuklab bo\'lmadi (Server xatosi: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint("Restore error detail: $e");
      rethrow;
    }
  }

  Future<void> updateOrganizationInfo({String? name, String? address, String? instagram}) async {
    if (!isActivated || activationCode == null) {
      throw Exception('Dastur faollashtirilmagan');
    }

    const url = "https://web-production-d2ed7.up.railway.app/update_org_info";
    
    Map<String, String> queryParams = {"activation_code": activationCode!};
    if (name != null) queryParams["name"] = name;
    if (address != null) queryParams["address"] = address;
    if (instagram != null) queryParams["instagram"] = instagram;

    final uri = Uri.parse(url).replace(queryParameters: queryParams);
    
    try {
      final response = await http.post(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        if (name != null) {
          organizationName = name;
          await prefs.setString('organizationName', name);
        }
        if (address != null) {
          organizationAddress = address;
          await prefs.setString('organizationAddress', address);
        }
        if (instagram != null) {
          instagramUsername = instagram;
          await prefs.setString('instagramUsername', instagram);
        }
        notifyListeners();
      } else {
        throw Exception('Server xatosi: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Ma\'lumotlarni yangilab bo\'lmadi: $e');
    }
  }

  String generateBarcode() {
    // Generate a simple unique barcode (e.g. 13 digits starting with 200 for internal use)
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString();
    // Use last 10 digits of timestamp + a random digit to make it 11, then add 200 at start
    final core = timestamp.substring(timestamp.length - 10);
    return '200$core';
  }

  Future<void> updateOrganizationLogo(String? path) async {
    organizationLogoPath = path;
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove('organizationLogoPath');
    } else {
      await prefs.setString('organizationLogoPath', path);
    }
    notifyListeners();
  }

  // Remove old updateOrganizationName as it's replaced by updateOrganizationInfo
  @Deprecated('Use updateOrganizationInfo instead')
  Future<void> updateOrganizationName(String newName) async {
    await updateOrganizationInfo(name: newName);
  }

  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Close DB properly before deleting (Critical for Windows)
      await DatabaseService.closeDatabase();

      final dbPath = await DatabaseService.getDatabasePath();
      final file = File(dbPath);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Data clear error: $e');
    }

    // Reset local state regardless of file deletion success
    isMaster = null;
    isActivated = false;
    isBlocked = false;
    activationCode = null;
    currentRegister = null;
    registers = [];
    products = [];
    categories = [];
    sales = [];

    notifyListeners();
  }
}
