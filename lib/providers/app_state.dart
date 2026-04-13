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
import '../core/constants/app_constants.dart';

class AppState extends ChangeNotifier {
  Register? currentRegister;
  bool isInitialized = false;
  String? initializationError;
  bool? isMaster;
  String? masterAddress;
  String? deviceId;
  String? masterPassword;
  String appVersion = AppConstants.appVersion;
  bool isPublicNetwork = false;
  String? currentNetworkName;

  List<Category> categories = [];
  List<Product> products = [];
  List<Warehouse> warehouses = [];
  List<Register> registers = [];
  List<Sale> sales = [];
  List<SaleReturn> returns = [];
  List<WriteOff> writeOffs = [];
  List<InventoryEntry> inventories = [];
  List<StockEntry> stockEntries = [];
  List<StockTransfer> stockTransfers = [];


  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool _isBarcodeScanMode = false;
  bool get isBarcodeScanMode => _isBarcodeScanMode;

  String? organizationName;
  String? organizationAddress;
  String? instagramUsername;
  bool isCloudMode = false;
  DateTime? lastCloudSync;

  Future<List<String>> get allLocalIps async {
    try {
      final interfaces = await NetworkInterface.list();
      List<String> allIps = [];

      for (var interface in interfaces) {
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

      if (allIps.isEmpty) return [];
      
      allIps.sort((a, b) {
         if (a.startsWith('192.168.')) return -1;
         if (b.startsWith('192.168.')) return 1;
         return 0;
      });
      
      return allIps;
    } catch (e) {
      return [];
    }
  }

  Future<String?> get localIp async {
    final ips = await allLocalIps;
    return ips.isNotEmpty ? ips.first : null;
  }

  // Logic for today stats
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
  Warehouse? get mainWarehouse =>
      warehouses.where((w) => w.isMain).firstOrNull ??
      (warehouses.isNotEmpty ? warehouses.first : null);

  AppState() {
    loadSettings();
    DatabaseService.dbUpdateStream.stream.listen((_) => reloadData());
    
    if (Platform.isWindows) {
      checkNetworkProfile();
    }
  }

  Future<void> reloadData() async {
    await _loadFromDb();
    notifyListeners();
  }

  Future<void> _loadFromDb() async {
    try {
      categories = await DatabaseService.getCategories();
      products = await DatabaseService.getProducts();
      warehouses = await DatabaseService.getWarehouses();
      registers = await DatabaseService.getRegisters();
      sales = await DatabaseService.getSales();
      returns = await DatabaseService.getReturns();
      writeOffs = await DatabaseService.getWriteOffs();
      inventories = await DatabaseService.getInventories();
      stockEntries = await DatabaseService.getStockEntries();
      stockTransfers = await DatabaseService.getStockTransfers();
      
      final prefs = await SharedPreferences.getInstance();
      final savedRegId = prefs.getString('currentRegisterId');
      if (savedRegId != null) {
        final matching = registers.where((r) => r.id == savedRegId).toList();
        if (matching.isNotEmpty && matching.first.activeDeviceId == deviceId) {
          currentRegister = matching.first;
        }
      }
    } catch (e) {
      debugPrint('Error loading from DB: $e');
    }
  }


  Future<void> setTerminalMode(
    bool master, {
    String? ip,
    String? password,
    bool isCloud = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isCloudMode', isCloud);

    if (isCloud) {
       await prefs.setBool('isMaster', true);
       if (password != null && password.isNotEmpty) {
          await prefs.setString('masterPassword', password);
          masterPassword = password;
       }
       isMaster = true;
       _startServer();
    } else if (master == false) {
      if (ip == null || ip.isEmpty) throw Exception('IP manzilni kiriting');
      masterAddress = ip;
      isMaster = false;
      await prefs.setBool('isMaster', false);
      await prefs.setString('masterAddress', ip);
      await prefs.setBool('isActivated', true);
    } else {
      await prefs.setBool('isMaster', true);
      if (password != null) {
        await prefs.setString('masterPassword', password);
        masterPassword = password;
      }
      isMaster = true;
      _startServer();
    }
    notifyListeners();
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

  void toggleTheme() {
    if (_themeMode == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }

  Future<void> _applyRemoteUpdate(
    String type,
    Map<String, dynamic> data,
  ) async {
    try {
      switch (type) {
        case 'category':
        case 'product':
        case 'warehouse':
        case 'register':
        case 'user':
        case 'stock_entry':
        case 'sale':
        case 'return':
        case 'write_off':
        case 'inventory':
        case 'stock_transfer':
        case 'organization':
          String table = type;
          if (type == 'category') table = 'categories';
          if (type == 'product') table = 'products';
          if (type == 'warehouse') table = 'warehouses';
          if (type == 'register') table = 'registers';
          if (type == 'user') table = 'users';
          if (type == 'organization') table = 'organizations';
          if (type == 'stock_entry') table = 'stock_entries';
          if (type == 'sale') table = 'sales';
          if (type == 'return') table = 'returns';
          if (type == 'write_off') table = 'write_offs';
          if (type == 'inventory') table = 'inventories';
          if (type == 'stock_transfer') table = 'stock_transfers';
          
          await DatabaseService.saveSyncedRecord(table, data);
          break;
        case 'warehouse_delete':
          await DatabaseService.deleteWarehouse(data['id']);
          break;
        case 'register_delete':
          await DatabaseService.deleteRegister(data['id']);
          break;
        case 'organization_delete':
          await DatabaseService.deleteOrganization(data['id']);
          break;
        case 'setting':
          await DatabaseService.saveSetting(data['key'], data['value'].toString());
          break;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error applying remote update ($type): $e');
    }
  }

  Future<void> clearAllData() async {
    await DatabaseService.clearAllData();
    final prefs = await SharedPreferences.getInstance();
    final dId = prefs.getString('deviceId');
    await prefs.clear();
    if (dId != null) await prefs.setString('deviceId', dId);
    
    isMaster = null;
    initializationError = null;
    currentRegister = null;
    notifyListeners();
  }

  Future<void> resetTerminalMode() async {
    await clearAllData();
    SyncService.stopServer();
    initializationError = null;
    isInitialized = true;
    notifyListeners();
  }

  Future<void> _setupFirewallRules() async {
    if (Platform.isWindows) {
      try {
        final exePath = Platform.resolvedExecutable;
        await Process.run('netsh', [
          'advfirewall', 'firewall', 'add', 'rule',
          'name=Simple Sale Sync Port', 'dir=in', 'action=allow',
          'protocol=TCP', 'localport=8080', 'profile=any',
        ]);
        await Process.run('netsh', [
          'advfirewall', 'firewall', 'add', 'rule',
          'name=Simple Sale Business Out', 'dir=out', 'action=allow',
          'program=$exePath', 'enable=yes', 'profile=any',
        ]);
        await Process.run('netsh', [
          'advfirewall', 'firewall', 'add', 'rule',
          'name=Simple Sale Business', 'dir=in', 'action=allow',
          'program=$exePath', 'enable=yes', 'profile=any',
        ]);
        debugPrint('Windows Firewall rules automated.');
      } catch (e) {
        debugPrint('Manual admin intervention required for firewall: $e');
      }
    }
  }

  Future<bool> fixNetworkConnection() async {
    await _setupFirewallRules();
    try {
      final res = await http.get(Uri.parse('https://google.com')).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void _startServer() {
    SyncService.startServer(
      onSaleReceived: (saleData) async {
        final sale = Sale.fromJson(saleData);
        final existing = await DatabaseService.getSaleById(sale.id);
        if (existing != null) return;
        
        await DatabaseService.saveSale(sale);

        for (var item in sale.items) {
          final product = await DatabaseService.getProductById(item.productId);
          if (product != null && product.trackStock) {
            final stocks = await DatabaseService.getProductStocks(product.id);
            final currentStock = stocks[sale.warehouseId] ?? 0;
            final newStock = currentStock - item.quantity;
            await DatabaseService.updateStock(
              item.productId,
              sale.warehouseId,
              newStock,
            );
          }
        }
        SyncService.broadcast('sale', saleData);
        notifyListeners();
      },
      onUpdateReceived: (type, data) async {
        await _applyRemoteUpdate(type, data);
        SyncService.broadcast(type, data);
      },
      onBatchUpdateReceived: (batch) async {
        for (var table in batch.keys) {
          final List records = batch[table];
          for (var record in records) {
            String type = table;
            if (table == 'write_offs') type = 'write_off';
            if (table == 'inventories') type = 'inventory';
            if (table == 'stock_entries') type = 'stock_entry';
            if (table == 'stock_transfers') type = 'stock_transfer';
            if (table == 'categories') type = 'category';
            if (table == 'products') type = 'product';
            if (table == 'warehouses') type = 'warehouse';
            if (table == 'registers') type = 'register';
            if (table == 'sales') type = 'sale';
            if (table == 'returns') type = 'return';
            if (table == 'users') type = 'user';
      if (type == 'stock_transfer') type = 'stock_transfer';
            if (type == 'categories') type = 'category';
            if (type == 'products') type = 'product';
            if (type == 'warehouses') type = 'warehouse';
            if (type == 'registers') type = 'register';
            if (type == 'sales') type = 'sale';
            if (type == 'returns') type = 'return';
            if (type == 'users') type = 'user';

            await _applyRemoteUpdate(type, record);
            SyncService.broadcast(type, record);
          }
        }
        notifyListeners();
      },
      onSyncRequested: () async {
        final users = await DatabaseService.getUsers();
        final categories = await DatabaseService.getCategories();
        final products = await DatabaseService.getProducts();
        final warehouses = await DatabaseService.getWarehouses();
        final registers = await DatabaseService.getRegisters();
        final returns = await DatabaseService.getReturns();
        final writeOffs = await DatabaseService.getWriteOffs();
        final inventories = await DatabaseService.getInventories();
        final organizations = await DatabaseService.getOrganizations();
        final prefs = await SharedPreferences.getInstance();

        return {
          'categories': categories.map((c) => c.toJson()).toList(),
          'products': products.map((p) => p.toJson()).toList(),
          'warehouses': warehouses.map((w) => w.toJson()).toList(),
          'registers': registers.map((r) => r.toJson()).toList(),
          'returns': returns.map((r) => r.toJson()).toList(),
          'writeOffs': writeOffs.map((w) => w.toJson()).toList(),
          'inventories': inventories.map((i) => i.toJson()).toList(),
          'users': users.map((u) => u.toJson()).toList(),
          'organizations': organizations.map((o) => o.toJson()).toList(),
          'organizationName': prefs.getString('organizationName'),
          'organizationAddress': prefs.getString('organizationAddress'),
          'instagramUsername': prefs.getString('instagramUsername'),
          'settings': {
            'barcodePrinterName': prefs.getString('barcodePrinterName') ?? '',
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
        
        final registers = await DatabaseService.getRegisters();
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

        for (var r in registers) {
          if (r.activeDeviceId == rDeviceId) {
            final cleared = Register(
              id: r.id,
              name: r.name,
              warehouseId: r.warehouseId,
              activeDeviceId: null,
            );
            await DatabaseService.saveRegister(cleared);
          }
        }

        final updated = Register(
          id: reg.id,
          name: reg.name,
          warehouseId: reg.warehouseId,
          activeDeviceId: rDeviceId,
        );
        await DatabaseService.saveRegister(updated);

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

  Future<void> checkNetworkProfile() async {
    if (!Platform.isWindows) return;
    
    try {
      final result = await Process.run('powershell', [
        '-Command',
        'Get-NetConnectionProfile | Select-Object -Property InterfaceAlias, NetworkCategory | ConvertTo-Json'
      ]);

      if (result.exitCode == 0) {
        final decoded = jsonDecode(result.stdout);
        if (decoded is List) {
          isPublicNetwork = decoded.any((item) => item['NetworkCategory'] == 2); // 2 is Public
          if (decoded.isNotEmpty) currentNetworkName = decoded.first['InterfaceAlias'];
        } else if (decoded is Map) {
          isPublicNetwork = decoded['NetworkCategory'] == 2;
          currentNetworkName = decoded['InterfaceAlias'];
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking network profile: $e');
    }
  }

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      bool? getSafeBool(String key) {
        try {
          return prefs.getBool(key);
        } catch (_) {
          try {
            final val = prefs.get(key);
            if (val is int) return val == 1;
            if (val is String) return val.toLowerCase() == 'true';
            return null;
          } catch (__) {
            return null;
          }
        }
      }

      final master = getSafeBool('isMaster');
      final ip = prefs.getString('masterAddress');
      masterPassword = prefs.getString('masterPassword');

      isMaster = master;
      isCloudMode = getSafeBool('isCloudMode') ?? false;
      masterAddress = ip;
      deviceId = prefs.getString('deviceId') ?? const Uuid().v4();
      await prefs.setString('deviceId', deviceId!);
      
      organizationName = prefs.getString('organizationName') ?? 'test';
      organizationAddress = prefs.getString('organizationAddress') ?? 'O\'zbekiston, Toshkent';
      instagramUsername = prefs.getString('instagramUsername') ?? '@simplesale';

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

      final lastSyncStr = prefs.getString('lastCloudSync');
      if (lastSyncStr != null) {
        try {
          lastCloudSync = DateTime.parse(lastSyncStr);
        } catch (_) {}
      }

      await reloadData();

      if (isMaster == true) {
        _startServer();
        _setupFirewallRules();
      }
    } catch (e) {
      initializationError = e.toString();
      debugPrint('loadSettings xatosi: $e');
    } finally {
      isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> retryInitialization() async {
    initializationError = null;
    isInitialized = false;
    notifyListeners();
    await DatabaseService.closeDatabase();
    await loadSettings();
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
}
