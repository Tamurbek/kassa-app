import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../models/models.dart';
import 'database_helper.dart';

class StockRepository {
  // --- Stock Entries ---
  static Future<List<StockEntry>> getStockEntries() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('stock_entries', where: 'isDeleted = 0', orderBy: 'date DESC');
    List<StockEntry> entries = [];
    for (var m in maps) {
      final itemsMap = await db.query('stock_entry_items', where: 'entryId = ?', whereArgs: [m['id']]);
      final entryMap = Map<String, dynamic>.from(m);
      entryMap['items'] = itemsMap;
      entries.add(StockEntry.fromJson(entryMap));
    }
    return entries;
  }

  static Future<void> saveStockEntry(StockEntry entry) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      // Check if this is an edit or a new entry
      final existing = await txn.query('stock_entries', where: 'id = ?', whereArgs: [entry.id]);
      final bool isNew = existing.isEmpty;

      await txn.insert(
        'stock_entries',
        {...entry.toJson(), 'isDeleted': 0, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0}..remove('items'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('stock_entry_items', where: 'entryId = ?', whereArgs: [entry.id]);
      
      for (var item in entry.items) {
        await txn.insert('stock_entry_items', {...item.toJson(), 'entryId': entry.id});
        
        // ONLY update the current product price/cost if this is a NEW entry.
        // This prevents old, historical entries from "overwriting" current product prices during edits.
        if (isNew && (item.costPrice > 0 || item.price > 0)) {
          final Map<String, dynamic> updates = {};
          if (item.costPrice > 0) updates['costPrice'] = item.costPrice;
          if (item.price > 0) updates['price'] = item.price;
          updates['updatedAt'] = DateTime.now().toIso8601String();
          updates['isSynced'] = 0;
          await txn.update('products', updates, where: 'id = ?', whereArgs: [item.productId]);
        }
      }
      // Note: we removed manual 'stocks' table updates here because recalculateStocks 
      // is always called after this and it is the reliable source of truth.
    });
  }

  static Future<void> deleteStockEntry(String id) async {
    final db = await DatabaseHelper.database;
    await db.update('stock_entries', {'isDeleted': 1, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0}, where: 'id = ?', whereArgs: [id]);
  }

  // --- Stock Transfers ---
  static Future<List<StockTransfer>> getStockTransfers() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('stock_transfers', where: 'isDeleted = 0', orderBy: 'date DESC');
    List<StockTransfer> transfers = [];
    for (var m in maps) {
      final itemsMap = await db.query('stock_transfer_items', where: 'transferId = ?', whereArgs: [m['id']]);
      final transMap = Map<String, dynamic>.from(m);
      transMap['items'] = itemsMap;
      transfers.add(StockTransfer.fromJson(transMap));
    }
    return transfers;
  }

  static Future<void> saveStockTransfer(StockTransfer transfer) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      await txn.insert(
        'stock_transfers',
        {...transfer.toJson(), 'isDeleted': 0, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0}..remove('items'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('stock_transfer_items', where: 'transferId = ?', whereArgs: [transfer.id]);
      for (var item in transfer.items) {
        await txn.insert('stock_transfer_items', {...item.toJson(), 'transferId': transfer.id});
      }
    });
  }

  static Future<void> deleteStockTransfer(String id) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      final entryRes = await txn.query('stock_transfers', where: 'id = ?', whereArgs: [id]);
      if (entryRes.isEmpty) return;
      
      final fromW = entryRes.first['fromWarehouseId'].toString();
      final toW = entryRes.first['toWarehouseId'].toString();
      final items = await txn.query('stock_transfer_items', where: 'transferId = ?', whereArgs: [id]);

      for (var item in items) {
        final pId = item['productId'].toString();
        final qty = (item['quantity'] as num).toDouble();
        
        final curFrom = await txn.query('stocks', where: 'productId=? AND warehouseId=?', whereArgs:[pId, fromW]);
        double curFromQty = curFrom.isNotEmpty ? (curFrom.first['quantity'] as num).toDouble() : 0;
        await txn.insert('stocks', {'productId':pId, 'warehouseId':fromW, 'quantity':curFromQty + qty}, conflictAlgorithm: ConflictAlgorithm.replace);

        final curTo = await txn.query('stocks', where: 'productId=? AND warehouseId=?', whereArgs:[pId, toW]);
        double curToQty = curTo.isNotEmpty ? (curTo.first['quantity'] as num).toDouble() : 0;
        await txn.insert('stocks', {'productId':pId, 'warehouseId':toW, 'quantity':curToQty - qty}, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await txn.update('stock_transfers', {
        'isDeleted': 1,
        'isSynced': 0,
        'updatedAt': DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [id]);
    });
  }

  // --- Returns ---
  static Future<List<SaleReturn>> getReturns() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('returns', where: 'isDeleted = 0', orderBy: 'date DESC');
    List<SaleReturn> returns = [];
    for (var m in maps) {
      final itemsMap = await db.query('return_items', where: 'returnId = ?', whereArgs: [m['id']]);
      final retMap = Map<String, dynamic>.from(m);
      retMap['items'] = itemsMap;
      returns.add(SaleReturn.fromJson(retMap));
    }
    return returns;
  }

  static Future<void> saveReturn(SaleReturn saleReturn) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      await txn.insert(
        'returns',
        {...saleReturn.toJson(), 'isDeleted': 0, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0}..remove('items'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('return_items', where: 'returnId = ?', whereArgs: [saleReturn.id]);
      for (var item in saleReturn.items) {
        await txn.insert('return_items', {...item.toJson(), 'returnId': saleReturn.id});
      }
    });
  }

  // --- Write Offs ---
  static Future<List<WriteOff>> getWriteOffs() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('write_offs', where: 'isDeleted = 0', orderBy: 'date DESC');
    List<WriteOff> writeOffs = [];
    for (var m in maps) {
      final itemsMap = await db.query('write_off_items', where: 'writeOffId = ?', whereArgs: [m['id']]);
      final woMap = Map<String, dynamic>.from(m);
      woMap['items'] = itemsMap;
      writeOffs.add(WriteOff.fromJson(woMap));
    }
    return writeOffs;
  }

  static Future<void> saveWriteOff(WriteOff writeOff) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      await txn.insert(
        'write_offs',
        {...writeOff.toJson(), 'isDeleted': 0, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0}..remove('items'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('write_off_items', where: 'writeOffId = ?', whereArgs: [writeOff.id]);
      for (var item in writeOff.items) {
        await txn.insert('write_off_items', {...item.toJson(), 'writeOffId': writeOff.id});
      }
    });
  }

  // --- Inventories ---
  static Future<List<InventoryEntry>> getInventories() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('inventories', where: 'isDeleted = 0', orderBy: 'date DESC');
    List<InventoryEntry> entries = [];
    for (var m in maps) {
      final itemsMap = await db.query('inventory_items', where: 'inventoryId = ?', whereArgs: [m['id']]);
      final invMap = Map<String, dynamic>.from(m);
      invMap['items'] = itemsMap;
      entries.add(InventoryEntry.fromJson(invMap));
    }
    return entries;
  }

  static Future<void> saveInventory(InventoryEntry inventory) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      await txn.insert(
        'inventories',
        {...inventory.toJson(), 'isDeleted': 0, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0}..remove('items'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('inventory_items', where: 'inventoryId = ?', whereArgs: [inventory.id]);
      for (var item in inventory.items) {
        await txn.insert('inventory_items', {...item.toJson(), 'inventoryId': inventory.id});
      }
    });
  }
}
