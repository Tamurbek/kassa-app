import 'dart:io';
import 'dart:async';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/models.dart';
import 'database/database_helper.dart';
import 'database/product_repository.dart';
import 'database/sale_repository.dart';
import 'database/category_repository.dart';
import 'database/warehouse_repository.dart';
import 'database/user_repository.dart';
import 'database/stock_repository.dart';
import 'database/repository_utils.dart';
import 'database/sync_repository.dart';
import 'database/stock_utils.dart';
import 'database/suspended_sale_repository.dart';
import 'database/organization_repository.dart';

class DatabaseService {
  static Future<Database> get database => DatabaseHelper.database;
  static final StreamController<void> dbUpdateStream = StreamController<void>.broadcast();
  static Function()? onDataChanged;

  static void triggerUpdate({bool skipPush = false}) {
    if (!skipPush) onDataChanged?.call();
    dbUpdateStream.add(null);
  }

  static Future<String> getDatabasePath() => DatabaseHelper.getDatabasePath();
  static Future<void> closeDatabase() => DatabaseHelper.closeDatabase();
  static Future<void> replaceDatabase(File newFile) => DatabaseHelper.replaceDatabase(newFile);

  // --- Product ---
  static Future<List<Product>> getProducts({int? limit, int? offset, String? searchQuery, String? categoryId}) => 
    ProductRepository.getProducts(limit: limit, offset: offset, searchQuery: searchQuery, categoryId: categoryId);
  static Future<void> saveProduct(Product product) async {
    await ProductRepository.saveProduct(product);
    triggerUpdate();
  }
  static Future<void> deleteProduct(String id) async {
    await ProductRepository.deleteProduct(id);
    triggerUpdate();
  }

  // --- Category ---
  static Future<List<Category>> getCategories() => CategoryRepository.getCategories();
  static Future<void> saveCategory(Category category) async {
    await CategoryRepository.saveCategory(category);
    triggerUpdate();
  }
  static Future<void> deleteCategory(String id) async {
    await CategoryRepository.deleteCategory(id);
    triggerUpdate();
  }

