import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  User? get currentUser => _currentUser;

  bool _isBlocked = false;
  bool get isBlocked => _isBlocked;

  bool _isActivated = false;
  bool get isActivated => _isActivated;

  String? activationCode;
  String? deviceId;

  List<User> _users = [];
  bool isInitialized = false;
  List<User> get activeUsers => _users.where((u) => !u.isDeleted).toList();
  List<User> get deletedUsers => _users.where((u) => u.isDeleted).toList();

  Timer? _monitorTimer;

  Future<void> loadAuth() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Professional: Safe boolean parsing from SharedPreferences
    bool getSafeBool(String key) {
      try {
        return prefs.getBool(key) ?? false;
      } catch (_) {
        try {
          final val = prefs.get(key);
          if (val is int) return val == 1;
          if (val is String) return val.toLowerCase() == 'true';
          return false;
        } catch (__) {
          return false;
        }
      }
    }

    _isActivated = getSafeBool('isActivated');
    _isBlocked = getSafeBool('isBlocked');
    activationCode = prefs.getString('activationCode');
    
    // Use the same deviceId key as AppState for consistency
    deviceId = prefs.getString('deviceId');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('deviceId', deviceId!);
    }
    await reloadUsers();
    
    isInitialized = true;
    notifyListeners();

    // Start background check for organization status and license
    if (_isActivated) {
      startBackgroundMonitoring();
    }
  }

  void startBackgroundMonitoring() {
    _monitorTimer?.cancel();
    // Initial check after 5 seconds to not block startup
    Future.delayed(const Duration(seconds: 5), () => checkBlockingStatus());
    
    // Periodically check every 20 minutes for license and organization updates
    _monitorTimer = Timer.periodic(const Duration(minutes: 20), (timer) {
      checkBlockingStatus();
    });
  }

  @override
  void dispose() {
    _monitorTimer?.cancel();
    super.dispose();
  }

  Future<void> reloadUsers() async {
    _users = await DatabaseService.getUsers(includeDeleted: true);
    
    // If empty, add default users
    if (_users.isEmpty) {
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
      _users = [admin, seller1, seller2];
    }
    notifyListeners();
  }

  Future<void> addUser(User user) async {
    await DatabaseService.saveUser(user);
    await reloadUsers();
  }

  Future<void> deleteUser(String id) async {
    final user = _users.firstWhere((u) => u.id == id);
    final updated = User(
      id: user.id,
      name: user.name,
      pin: user.pin,
      role: user.role,
      isDeleted: true,
    );
    await DatabaseService.saveUser(updated);
    await reloadUsers();
  }

  Future<void> restoreUser(String id) async {
    final user = _users.firstWhere((u) => u.id == id);
    final updated = User(
      id: user.id,
      name: user.name,
      pin: user.pin,
      role: user.role,
      isDeleted: false,
    );
    await DatabaseService.saveUser(updated);
    await reloadUsers();
  }

  Future<void> restoreUsersBatch(List<String> ids) async {
    for (var id in ids) {
      final user = _users.firstWhere((u) => u.id == id);
      final updated = User(
        id: user.id,
        name: user.name,
        pin: user.pin,
        role: user.role,
        isDeleted: false,
      );
      await DatabaseService.saveUser(updated);
    }
    await reloadUsers();
  }

  Future<void> hardDeleteUsersBatch(List<String> ids) async {
    await DatabaseService.hardDeleteUsersBatch(ids);
    await reloadUsers();
  }
  String get activationRequestCode {
    if (deviceId == null) return "Unknown";
    return deviceId!.substring(0, 8).toUpperCase();
  }

  Future<void> activate(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('serverBaseUrl') ?? "https://web-production-d2ed7.up.railway.app";
    final backendUrl = "$baseUrl/verify";
    final cleanCode = code.trim().toUpperCase();
    
    try {
      debugPrint("Attempting online activation for: $deviceId");
      final response = await http
          .post(
            Uri.parse(backendUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "device_id": deviceId,
              "activation_code": cleanCode,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        
        // Save organization details from verification response
        if (data['organization_name'] != null) {
          await prefs.setString('organizationName', data['organization_name']);
          await DatabaseService.saveSetting('organizationName', data['organization_name']);
        }
        if (data['organization_address'] != null) {
          await prefs.setString('organizationAddress', data['organization_address']);
          await DatabaseService.saveSetting('organizationAddress', data['organization_address']);
        }
        if (data['instagram'] != null) {
          await prefs.setString('instagramUsername', data['instagram']);
          await DatabaseService.saveSetting('instagramUsername', data['instagram']);
        }
        
        await setActivated(true, cleanCode);
      } else {
        final errorMsg = response.statusCode == 404 ? "Server topilmadi" : "Kod noto'g'ri";
        throw Exception("$errorMsg (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("Activation connection issue, trying offline fallback: $e");
      
      // Offline fallback
      final secret = deviceId!.substring(0, 8).split('').reversed.join('');
      final expected = "SS-$secret-OK".toUpperCase();
      
      if (cleanCode == expected) {
         await setActivated(true, cleanCode);
      } else {
         if (e is TimeoutException) {
           throw Exception("Serverdan javob kutish vaqti tugadi. Iltimos, internetni tekshiring yoki oflayn kodni kiriting.");
         }
         throw Exception("Aloqa mavjud emas ($e) va oflayn kod noto'g'ri!");
      }
    }
  }

  String cloudStatus = 'Sinxronizatsiya faol';
  bool _isConnecting = false;

  Future<void> performRemoteLogout() async {
    debugPrint("Remote data wipe requested. Clearing...");
    await DatabaseService.clearAllData();
    _isActivated = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (deviceId != null) await prefs.setString('deviceId', deviceId!);
    notifyListeners();
  }

  Future<void> checkBlockingStatus() async {
    if (!_isActivated || activationCode == null || deviceId == null || _isConnecting) return;
    _isConnecting = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString('serverBaseUrl') ?? "https://web-production-d2ed7.up.railway.app";
      final response = await http
          .get(Uri.parse(
              "$baseUrl/check?device_id=$deviceId&code=$activationCode"))
          .timeout(const Duration(seconds: 10));

      _isConnecting = false;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        cloudStatus = 'Bulutga ulandi';

        // 1. Licensing & Blocking
        bool isBlockedOnServer = data['blocked'] == true;
        if (isBlockedOnServer != _isBlocked) {
          await setBlocked(isBlockedOnServer);
        }

        // 2. Sync Professional Organization Details
        final prefs = await SharedPreferences.getInstance();
        bool changed = false;

        if (data['organization_name'] != null && data['organization_name'] != (prefs.getString('organizationName') ?? '')) {
          await prefs.setString('organizationName', data['organization_name']);
          await DatabaseService.saveSetting('organizationName', data['organization_name']);
          changed = true;
        }

        if (data['organization_address'] != null && data['organization_address'] != (prefs.getString('organizationAddress') ?? '')) {
          await prefs.setString('organizationAddress', data['organization_address']);
          await DatabaseService.saveSetting('organizationAddress', data['organization_address']);
          changed = true;
        }

        if (data['instagram'] != null || data['instagram_username'] != null) {
          final ig = data['instagram'] ?? data['instagram_username'];
          await prefs.setString('instagramUsername', ig);
          await DatabaseService.saveSetting('instagramUsername', ig);
          changed = true;
        }

        if (changed) {
          notifyListeners();
        }

        // 3. Remote Data Management (Wipe if requested by master server)
        if (data['force_logout'] == true) {
          await performRemoteLogout();
        }
      } else {
        cloudStatus = 'Serverda xato (${response.statusCode})';
        notifyListeners();
      }
    } catch (e) {
      _isConnecting = false;
      cloudStatus = 'Internet kutilmoqda...';
      notifyListeners();
      debugPrint("Railway check error: $e");
    }
  }

  Future<bool> login(String pin) async {
    final user = activeUsers.cast<User?>().firstWhere((u) => u?.pin == pin, orElse: () => null);
    
    if (user != null) {
      _currentUser = user;
      notifyListeners();
      return true;
    }
    return false;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  Future<void> setActivated(bool value, String code) async {
    _isActivated = value;
    activationCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isActivated', value);
    await prefs.setString('activationCode', code);
    notifyListeners();
  }

  Future<void> setBlocked(bool value) async {
    _isBlocked = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isBlocked', value);
    notifyListeners();
  }
}
