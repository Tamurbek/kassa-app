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
  static Future<List<Product>> getProducts() => ProductRepository.getProducts();
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

  // --- Settings ---
  static Future<Map<String, String>> getSettings() => SettingsRepository.getSettings();
  static Future<void> saveSetting(String key, String value) async {
    await SettingsRepository.saveSetting(key, value);
    triggerUpdate();
  }
  static Future<void> deleteSetting(String key) async {
    final db = await database;
    await db.delete('settings', where: 'key = ?', whereArgs: [key]);
    triggerUpdate();
  }

  // --- Sync & Utils ---
  static Future<void> recalculateStocks({bool force = false}) async {
    await StockUtils.recalculateStocks(force: force);
    triggerUpdate();
  }
  static Future<void> markAsSynced(String table, String id) async {
    await SyncRepository.markAsSynced(table, id);
    triggerUpdate(skipPush: true);
  }
  static Future<Map<String, List<Map<String, dynamic>>>> getUnsyncedRecords() => SyncRepository.getUnsyncedRecords();

  // Bridging some missing methods if any
  static Future<void> saveSyncedRecord(String table, Map<String, dynamic> data) async {
    // This is complex, I'll keep the logic here for now or move to SyncRepository
    final db = await database;
    await db.transaction((txn) async {
      final Map<String, dynamic> mutable = Map.from(data);
      final List<dynamic>? items = mutable.remove('items') as List<dynamic>?;
      mutable['isSynced'] = 1;
      final id = table == 'settings' ? mutable['key'] : mutable['id'];

      await txn.insert(table, mutable, conflictAlgorithm: ConflictAlgorithm.replace);

      if (items != null) {
        String itemTable = '';
        String idCol = '';
        if (table == 'sales') { itemTable = 'sale_items'; idCol = 'saleId'; }
        else if (table == 'returns') { itemTable = 'return_items'; idCol = 'returnId'; }
        else if (table == 'write_offs') { itemTable = 'write_off_items'; idCol = 'writeOffId'; }
        else if (table == 'inventories') { itemTable = 'inventory_items'; idCol = 'inventoryId'; }
        else if (table == 'stock_entries') { itemTable = 'stock_entry_items'; idCol = 'entryId'; }
        else if (table == 'stock_transfers') { itemTable = 'stock_transfer_items'; idCol = 'transferId'; }

        if (itemTable.isNotEmpty) {
          await txn.delete(itemTable, where: '$idCol = ?', whereArgs: [id]);
          for (var item in items) {
            await txn.insert(itemTable, Map<String, dynamic>.from(item));
          }
        }
      }
    });

    if (['sales', 'returns', 'write_offs', 'stock_entries', 'stock_transfers', 'inventories'].contains(table)) {
      await recalculateStocks();
    }
    triggerUpdate(skipPush: true);
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
      await recalculateStocks();
    }
    triggerUpdate(skipPush: true);
  }
}
