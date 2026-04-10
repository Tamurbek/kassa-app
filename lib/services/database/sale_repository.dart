import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../models/models.dart';
import 'database_helper.dart';

class SaleRepository {
  static Future<List<Sale>> getSales() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sales', 
      where: 'isDeleted = 0',
      orderBy: 'date DESC'
    );
    
    List<Sale> sales = [];
    for (var m in maps) {
      final itemsMap = await db.query(
        'sale_items', 
        where: 'saleId = ?', 
        whereArgs: [m['id']]
      );
      
      final saleMap = Map<String, dynamic>.from(m);
      saleMap['items'] = itemsMap;
      sales.add(Sale.fromJson(saleMap));
    }
    return sales;
  }

  static Future<void> saveSale(Sale sale) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      await txn.insert(
        'sales',
        {...sale.toJson(), 'isDeleted': 0, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0}..remove('items'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      await txn.delete('sale_items', where: 'saleId = ?', whereArgs: [sale.id]);
      for (var item in sale.items) {
        await txn.insert('sale_items', {...item.toJson(), 'saleId': sale.id});
        
        // Stock management (decrement only if trackStock is true)
        final List<Map<String, dynamic>> products = await txn.query(
          'products', 
          where: 'id = ?', 
          whereArgs: [item.productId]
        );
        if (products.isNotEmpty && (products.first['trackStock'] == 1 || products.first['trackStock'] == true)) {
          await txn.execute('''
            UPDATE stocks SET quantity = quantity - ? 
            WHERE productId = ? AND warehouseId = ?
          ''', [item.quantity, item.productId, sale.warehouseId]);
        }
      }
    });
  }

  static Future<void> deleteSale(String id) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'sales', 
      {'isDeleted': 1, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0}, 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }
}
