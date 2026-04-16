import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_helper.dart';

class SyncRepository {
  static Future<void> markAsSynced(String table, String id) async {
    final db = await DatabaseHelper.database;
    await db.update(
      table,
      {'isSynced': 1},
      where: table == 'settings' ? 'key = ?' : 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<Map<String, List<Map<String, dynamic>>>> getUnsyncedRecords() async {
    final db = await DatabaseHelper.database;
    final tables = [
      'categories', 'products', 'warehouses', 'registers', 
      'sales', 'returns', 'write_offs', 'inventories', 
      'stock_entries', 'users', 'stock_transfers', 'settings'
    ];
    
    final Map<String, List<Map<String, dynamic>>> result = {};
    for (var table in tables) {
      final records = await db.query(table, where: 'isSynced = 0');
      if (records.isNotEmpty) {
        final List<Map<String, dynamic>> enriched = [];
        for (var record in records) {
          final Map<String, dynamic> mutable = Map.from(record);
          final id = table == 'settings' ? record['key'] : record['id'];

          if (table == 'products') {
            final barcodes = await db.query('product_additional_barcodes', where: 'productId = ?', whereArgs: [id]);
            final boxBarcodes = await db.query('product_additional_box_barcodes', where: 'productId = ?', whereArgs: [id]);
            mutable['additionalBarcodes'] = barcodes.map((b) => b['barcode']).toList();
            mutable['additionalBoxBarcodes'] = boxBarcodes.map((b) => b['barcode']).toList();
          } else if (table == 'sales') {
            mutable['items'] = await db.query('sale_items', where: 'saleId = ?', whereArgs: [id]);
          } else if (table == 'returns') {
            mutable['items'] = await db.query('return_items', where: 'returnId = ?', whereArgs: [id]);
          } else if (table == 'write_offs') {
            mutable['items'] = await db.query('write_off_items', where: 'writeOffId = ?', whereArgs: [id]);
          } else if (table == 'inventories') {
            mutable['items'] = await db.query('inventory_items', where: 'inventoryId = ?', whereArgs: [id]);
          } else if (table == 'stock_entries') {
            mutable['items'] = await db.query('stock_entry_items', where: 'entryId = ?', whereArgs: [id]);
          } else if (table == 'stock_transfers') {
            mutable['items'] = await db.query('stock_transfer_items', where: 'transferId = ?', whereArgs: [id]);
          }
          enriched.add(mutable);
        }
        result[table] = enriched;
      }
    }
    return result;
  }
}
