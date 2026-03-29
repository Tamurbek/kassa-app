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
  bool isInitialized = false;
  bool? isMaster;
  bool isCloudMode = false;
  String? masterAddress;
  DateTime? lastCloudSync;
  bool isSyncingCloud = false;
  String syncingStage = '';
  bool _isConnected = false;
  bool get isConnected => isMaster == true ? true : _isConnected;

  WebSocketChannel? _wsChannel;
  bool _isConnectingWs = false;
  Timer? _cloudBackupTimer;

  Future<void> loadSync() async {
    final prefs = await SharedPreferences.getInstance();
    isMaster = prefs.getBool('isMaster');
    isCloudMode = prefs.getBool('isCloudMode') ?? false;
    masterAddress = prefs.getString('masterAddress');
    _incrementalSyncTimer?.cancel();
    _cloudBackupTimer?.cancel();
    _wsChannel?.sink.close();
    _cloudSyncChannel?.sink.close();
    _isConnected = false;
    _isConnectingWs = false;

    final lastSyncStr = prefs.getString('lastCloudSync');
    if (lastSyncStr != null) lastCloudSync = DateTime.parse(lastSyncStr);
    
    DatabaseService.onDataChanged = () => syncNow();

    final activationCode = prefs.getString('activationCode')?.trim().toUpperCase();
    if (isCloudMode && activationCode != null) {
      _connectCloudSync(activationCode);
    }

    if (isMaster == false && masterAddress != null) {
      _connectRealtime();
    }
    
    // Professional auto-sync: Start background backup/sync
    if (isMaster == true) {
      startAutoCloudBackup();
      startAutoIncrementalSync();
    } else if (isMaster == false && masterAddress != null) {
      startAutoIncrementalSync(); // Slaves also push their data incrementally
    }
    notifyListeners();
  }

  Timer? _incrementalSyncTimer;
  void startAutoIncrementalSync() {
    _incrementalSyncTimer?.cancel();
    // Professional sync interval: Every 30 seconds check for new data to push AND pull
    _incrementalSyncTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
       await syncIncremental();
       if (isCloudMode) {
         await pullFromCloudIncremental();
       } else if (isMaster == false && masterAddress != null) {
         // LAN Fallback: Periodically fetch status or sync data if WS is down
         try {
           await syncWithMaster(); // Keep Slave in sync even if WS is unstable
         } catch (_) {}
       }
    });
  }

  void startAutoCloudBackup() {
    _cloudBackupTimer?.cancel();
    // Background cloud sync every 2 hours if active
    _cloudBackupTimer = Timer.periodic(const Duration(hours: 2), (timer) async {
       if (isMaster == true) {
         try {
           await uploadDatabaseToCloud();
         } catch (e) {
           debugPrint('Auto cloud backup error: $e');
         }
       }
    });
  }

  @override
  void dispose() {
    _cloudBackupTimer?.cancel();
    _incrementalSyncTimer?.cancel();
    _wsChannel?.sink.close();
    super.dispose();
  }

  Future<void> syncIncremental() async {
    // Get all records that haven't been synced yet
    final unsynced = await DatabaseService.getUnsyncedRecords();
    if (unsynced.isEmpty) return;

    debugPrint("Professional Sync: Found ${unsynced.length} tables with unsynced data");

    if (isCloudMode) {
      // In Cloud Mode, we push to the central server
      await _pushToCloudIncremental(unsynced);
    }

    // Simultaneously, maintain Local Network (LAN) synchronization
    if (isMaster == true) {
      // MASTER (LAN Mode): Broadcast unsynced local changes to connected terminals
      for (var entry in unsynced.entries) {
        final table = entry.key;
        final type = _getSingularType(table);
        for (var record in entry.value) {
          debugPrint("Professional Sync: Master broadcasting $type to LAN");
          SyncService.broadcast(type, record);
          // After broadcasting/cloud-syncing, we mark it as synced locally
          await DatabaseService.markAsSynced(table, record['id']);
        }
      }
    } else if (isMaster == false && masterAddress != null) {
      // SLAVE (LAN Mode): Push to Master via Local Network for real-time local updates
      await _pushToMasterIncremental(unsynced);
    }
  }

  String _getSingularType(String table) {
    if (table == 'write_offs') return 'write_off';
    if (table == 'inventories') return 'inventory';
    if (table == 'stock_entries') return 'stock_entry';
    if (table == 'stock_transfers') return 'stock_transfer';
    if (table == 'categories') return 'category';
    if (table == 'products') return 'product';
    if (table == 'warehouses') return 'warehouse';
    if (table == 'registers') return 'register';
    if (table == 'sales') return 'sale';
    if (table == 'returns') return 'return';
    if (table == 'users') return 'user';
    return table;
  }

  bool _isSyncingInternally = false;

  Future<void> syncNow() async {
    if (_isSyncingInternally) return;
    
    _isSyncingInternally = true;
    try {
      debugPrint("Professional Sync: Triggering immediate sync (Cloud: $isCloudMode)...");
      await syncIncremental();
      if (isCloudMode) {
        await pullFromCloudIncremental();
      }
    } finally {
      _isSyncingInternally = false;
    }
  }

  Future<void> pullFromCloudIncremental() async {
    final prefs = await SharedPreferences.getInstance();
    final activationCode = prefs.getString('activationCode')?.trim().toUpperCase();
    if (activationCode == null) return;

    final lastId = prefs.getInt('lastSyncId') ?? 0;
    final url = "https://web-production-d2ed7.up.railway.app/sync-incremental?activation_code=$activationCode&last_id=$lastId";

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List events = jsonDecode(response.body);
        if (events.isEmpty) return;

        int maxId = lastId;
        for (var event in events) {
          final id = event['id'] as int;
          final tableName = event['table_name'] as String;
          final data = event['data'] as Map<String, dynamic>;

          await DatabaseService.saveSyncedRecord(tableName, data);
          if (id > maxId) maxId = id;
        }

        await prefs.setInt('lastSyncId', maxId);
        lastCloudSync = DateTime.now();
        await prefs.setString('lastCloudSync', lastCloudSync!.toIso8601String());
        
        notifyListeners();
        debugPrint("Professional Sync: Pulled ${events.length} records. Latest ID: $maxId");
      }
    } catch (e) {
      debugPrint("Professional Sync: Pull error: $e");
    }
  }

  Future<void> _pushToCloudIncremental(Map<String, List<Map<String, dynamic>>> data) async {
    final prefs = await SharedPreferences.getInstance();
    final activationCode = prefs.getString('activationCode')?.trim().toUpperCase();
    if (activationCode == null) return;

    try {
      // Professional Incremental Endpoint
      final syncUrl = "https://web-production-d2ed7.up.railway.app/sync-incremental?activation_code=$activationCode";
      final response = await http.post(
        Uri.parse(syncUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        // Success! Mark everything as synced
        for (var entry in data.entries) {
          final table = entry.key;
          for (var record in entry.value) {
            await DatabaseService.markAsSynced(table, record['id']);
          }
        }
        debugPrint("Professional Sync: Cloud incremental sync successful");
      }
    } catch (e) {
      debugPrint("Professional Sync: Cloud incremental sync failed: $e");
    }
  }

  Future<void> _pushToMasterIncremental(Map<String, List<Map<String, dynamic>>> data) async {
    if (masterAddress == null) return;
    
    try {
      final syncUrl = "http://$masterAddress:8080/sync-batch";
      final response = await http.post(
        Uri.parse(syncUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        for (var entry in data.entries) {
          final table = entry.key;
          for (var record in entry.value) {
            await DatabaseService.markAsSynced(table, record['id']);
          }
        }
        debugPrint("Professional Sync: Master incremental sync successful");
      }
    } catch (e) {
      debugPrint("Professional Sync: Master incremental sync failed: $e");
    }
  }

  VoidCallback? onRemoteLogout;
  WebSocketChannel? _cloudSyncChannel;

  void _connectCloudSync(String activationCode) {
    _cloudSyncChannel?.sink.close();
    
    final wsUrl = "wss://web-production-d2ed7.up.railway.app/ws/sync/$activationCode";
    debugPrint("Professional Sync: Connecting to cloud websocket: $wsUrl");
    
    try {
      _cloudSyncChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _cloudSyncChannel!.stream.listen(
        (message) {
          debugPrint("Professional Sync: Received cloud notification: $message");
          if (message == "sync_needed") {
            pullFromCloudIncremental();
          } else if (message == "ping") {
            _cloudSyncChannel?.sink.add("pong");
          } else if (message == "force_logout") {
            debugPrint("Professional Sync: Force logout command received via WebSocket!");
            onRemoteLogout?.call();
          }
        },
        onDone: () {
          debugPrint("Professional Sync: Cloud websocket closed. Reconnecting...");
          Future.delayed(const Duration(seconds: 10), () {
            if (isCloudMode) _connectCloudSync(activationCode);
          });
        },
        onError: (e) {
          debugPrint("Professional Sync: Cloud websocket error: $e");
          Future.delayed(const Duration(seconds: 15), () {
            if (isCloudMode) _connectCloudSync(activationCode);
          });
        },
      );
    } catch (e) {
      debugPrint("Professional Sync: Could not establish cloud websocket: $e");
    }
  }

  void _connectRealtime() {
    if (_isConnectingWs || (isMaster != false) || masterAddress == null) return;
    _isConnectingWs = true;

    try {
      final wsUrl = 'ws://$masterAddress:8080/ws';
      debugPrint("Professional Sync: Connecting to LAN websocket: $wsUrl");
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _wsChannel!.stream.listen(
        (message) async {
          if (!_isConnected) {
            _isConnected = true;
            notifyListeners();
          }
          
          try {
            final data = jsonDecode(message);
            final type = data['type'];
            
            if (type == 'heartbeat' || type == 'pong') {
               notifyListeners();
               return;
            }

            debugPrint("Professional Sync: Received real-time update: $type");
            
            // Handle specific entity updates
            const entities = [
              'category', 'product', 'warehouse', 'register', 
              'sale', 'return', 'write_off', 'inventory', 
              'stock_entry', 'user', 'stock_transfer'
            ];
            
            if (entities.contains(type)) {
              String table = type;
              if (type == 'category') table = 'categories';
              if (type == 'product') table = 'products';
              if (type == 'warehouse') table = 'warehouses';
              if (type == 'register') table = 'registers';
              if (type == 'user') table = 'users';
              if (type == 'stock_entry') table = 'stock_entries';
              if (type == 'sale') table = 'sales';
              if (type == 'return') table = 'returns';
              if (type == 'write_off') table = 'write_offs';
              if (type == 'inventory') table = 'inventories';
              if (type == 'stock_transfer') table = 'stock_transfers';
              
              await DatabaseService.saveSyncedRecord(table, data['data']);
              debugPrint("Professional Sync: $type record saved and UI notified");
            } else if (type == 'setting') {
              await DatabaseService.saveSetting(data['data']['key'], data['data']['value'].toString());
            } else if (type.toString().endsWith('_delete')) {
               final entityType = type.toString().split('_').first;
               String table = entityType;
               if (entityType == 'category') table = 'categories';
               if (entityType == 'product') table = 'products';
               // ... (add other table mappings if needed)
               await DatabaseService.deleteSyncedRecord(table, data['data']['id']);
            }
            
            notifyListeners();
          } catch (e) {
            debugPrint("Professional Sync: Error parsing WS message: $e");
          }
        },
        onError: (e) {
          debugPrint("Professional Sync: LAN websocket error: $e");
          _isConnected = false;
          _isConnectingWs = false;
          _reconnectRealtime();
        },
        onDone: () {
          debugPrint("Professional Sync: LAN websocket closed.");
          _isConnected = false;
          _isConnectingWs = false;
          _reconnectRealtime();
        },
      );
    } catch (e) {
      debugPrint("Professional Sync: Could not connect to LAN websocket: $e");
      _isConnected = false;
      _isConnectingWs = false;
      _reconnectRealtime();
    }
  }

  void _reconnectRealtime() {
    Future.delayed(const Duration(seconds: 5), () {
      if (isMaster == false && masterAddress != null) {
        _connectRealtime();
      }
    });
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
    final rawCode = prefs.getString('activationCode');
    final isActivated = prefs.getBool('isActivated') ?? false;

    if (!isActivated || rawCode == null) {
      throw Exception('Dastur faollashtirilmagan');
    }
    
    final activationCode = rawCode.trim().toUpperCase();

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
  Future<void> restoreDatabaseFromCloud({String? activationCodeOverride}) async {
    final prefs = await SharedPreferences.getInstance();
    
    String? activationCode;
    if (activationCodeOverride != null) {
      activationCode = activationCodeOverride.trim().toUpperCase();
    } else {
      final rawCode = prefs.getString('activationCode');
      final isActivated = prefs.getBool('isActivated') ?? false;
      if (!isActivated || rawCode == null) {
        throw Exception('Dastur faollashtirilmagan');
      }
      activationCode = rawCode.trim().toUpperCase();
    }

    isSyncingCloud = true;
    syncingStage = 'Bulutdan yuklab olinmoqda...';
    notifyListeners();

    final downloadUrl = "https://web-production-d2ed7.up.railway.app/backup/$activationCode";
    debugPrint("Restoring from cloud URL: $downloadUrl");

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
        throw Exception('Ushbu kod ($activationCode) uchun bulutli serverdan zaxira topilmadi. Avval "Bulutga saqlash" tugmasini bosganingizga ishonch hosil qiling.');
      } else {
        throw Exception('Bulutdan zaxirani yuklab bo\'mladi (Server xatosi: ${response.statusCode})');
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

  /// Combined Push & Pull Sync
  Future<void> performFullSync(BuildContext context) async {
    isSyncingCloud = true;
    syncingStage = 'Sinxronizatsiya qilinmoqda...';
    notifyListeners();

    try {
      // 1. First push local changes (Incremental)
      syncingStage = 'O\'zgarishlar yuborilmoqda...';
      notifyListeners();
      await syncIncremental();

      // 2. Pull changes from cloud (Incremental)
      syncingStage = 'Serverdan ma\'lumotlar olinmoqda...';
      notifyListeners();
      await pullFromCloudIncremental();

      // 3. Backup full database (for safety/history)
      if (isMaster == true) {
        syncingStage = 'To\'liq zaxira saqlanmoqda...';
        notifyListeners();
        await uploadDatabaseToCloud();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Sinxronizatsiya muvaffaqiyatli yakunlandi!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      isSyncingCloud = false;
      syncingStage = '';
      notifyListeners();
    }
  }

  /// Export database to a local file
  Future<void> exportDatabaseToFile() async {
    try {
      final dbPath = await DatabaseService.getDatabasePath();
      final file = File(dbPath);
      if (!await file.exists()) throw Exception('Baza fayli topilmadi');

      final fileName = "SimpleSale_Backup_${DateTime.now().toString().substring(0, 10)}.db";

      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Zaxira faylini saqlash joyini tanlang',
          fileName: fileName,
          lockParentWindow: true,
          type: FileType.any,
        );

        if (outputFile != null) {
          await file.copy(outputFile);
        }
      } else {
        // Mobile sharing
        await Share.shareXFiles([XFile(dbPath)], text: 'SimpleSale Ma\'lumotlar Bazasi Zaxirasi');
      }
    } catch (e) {
      throw Exception('Faylga saqlashda xatolik: $e');
    }
  }

  /// Import database from a local file
  Future<void> importDatabaseFromFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final pickedFile = File(result.files.single.path!);
        await DatabaseService.replaceDatabase(pickedFile);
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Fayldan tiklashda xatolik: $e');
    }
  }
}
