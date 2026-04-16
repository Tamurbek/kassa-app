import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'database_helper.dart';

class StockUtils {
  static Future<void> recalculateStocks({bool force = false}) async {
    try {
      final db = await DatabaseHelper.database;
      
      // Always recalculate if called, to ensure consistency after edits/deletes
      await db.transaction((txn) async {
        await txn.delete('stocks');

        // Professional: Check global inventory tracking setting
        final settingsRes = await txn.query('settings', where: 'key = ?', whereArgs: ['shouldTrackInventory']);
        final bool globalInventoryTracking = settingsRes.isEmpty || settingsRes.first['value'] == '1';

        final entries = await txn.query('stock_entries', where: 'isDeleted = 0');
        final sales = await txn.query('sales', where: 'isDeleted = 0');
        final returns = await txn.query('returns', where: 'isDeleted = 0');
        final woffs = await txn.query('write_offs', where: 'isDeleted = 0');
        final transfers = await txn.query('stock_transfers', where: 'isDeleted = 0');
        final inventories = await txn.query('inventories', where: 'isDeleted = 0');

        List<Map<String, dynamic>> timeline = [];
        for (var d in entries) timeline.add({'type': 'entry', 'date': d['date'], 'doc': d});
        for (var d in sales) timeline.add({'type': 'sale', 'date': d['date'], 'doc': d});
        for (var d in returns) timeline.add({'type': 'return', 'date': d['date'], 'doc': d});
        for (var d in woffs) timeline.add({'type': 'woff', 'date': d['date'], 'doc': d});
        for (var d in transfers) timeline.add({'type': 'transfer', 'date': d['date'], 'doc': d});
        for (var d in inventories) timeline.add({'type': 'inventory', 'date': d['date'], 'doc': d});

        timeline.sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));

        for (var step in timeline) {
          final type = step['type'];
          final doc = step['doc'];
          final dId = doc['id'];

          switch (type) {
            case 'entry':
              final items = await txn.query('stock_entry_items', where: 'entryId = ?', whereArgs: [dId]);
              for (var it in items) await _increaseStockTxn(txn, it['productId'].toString(), doc['warehouseId'].toString(), (it['quantity'] as num).toDouble());
              break;
            case 'sale':
              if (!globalInventoryTracking) break;
              final items = await txn.query('sale_items', where: 'saleId = ?', whereArgs: [dId]);
              for (var it in items) {
                final pRes = await txn.query('products', columns: ['trackStock'], where: 'id = ?', whereArgs: [it['productId']]);
                if (pRes.isNotEmpty && pRes.first['trackStock'] == 1) {
                  await _decreaseStockTxn(txn, it['productId'].toString(), doc['warehouseId'].toString(), (it['quantity'] as num).toDouble());
                }
              }
              break;
            case 'return':
              if (!globalInventoryTracking) break;
              final items = await txn.query('return_items', where: 'returnId = ?', whereArgs: [dId]);
              for (var it in items) await _increaseStockTxn(txn, it['productId'].toString(), doc['warehouseId'].toString(), (it['quantity'] as num).toDouble());
              break;
            case 'woff':
              final items = await txn.query('write_off_items', where: 'writeOffId = ?', whereArgs: [dId]);
              for (var it in items) await _decreaseStockTxn(txn, it['productId'].toString(), doc['warehouseId'].toString(), (it['quantity'] as num).toDouble());
              break;
            case 'transfer':
              final items = await txn.query('stock_transfer_items', where: 'transferId = ?', whereArgs: [dId]);
              for (var it in items) {
                final qty = (it['quantity'] as num).toDouble();
                await _decreaseStockTxn(txn, it['productId'].toString(), doc['fromWarehouseId'].toString(), qty);
                await _increaseStockTxn(txn, it['productId'].toString(), doc['toWarehouseId'].toString(), qty);
              }
              break;
            case 'inventory':
              final items = await txn.query('inventory_items', where: 'inventoryId = ?', whereArgs: [dId]);
              for (var it in items) {
                await txn.insert('stocks', {
                  'productId': it['productId'].toString(),
                  'warehouseId': doc['warehouseId'].toString(),
                  'quantity': (it['actualQuantity'] as num).toDouble()
                }, conflictAlgorithm: ConflictAlgorithm.replace);
              }
              break;
          }
        }
      });
    } catch (e) {
      debugPrint('Recalculate error: $e');
    }
  }

  static Future<void> _increaseStockTxn(Transaction txn, String pId, String wId, double qty) async {
    final cur = await txn.query('stocks', where: 'productId=? AND warehouseId=?', whereArgs:[pId, wId]);
    double curQty = cur.isNotEmpty ? (cur.first['quantity'] as num).toDouble() : 0;
    await txn.insert('stocks', {'productId':pId, 'warehouseId':wId, 'quantity':curQty + qty}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> _decreaseStockTxn(Transaction txn, String pId, String wId, double qty) async {
    final cur = await txn.query('stocks', where: 'productId=? AND warehouseId=?', whereArgs:[pId, wId]);
    double curQty = cur.isNotEmpty ? (cur.first['quantity'] as num).toDouble() : 0;
    await txn.insert('stocks', {'productId':pId, 'warehouseId':wId, 'quantity':curQty - qty}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
