import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../services/database_service.dart';
import '../../models/models.dart';
import '../../core/constants/app_constants.dart';
import 'dart:io';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  String? selectedPrinterName;
  String? barcodePrinterName;
  String? networkPrinterIp;
  String? networkBarcodePrinterIp;
  int receiptWidth = 80;
  String receiptFooterText = 'Xaridingiz uchun rahmat!';
  bool showInstagramOnReceipt = true;
  
  String? organizationName = 'Biznes Nomi';
  String? organizationAddress = 'O\'zbekiston';
  String? instagramUsername = '@simplesale';
  
  List<Register> registers = [];
  Register? currentRegister;
  
  bool isBarcodeScanMode = false;
  bool shouldTrackInventory = true;
  bool isFullScreen = false;
  bool isStarterDataLoaded = false;
  String appVersion = AppConstants.appVersion;
  String? deviceId;

  // Scale Settings
  String? scalePort;
  int scaleBaudRate = 9600;
  String scaleProtocol = 'NCI'; // NCI, CAS, POS
  
  StreamSubscription<void>? _dbSubscription;

  SettingsProvider() {
    _dbSubscription = DatabaseService.dbUpdateStream.stream.listen((_) {
      debugPrint("SettingsProvider: Background data change detected. Reloading...");
      loadSettings(isInitialLoad: false);
    });
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadSettings({bool isInitialLoad = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Professional: Safe boolean parsing from SharedPreferences
      bool getSafeBool(String key, {bool defaultValue = false}) {
        try {
          return prefs.getBool(key) ?? defaultValue;
        } catch (_) {
          try {
            final val = prefs.get(key);
            if (val is int) return val == 1;
            if (val is String) return val.toLowerCase() == 'true';
            return defaultValue;
          } catch (__) {
            return defaultValue;
          }
        }
      }

      // 1. Device Identification
      deviceId = prefs.getString('deviceId');
      if (deviceId == null) {
        deviceId = const Uuid().v4();
        await prefs.setString('deviceId', deviceId!);
      }

      // 2. Load basic prefs
      final savedTheme = prefs.getString('themeMode');
      _themeMode = savedTheme == 'light' ? ThemeMode.light : (savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.system);
      
      isBarcodeScanMode = getSafeBool('isBarcodeScanMode');
      receiptWidth = prefs.getInt('receiptWidth') ?? 80;

      // 3. Load from Database (Source of Truth for persistence)
      final dbSettings = await DatabaseService.getAllSettings();
      
      organizationName = dbSettings['organizationName'] ?? prefs.getString('organizationName') ?? 'Mening Do\'konim';
      organizationAddress = dbSettings['organizationAddress'] ?? prefs.getString('organizationAddress') ?? 'O\'zbekiston';
      instagramUsername = dbSettings['instagramUsername'] ?? prefs.getString('organizationAddress') ?? '@simplesale';
      
      selectedPrinterName = dbSettings['selectedPrinterName'] ?? prefs.getString('selectedPrinterName');
      barcodePrinterName = dbSettings['barcodePrinterName'] ?? prefs.getString('barcodePrinterName');
      networkPrinterIp = dbSettings['networkPrinterIp'] ?? prefs.getString('networkPrinterIp');
      networkBarcodePrinterIp = dbSettings['networkBarcodePrinterIp'] ?? prefs.getString('networkBarcodePrinterIp');
      
      receiptFooterText = dbSettings['receiptFooterText'] ?? prefs.getString('receiptFooterText') ?? 'Xaridingiz uchun rahmat!';
      
      // showInstagramOnReceipt is complex because it can be in both DB and Prefs as different formats
      final dbShowInsta = dbSettings['showInstagramOnReceipt'];
      if (dbShowInsta != null) {
        showInstagramOnReceipt = dbShowInsta.toLowerCase() == 'true' || dbShowInsta == '1';
      } else {
        showInstagramOnReceipt = getSafeBool('showInstagramOnReceipt', defaultValue: true);
      }
      
      // shouldTrackInventory persistence
      final dbTrackStock = dbSettings['shouldTrackInventory'];
      if (dbTrackStock != null) {
        shouldTrackInventory = dbTrackStock.toLowerCase() == 'true' || dbTrackStock == '1';
      } else {
        shouldTrackInventory = getSafeBool('shouldTrackInventory', defaultValue: true);
      }

      // 4. Load Registers and selection
      registers = await DatabaseService.getRegisters();
      final savedRegId = prefs.getString('currentRegisterId');
      if (savedRegId != null) {
        final matching = registers.where((r) => r.id == savedRegId).toList();
        if (matching.isNotEmpty && matching.first.activeDeviceId == deviceId) {
          currentRegister = matching.first;
        }
      }

      // 5. Load App Version from platform
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = packageInfo.version;
      } catch (e) {
        debugPrint('Error loading package info: $e');
      }

      // 6. Load Scale Settings
      scalePort = dbSettings['scalePort'] ?? prefs.getString('scalePort');
      scaleBaudRate = int.tryParse(dbSettings['scaleBaudRate'] ?? '') ?? prefs.getInt('scaleBaudRate') ?? 9600;
      scaleProtocol = dbSettings['scaleProtocol'] ?? prefs.getString('scaleProtocol') ?? 'NCI';

      // 7. Full Screen Mode (Apply window size only on startup or explicit toggle)
      isStarterDataLoaded = getSafeBool('isStarterDataLoaded', defaultValue: false);
      isFullScreen = getSafeBool('isFullScreen', defaultValue: false);
      if (isInitialLoad && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        await windowManager.setFullScreen(isFullScreen);
        if (!isFullScreen) {
          await windowManager.setSize(const Size(1280, 800));
          await windowManager.center();
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.toString().split('.').last);
    notifyListeners();
  }

  Future<void> toggleBarcodeScanMode() async {
    isBarcodeScanMode = !isBarcodeScanMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isBarcodeScanMode', isBarcodeScanMode);
    notifyListeners();
  }


  Future<void> updateCurrentRegister(Register? register) async {
    currentRegister = register;
    final prefs = await SharedPreferences.getInstance();
    
    if (register == null) {
      await prefs.remove('currentRegisterId');
    } else {
      await prefs.setString('currentRegisterId', register.id);
      if (deviceId != null) {
        // Claim this register for this device in the DB
        await DatabaseService.updateRegisterDevice(register.id, deviceId);
      }
    }
    notifyListeners();
  }

  Future<void> updateOrganizationInfo({String? name, String? address, String? instagram}) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) {
      organizationName = name;
      await prefs.setString('organizationName', name);
      await DatabaseService.saveSetting('organizationName', name);
    }
    if (address != null) {
      organizationAddress = address;
      await prefs.setString('organizationAddress', address);
      await DatabaseService.saveSetting('organizationAddress', address);
    }
    if (instagram != null) {
      instagramUsername = instagram;
      await prefs.setString('instagramUsername', instagram);
      await DatabaseService.saveSetting('instagramUsername', instagram);
    }
    notifyListeners();
  }

  Future<void> updateReceiptSettings({String? footer, bool? showInstagram, int? width}) async {
    final prefs = await SharedPreferences.getInstance();
    if (footer != null) {
      receiptFooterText = footer;
      await DatabaseService.saveSetting('receiptFooterText', footer);
    }
    if (showInstagram != null) {
      showInstagramOnReceipt = showInstagram;
      await DatabaseService.saveSetting('showInstagramOnReceipt', showInstagram.toString());
    }
    if (width != null) {
      receiptWidth = width;
      await prefs.setInt('receiptWidth', width);
      await DatabaseService.saveSetting('receiptWidth', width.toString());
    }
    notifyListeners();
  }

  Future<void> updatePrinter(String name) async {
    selectedPrinterName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedPrinterName', name);
    await DatabaseService.saveSetting('selectedPrinterName', name);
    notifyListeners();
  }

  Future<void> updateBarcodePrinter(String name) async {
    barcodePrinterName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('barcodePrinterName', name);
    await DatabaseService.saveSetting('barcodePrinterName', name);
    notifyListeners();
  }

  Future<void> updateNetworkPrinterIp(String ip) async {
    networkPrinterIp = ip;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('networkPrinterIp', ip);
    await DatabaseService.saveSetting('networkPrinterIp', ip);
    notifyListeners();
  }

  Future<void> updateNetworkBarcodePrinterIp(String ip) async {
    networkBarcodePrinterIp = ip;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('networkBarcodePrinterIp', ip);
    await DatabaseService.saveSetting('networkBarcodePrinterIp', ip);
    notifyListeners();
  }

  Future<void> clearAllData() async {
    await DatabaseService.clearAllData();
    final prefs = await SharedPreferences.getInstance();
    final dId = prefs.getString('deviceId');
    await prefs.clear();
    if (dId != null) await prefs.setString('deviceId', dId); // Keep the device identity
    await loadSettings();
  }

  Future<void> toggleInventoryTracking() async {
    shouldTrackInventory = !shouldTrackInventory;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shouldTrackInventory', shouldTrackInventory);
    await DatabaseService.saveSetting('shouldTrackInventory', shouldTrackInventory ? '1' : '0');
    // Force recalculate stocks to apply/remove sale impacts immediately
    await DatabaseService.recalculateStocks(force: true);
  }

  Future<void> updateScaleSettings({String? port, int? baudRate, String? protocol}) async {
    final prefs = await SharedPreferences.getInstance();
    if (port != null) {
      scalePort = port;
      await prefs.setString('scalePort', port);
      await DatabaseService.saveSetting('scalePort', port);
    }
    if (baudRate != null) {
      scaleBaudRate = baudRate;
      await prefs.setInt('scaleBaudRate', baudRate);
      await DatabaseService.saveSetting('scaleBaudRate', baudRate.toString());
    }
    if (protocol != null) {
      scaleProtocol = protocol;
      await prefs.setString('scaleProtocol', protocol);
      await DatabaseService.saveSetting('scaleProtocol', protocol);
    }
    notifyListeners();
  }

  Future<void> markStarterDataAsLoaded() async {
    isStarterDataLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isStarterDataLoaded', true);
    notifyListeners();
  }

  Future<void> toggleFullScreen() async {
    isFullScreen = !isFullScreen;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFullScreen', isFullScreen);
    
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      if (isFullScreen) {
        await windowManager.setFullScreen(true);
      } else {
        await windowManager.setFullScreen(false);
        await windowManager.setSize(const Size(1280, 800));
        await windowManager.center();
      }
    }
    notifyListeners();
  }
}
