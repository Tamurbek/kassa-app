import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/database_service.dart';
import '../../models/models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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
  
  String? organizationName = 'test';
  String? organizationAddress = 'O\'zbekiston, Toshkent';
  String? instagramUsername = '@simplesale';
  String? organizationLogoPath;
  
  List<Register> registers = [];
  Register? currentRegister;
  
  bool isBarcodeScanMode = false;
  bool showProductImages = true;
  String appVersion = '1.16.0';

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final savedTheme = prefs.getString('themeMode');
      if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      } else if (savedTheme == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }

      isBarcodeScanMode = prefs.getBool('isBarcodeScanMode') ?? false;
      showProductImages = prefs.getBool('showProductImages') ?? true;
      networkPrinterIp = prefs.getString('networkPrinterIp');
      networkBarcodePrinterIp = prefs.getString('networkBarcodePrinterIp');
      selectedPrinterName = prefs.getString('selectedPrinterName');
      barcodePrinterName = prefs.getString('barcodePrinterName');
      receiptWidth = prefs.getInt('receiptWidth') ?? 80;
      receiptFooterText = prefs.getString('receiptFooterText') ?? 'Xaridingiz uchun rahmat!';
      showLogoOnReceipt = prefs.getBool('showLogoOnReceipt') ?? true;
      showInstagramOnReceipt = prefs.getBool('showInstagramOnReceipt') ?? true;
      organizationName = prefs.getString('organizationName') ?? 'test';
      organizationAddress = prefs.getString('organizationAddress') ?? 'O\'zbekiston, Toshkent';
      instagramUsername = prefs.getString('instagramUsername') ?? '@simplesale';
      organizationLogoPath = prefs.getString('organizationLogoPath');

      // Load settings from DB (overrides SharedPreferences if exists)
      final dbSettings = await DatabaseService.getAllSettings();
      if (dbSettings.containsKey('receiptFooterText')) receiptFooterText = dbSettings['receiptFooterText']!;
      if (dbSettings.containsKey('showLogoOnReceipt')) showLogoOnReceipt = dbSettings['showLogoOnReceipt'] == 'true';
      if (dbSettings.containsKey('showInstagramOnReceipt')) showInstagramOnReceipt = dbSettings['showInstagramOnReceipt'] == 'true';
      if (dbSettings.containsKey('organizationName')) organizationName = dbSettings['organizationName']!;
      if (dbSettings.containsKey('organizationAddress')) organizationAddress = dbSettings['organizationAddress']!;
      if (dbSettings.containsKey('instagramUsername')) instagramUsername = dbSettings['instagramUsername']!;
      if (dbSettings.containsKey('barcodePrinterName')) barcodePrinterName = dbSettings['barcodePrinterName']!;

      registers = await DatabaseService.getRegisters();
      final savedRegId = prefs.getString('currentRegisterId');
      final deviceId = prefs.getString('deviceId');
      if (savedRegId != null) {
        final matching = registers.where((r) => r.id == savedRegId).toList();
        if (matching.isNotEmpty && matching.first.activeDeviceId == deviceId) {
          currentRegister = matching.first;
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
    }
    notifyListeners();
  }

  Future<void> updateOrganizationInfo({
    String? name,
    String? address,
    String? instagram,
  }) async {
    if (name != null) organizationName = name;
    if (address != null) organizationAddress = address;
    if (instagram != null) instagramUsername = instagram;

    final prefs = await SharedPreferences.getInstance();
    if (name != null) {
      await prefs.setString('organizationName', name);
      await DatabaseService.saveSetting('organizationName', name);
    }
    if (address != null) {
      await prefs.setString('organizationAddress', address);
      await DatabaseService.saveSetting('organizationAddress', address);
    }
    if (instagram != null) {
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

  Future<void> saveOrgInfo({
    required String name,
    required String address,
    required String instagram,
    String? logoPath,
  }) async {
    await updateOrganizationInfo(name: name, address: address, instagram: instagram);
    if (logoPath != null) await updateOrganizationLogo(logoPath);
  }

  Future<void> updateReceiptSettings({
     String? footer,
     bool? showLogo,
     bool? showInstagram,
     int? width,
  }) async {
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('receiptWidth', width);
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

  Future<void> exportDatabase() async {
    // Current DB path
    final dbPath = await DatabaseService.getDatabasePath();
    final file = File(dbPath);
    if (!await file.exists()) throw Exception('Baza topilmadi');

    // This would typically involve using share_plus or file_picker to save
    // For now, we'll use a placeholder logic or keep it simple
    // state.exportDatabase used share_plus.
  }

  Future<void> importDatabase() async {
    // This would typically involve file_picker
    // state.importDatabase used file_picker.
  }

  Future<void> clearAllData() async {
    await DatabaseService.clearAllData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
    // After clear, would need to reload or restart app
  }
}
