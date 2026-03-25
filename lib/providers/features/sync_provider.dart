import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';

class SyncProvider extends ChangeNotifier {
  bool? isMaster;
  String? masterAddress;
  DateTime? lastCloudSync;
  bool isSyncingCloud = false;
  String syncingStage = '';
  bool _isConnected = false;
  bool get isConnected => isMaster == true ? true : _isConnected;

  WebSocketChannel? _wsChannel;
  bool _isConnectingWs = false;

  Future<void> loadSync() async {
    final prefs = await SharedPreferences.getInstance();
    isMaster = prefs.getBool('isMaster');
    masterAddress = prefs.getString('masterAddress');
    final lastSyncStr = prefs.getString('lastCloudSync');
    if (lastSyncStr != null) lastCloudSync = DateTime.parse(lastSyncStr);

    if (isMaster == false && masterAddress != null) {
      _connectRealtime();
    }
    notifyListeners();
  }

  void _connectRealtime() {
    if (_isConnectingWs || (isMaster != false) || masterAddress == null) return;
    _isConnectingWs = true;

    try {
      final wsUrl = 'ws://$masterAddress:8080/ws';
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _wsChannel!.stream.listen(
        (message) {
          _isConnected = true;
          final data = jsonDecode(message);
          if (data['type'] == 'update') {
            notifyListeners();
          }
        },
        onError: (e) {
          _isConnected = false;
          _isConnectingWs = false;
          Future.delayed(const Duration(seconds: 5), _connectRealtime);
        },
        onDone: () {
          _isConnected = false;
          _isConnectingWs = false;
          Future.delayed(const Duration(seconds: 5), _connectRealtime);
        },
      );
    } catch (e) {
      _isConnected = false;
      _isConnectingWs = false;
    }
  }

  Future<void> syncWithMaster() async {
    if (isMaster != false || masterAddress == null) return;

    final data = await SyncService.fetchFullState(masterAddress!);
    if (data != null) {
      final newCategories = (data['categories'] as List).map((c) => Category.fromJson(c)).toList();
      final newProducts = (data['products'] as List).map((p) => Product.fromJson(p)).toList();
      final newWarehouses = (data['warehouses'] as List).map((w) => Warehouse.fromJson(w)).toList();
      final newRegisters = (data['registers'] as List).map((r) => Register.fromJson(r)).toList();
      final newUsers = data['users'] != null
          ? (data['users'] as List).map((u) => User.fromJson(u)).toList()
          : <User>[];

      await DatabaseService.clearAllAndReplace(
        categories: newCategories,
        products: newProducts,
        warehouses: newWarehouses,
        registers: newRegisters,
        users: newUsers,
      );

      if (data['settings'] != null) {
        final Map<String, dynamic> remoteSettings = data['settings'];
        for (var entry in remoteSettings.entries) {
          await DatabaseService.saveSetting(entry.key, entry.value.toString());
        }
      }

      notifyListeners();
    } else {
      throw Exception('Asosiy kompyuterga ulanib bo\'lmadi.');
    }
  }

  /// Professional HTTP-based cloud synchronization (Backup)
  Future<void> uploadDatabaseToCloud() async {
    final prefs = await SharedPreferences.getInstance();
    final activationCode = prefs.getString('activationCode');
    final isActivated = prefs.getBool('isActivated') ?? false;

    if (!isActivated || activationCode == null) {
      throw Exception('Dastur faollashtirilmagan');
    }

    isSyncingCloud = true;
    syncingStage = 'Terminalardan ma\'lumotlarni jamlash...';
    notifyListeners();

    try {
      final dbPath = await DatabaseService.getDatabasePath();
      final file = File(dbPath);
      if (!await file.exists()) throw Exception('Baza fayli topilmadi');

      // Professional consolidation: Ensure all terminals have pushed their data
      if (isMaster == true) {
        debugPrint("Consolidating data from terminals before cloud sync...");
        SyncService.broadcast('force_sync_push', {'request': 'backup'});
        // Wait a bit for any slow terminals to finish their last HTTP POSTs
        await Future.delayed(const Duration(seconds: 2));
      }

      syncingStage = 'Bulutli serverga saqlash...';
      notifyListeners();

      const uploadUrl = "https://web-production-d2ed7.up.railway.app/backup";

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$uploadUrl?activation_code=$activationCode'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', dbPath));

      var response = await request.send().timeout(const Duration(seconds: 40));
      if (response.statusCode == 200) {
        lastCloudSync = DateTime.now();
        await prefs.setString('lastCloudSync', lastCloudSync!.toIso8601String());
        notifyListeners();
      } else {
        throw Exception('Zaxira yuklashda xatolik: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Serverga ulanib bo\'lmadi: $e');
    } finally {
      isSyncingCloud = false;
      syncingStage = '';
      notifyListeners();
    }
  }

  /// Professional HTTP-based cloud synchronization (Restore)
  Future<void> restoreDatabaseFromCloud() async {
    final prefs = await SharedPreferences.getInstance();
    final activationCode = prefs.getString('activationCode');
    final isActivated = prefs.getBool('isActivated') ?? false;

    if (!isActivated || activationCode == null) {
      throw Exception('Dastur faollashtirilmagan');
    }

    isSyncingCloud = true;
    syncingStage = 'Bulutdan yuklab olinmoqda...';
    notifyListeners();

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
        
        lastCloudSync = DateTime.now();
        await prefs.setString('lastCloudSync', lastCloudSync!.toIso8601String());
        
        notifyListeners();
        debugPrint("Cloud restore successful");
      } else if (response.statusCode == 404) {
        throw Exception('Ushbu kod uchun bulutli zaxira topilmadi');
      } else {
        throw Exception('Bulutdan zaxirani yuklab bo\'lmadi (Server xatosi: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint("Restore error detail: $e");
      rethrow;
    } finally {
      isSyncingCloud = false;
      syncingStage = '';
      notifyListeners();
    }
  }
}
