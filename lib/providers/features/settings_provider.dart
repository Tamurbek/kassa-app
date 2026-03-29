import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
  bool showLogoOnReceipt = true;
  bool showInstagramOnReceipt = true;
  
  String? organizationName = 'Biznes Nomi';
  String? organizationAddress = 'O\'zbekiston';
  String? instagramUsername = '@simplesale';
  String? organizationLogoPath;
  
  List<Register> registers = [];
  Register? currentRegister;
  
  bool isBarcodeScanMode = false;
  bool showProductImages = true;
  String appVersion = AppConstants.appVersion;
  String? deviceId;

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Device Identification
      deviceId = prefs.getString('deviceId');
      if (deviceId == null) {
        deviceId = const Uuid().v4();
        await prefs.setString('deviceId', deviceId!);
      }

      // 2. Load basic prefs
      final savedTheme = prefs.getString('themeMode');
      _themeMode = savedTheme == 'light' ? ThemeMode.light : (savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.system);
      
      isBarcodeScanMode = prefs.getBool('isBarcodeScanMode') ?? false;
      showProductImages = prefs.getBool('showProductImages') ?? true;
      receiptWidth = prefs.getInt('receiptWidth') ?? 80;

      // 3. Load from Database (Source of Truth for persistence)
      final dbSettings = await DatabaseService.getAllSettings();
      
      organizationName = dbSettings['organizationName'] ?? prefs.getString('organizationName') ?? 'Mening Do\'konim';
      organizationAddress = dbSettings['organizationAddress'] ?? prefs.getString('organizationAddress') ?? 'O\'zbekiston';
      instagramUsername = dbSettings['instagramUsername'] ?? prefs.getString('instagramUsername') ?? '@simplesale';
      organizationLogoPath = dbSettings['organizationLogoPath'] ?? prefs.getString('organizationLogoPath');
      
      selectedPrinterName = dbSettings['selectedPrinterName'] ?? prefs.getString('selectedPrinterName');
      barcodePrinterName = dbSettings['barcodePrinterName'] ?? prefs.getString('barcodePrinterName');
      networkPrinterIp = dbSettings['networkPrinterIp'] ?? prefs.getString('networkPrinterIp');
      networkBarcodePrinterIp = dbSettings['networkBarcodePrinterIp'] ?? prefs.getString('networkBarcodePrinterIp');
      
      receiptFooterText = dbSettings['receiptFooterText'] ?? prefs.getString('receiptFooterText') ?? 'Xaridingiz uchun rahmat!';
      showLogoOnReceipt = (dbSettings['showLogoOnReceipt'] ?? prefs.getBool('showLogoOnReceipt')?.toString() ?? 'true') == 'true';
      showInstagramOnReceipt = (dbSettings['showInstagramOnReceipt'] ?? prefs.getBool('showInstagramOnReceipt')?.toString() ?? 'true') == 'true';

      // 4. Load Registers and selection
      registers = await DatabaseService.getRegisters();
      final savedRegId = prefs.getString('currentRegisterId');
      if (savedRegId != null) {
        final matching = registers.where((r) => r.id == savedRegId).toList();
        // Only auto-select if this device is the one associated (or if we want to allow re-claiming)
        if (matching.isNotEmpty && matching.first.activeDeviceId == deviceId) {
          currentRegister = matching.first;
        }
      }

      // 5. Load App Version from pubspec.yaml
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = packageInfo.version;
      } catch (e) {
        debugPrint('Error loading package info: $e');
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

  Future<void> toggleShowProductImages() async {
    showProductImages = !showProductImages;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showProductImages', showProductImages);
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

  Future<void> updateOrganizationLogo(String? path) async {
    organizationLogoPath = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString('organizationLogoPath', path);
      await DatabaseService.saveSetting('organizationLogoPath', path);
    } else {
      await prefs.remove('organizationLogoPath');
      await DatabaseService.deleteSetting('organizationLogoPath');
    }
    notifyListeners();
  }

  Future<void> updateReceiptSettings({String? footer, bool? showLogo, bool? showInstagram, int? width}) async {
    final prefs = await SharedPreferences.getInstance();
    if (footer != null) {
      receiptFooterText = footer;
      await DatabaseService.saveSetting('receiptFooterText', footer);
    }
    if (showLogo != null) {
      showLogoOnReceipt = showLogo;
      await DatabaseService.saveSetting('showLogoOnReceipt', showLogo.toString());
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
}