  // --- Warehouse ---
  static Future<List<Warehouse>> getWarehouses() => WarehouseRepository.getWarehouses();
  static Future<void> saveWarehouse(Warehouse warehouse) async {
    await WarehouseRepository.saveWarehouse(warehouse);
    triggerUpdate();
  }
  static Future<void> deleteWarehouse(String id) async {
    await WarehouseRepository.deleteWarehouse(id);
    triggerUpdate();
  }
  static Future<List<Warehouse>> getAllWarehouses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('warehouses', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => Warehouse.fromJson(maps[i]));
  }

  // --- Register ---
  static Future<List<Register>> getRegisters() => RegisterRepository.getRegisters();
  static Future<void> saveRegister(Register register) async {
    await RegisterRepository.saveRegister(register);
    triggerUpdate();
  }
  static Future<void> deleteRegister(String id) async {
    await RegisterRepository.deleteRegister(id);
    triggerUpdate();
  }
  static Future<List<Register>> getAllRegisters() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('registers', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => Register.fromJson(maps[i]));
  }

  // --- Sale ---
  static Future<List<Sale>> getSales() => SaleRepository.getSales();
  static Future<void> saveSale(Sale sale) async {
    await SaleRepository.saveSale(sale);
    triggerUpdate();
  }
  static Future<void> deleteSale(String id) async {
    await SaleRepository.deleteSale(id);
    triggerUpdate();
  }

  // --- Suspended Sales ---
  static Future<List<SuspendedSale>> getSuspendedSales() => SuspendedSaleRepository.getSuspendedSales();
  static Future<void> saveSuspendedSale(SuspendedSale sale) async {
    await SuspendedSaleRepository.saveSuspendedSale(sale);
    triggerUpdate();
  }
  static Future<void> deleteSuspendedSale(String id) async {
    await SuspendedSaleRepository.deleteSuspendedSale(id);
    triggerUpdate();
  }

  // --- Stock Entries ---
  static Future<List<StockEntry>> getStockEntries() => StockRepository.getStockEntries();
  static Future<void> saveStockEntry(StockEntry entry) async {
    await StockRepository.saveStockEntry(entry);
    triggerUpdate();
  }
  static Future<void> deleteStockEntry(String id) async {
    await StockRepository.deleteStockEntry(id);
    triggerUpdate();
  }

  // --- Stock Transfer ---
  static Future<List<StockTransfer>> getStockTransfers() => StockRepository.getStockTransfers();
  static Future<void> saveStockTransfer(StockTransfer transfer) async {
    await StockRepository.saveStockTransfer(transfer);
    triggerUpdate();
  }
  static Future<void> deleteStockTransfer(String id) async {
    await StockRepository.deleteStockTransfer(id);
    triggerUpdate();
  }

  // --- Returns, WriteOff, Inventory ---
  static Future<List<SaleReturn>> getReturns() => StockRepository.getReturns();
  static Future<void> saveReturn(SaleReturn saleReturn) async {
    await StockRepository.saveReturn(saleReturn);
    triggerUpdate();
  }
  static Future<void> deleteReturn(String id) async {
    final db = await database;
    await db.update('returns', {'isDeleted': 1, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0}, where: 'id = ?', whereArgs: [id]);
    triggerUpdate();
  }

  static Future<List<WriteOff>> getWriteOffs() => StockRepository.getWriteOffs();
  static Future<void> saveWriteOff(WriteOff writeOff) async {
    await StockRepository.saveWriteOff(writeOff);
    triggerUpdate();
  }
  static Future<void> deleteWriteOff(String id) async {
    final db = await database;
    await db.update('write_offs', {'isDeleted': 1, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0}, where: 'id = ?', whereArgs: [id]);
    triggerUpdate();
  }

  static Future<List<InventoryEntry>> getInventories() => StockRepository.getInventories();
  static Future<void> saveInventory(InventoryEntry inventory) async {
    await StockRepository.saveInventory(inventory);
    triggerUpdate();
  }
  static Future<void> deleteInventory(String id) async {
    final db = await database;
    await db.update('inventories', {'isDeleted': 1, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0}, where: 'id = ?', whereArgs: [id]);
    triggerUpdate();
  }

  // --- User ---
  static Future<List<User>> getUsers() => UserRepository.getUsers();
  static Future<void> saveUser(User user) async {
    await UserRepository.saveUser(user);
    triggerUpdate();
  }
  static Future<void> deleteUser(String id) async {
    await UserRepository.deleteUser(id);
    triggerUpdate();
  }
  static Future<List<User>> getAllUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => User.fromJson(maps[i]));
  }

  // --- Organization ---
  static Future<List<Organization>> getOrganizations() => OrganizationRepository.getOrganizations();
  static Future<void> saveOrganization(Organization org) async {
    await OrganizationRepository.saveOrganization(org);
    triggerUpdate();
  }
  static Future<void> deleteOrganization(String id) async {
    await OrganizationRepository.deleteOrganization(id);
    triggerUpdate();
  }
  static Future<void> restoreOrganization(String id) async {
    await OrganizationRepository.restoreOrganization(id);
    triggerUpdate();
  }
  static Future<void> permanentDeleteOrganization(String id) async {
    await OrganizationRepository.permanentDeleteOrganization(id);
    triggerUpdate();
  }

  // --- Settings ---
  static Future<Map<String, String>> getSettings() => SettingsRepository.getSettings();
  static Future<Map<String, String>> getAllSettings() => SettingsRepository.getSettings(); // Alias for AppState/SettingsProvider
  static Future<void> saveSetting(String key, String value) async {
    await SettingsRepository.saveSetting(key, value);
    triggerUpdate();
  }
  static Future<void> deleteSetting(String key) async {
    final db = await database;
    await db.delete('settings', where: 'key = ?', whereArgs: [key]);
    triggerUpdate();
  }
  static Future<void> updateRegisterDevice(String registerId, String? deviceId) async {
    final db = await database;
    await db.update('registers', {'activeDeviceId': deviceId, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0}, where: 'id = ?', whereArgs: [registerId]);
    triggerUpdate();
  }

  // --- Sync & Utils ---
  static Future<void> recalculateStocks({bool force = false, bool skipNotify = false}) async {
    await StockUtils.recalculateStocks(force: force);
    if (!skipNotify) triggerUpdate();
  }
  static Future<void> updateStock(String productId, String warehouseId, double quantity) async {
    final db = await database;
    await db.insert('stocks', {'productId': productId, 'warehouseId': warehouseId, 'quantity': quantity}, conflictAlgorithm: ConflictAlgorithm.replace);
    triggerUpdate();
  }
  static Future<void> clearAllData() async {
    await DatabaseHelper.clearAllData();
    triggerUpdate();
  }
  static Future<void> clearAllAndReplace({
    required List<Category> categories,
    required List<Product> products,
    required List<Warehouse> warehouses,
    required List<Register> registers,
    required List<User> users,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await clearAllData();
      
      // Professional: Explicitly map booleans to 0/1 for SQLite INTEGER columns
      for (var c in categories) {
        await txn.insert(
          'categories', 
          {...c.toJson(), 'isDeleted': c.isDeleted ? 1 : 0}, 
          conflictAlgorithm: ConflictAlgorithm.replace
        );
      }
      for (var w in warehouses) {
        await txn.insert(
          'warehouses', 
          {...w.toJson(), 'isMain': w.isMain ? 1 : 0, 'isDeleted': 0}, 
          conflictAlgorithm: ConflictAlgorithm.replace
        );
      }
      for (var r in registers) {
        await txn.insert(
          'registers', 
          {...r.toJson(), 'isDeleted': 0}, 
          conflictAlgorithm: ConflictAlgorithm.replace
        );
      }
      for (var u in users) {
        await txn.insert(
          'users', 
          {...u.toJson(), 'isDeleted': u.isDeleted ? 1 : 0}, 
          conflictAlgorithm: ConflictAlgorithm.replace
        );
      }
      
      for (var p in products) {
        await txn.insert(
          'products',
          {...p.toJson(), 'isDeleted': p.isDeleted ? 1 : 0, 'trackStock': p.trackStock ? 1 : 0, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0}..remove('stocks')..remove('additionalBarcodes'),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (var b in p.additionalBarcodes) {
          await txn.insert('product_additional_barcodes', {'productId': p.id, 'barcode': b});
        }
        for (var s in p.stocks.entries) {
          await txn.insert('stocks', {'productId': p.id, 'warehouseId': s.key, 'quantity': s.value}, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
    await recalculateStocks(skipNotify: true);
    triggerUpdate();
  }

  static Future<void> saveCategoriesBatch(List<Category> categories, {bool skipNotify = false, bool skipPush = false}) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (var c in categories) {
        batch.insert(
          'categories',
          {
            ...c.toJson(),
            'isDeleted': c.isDeleted ? 1 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
    if (!skipNotify) triggerUpdate(skipPush: skipPush);
  }

  static Future<void> saveProductsBatch(List<Product> products, {bool skipNotify = false, bool skipPush = false}) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      final now = DateTime.now().toIso8601String();
      for (var p in products) {
        batch.insert(
          'products',
          {
            ...p.toJson(),
            'isDeleted': p.isDeleted ? 1 : 0,
            'trackStock': p.trackStock ? 1 : 0,
            'updatedAt': now,
            'isSynced': 0,
          }..remove('stocks')..remove('additionalBarcodes'),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        
        batch.delete('product_additional_barcodes', where: 'productId = ?', whereArgs: [p.id]);
        for (var b in p.additionalBarcodes) {
          batch.insert('product_additional_barcodes', {'productId': p.id, 'barcode': b});
        }
        for (var s in p.stocks.entries) {
          batch.insert(
            'stocks',
            {'productId': p.id, 'warehouseId': s.key, 'quantity': s.value},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      await batch.commit(noResult: true);
    });
    if (!skipNotify) triggerUpdate(skipPush: skipPush);
  }

  static Future<void> markAsSynced(String table, String id) async {
    await SyncRepository.markAsSynced(table, id);
    triggerUpdate(skipPush: true);
  }

  static Future<void> markAsSyncedBatch(Map<String, List<String>> tableToIds) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var entry in tableToIds.entries) {
        final table = entry.key;
        for (var id in entry.value) {
          await txn.update(
            table,
            {'isSynced': 1},
            where: table == 'settings' ? 'key = ?' : 'id = ?',
            whereArgs: [id],
          );
        }
      }
    });
    triggerUpdate(skipPush: true);
  }

  static Future<Map<String, List<Map<String, dynamic>>>> getUnsyncedRecords() => SyncRepository.getUnsyncedRecords();

  static Future<void> saveSyncedRecordsBatch(List<dynamic> events) async {
    if (events.isEmpty) return;
    
    final db = await database;
    bool needsRecalculate = false;

    await db.transaction((txn) async {
      for (var event in events) {
        final tableName = event['table_name'] as String;
        final data = event['data'] as Map<String, dynamic>;
        
        final Map<String, dynamic> mutable = Map.from(data);
        final List<dynamic>? items = mutable.remove('items') as List<dynamic>?;
        mutable['isSynced'] = 1;
        final id = tableName == 'settings' ? mutable['key'] : mutable['id'];

        await txn.insert(tableName, mutable, conflictAlgorithm: ConflictAlgorithm.replace);

        if (items != null) {
          String itemTable = '';
          String idCol = '';
          if (tableName == 'sales') { itemTable = 'sale_items'; idCol = 'saleId'; }
          else if (tableName == 'returns') { itemTable = 'return_items'; idCol = 'returnId'; }
          else if (tableName == 'write_offs') { itemTable = 'write_off_items'; idCol = 'writeOffId'; }
          else if (tableName == 'inventories') { itemTable = 'inventory_items'; idCol = 'inventoryId'; }
          else if (tableName == 'stock_entries') { itemTable = 'stock_entry_items'; idCol = 'entryId'; }
          else if (tableName == 'stock_transfers') { itemTable = 'stock_transfer_items'; idCol = 'transferId'; }

          if (itemTable.isNotEmpty) {
            await txn.delete(itemTable, where: '$idCol = ?', whereArgs: [id]);
            for (var item in items) {
              await txn.insert(itemTable, Map<String, dynamic>.from(item));
            }
          }
        }

        if (['sales', 'returns', 'write_offs', 'stock_entries', 'stock_transfers', 'inventories'].contains(tableName)) {
          needsRecalculate = true;
        }
      }
    });

    if (needsRecalculate) {
      await recalculateStocks(skipNotify: true);
    }
    triggerUpdate(skipPush: true);
  }

  static Future<void> saveSyncedRecord(String table, Map<String, dynamic> data) async {
    await saveSyncedRecordsBatch([{'table_name': table, 'data': data}]);
  }

  static Future<void> deleteSyncedRecord(String table, String id) async {
    final db = await database;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
    
    if (table == 'sales') await db.delete('sale_items', where: 'saleId = ?', whereArgs: [id]);
    if (table == 'returns') await db.delete('return_items', where: 'returnId = ?', whereArgs: [id]);
    if (table == 'write_offs') await db.delete('write_off_items', where: 'writeOffId = ?', whereArgs: [id]);
    if (table == 'inventories') await db.delete('inventory_items', where: 'inventoryId = ?', whereArgs: [id]);
    if (table == 'stock_entries') await db.delete('stock_entry_items', where: 'entryId = ?', whereArgs: [id]);
    if (table == 'stock_transfers') await db.delete('stock_transfer_items', where: 'transferId = ?', whereArgs: [id]);

    if (['sales', 'returns', 'write_offs', 'stock_entries', 'stock_transfers', 'inventories'].contains(table)) {
      await recalculateStocks(skipNotify: true);
    }
    triggerUpdate(skipPush: true);
  }
  static Future<Sale?> getSaleById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sales', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    
    final itemsMap = await db.query('sale_items', where: 'saleId = ?', whereArgs: [id]);
    final saleMap = Map<String, dynamic>.from(maps.first);
    saleMap['items'] = itemsMap;
    return Sale.fromJson(saleMap);
  }

  static Future<Product?> getProductById(String id) => ProductRepository.getProductById(id);

  static Future<Map<String, double>> getProductStocks(String productId) async {
    final db = await database;
    final List<Map<String, dynamic>> stocks = await db.query('stocks', where: 'productId = ?', whereArgs: [productId]);
    return {for (var s in stocks) s['warehouseId'].toString(): (s['quantity'] as num).toDouble()};
  }
}
