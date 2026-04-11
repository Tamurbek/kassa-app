import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../models/models.dart';
import 'database_helper.dart';

class SuspendedSaleRepository {
  static Future<void> saveSuspendedSale(SuspendedSale sale) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      await txn.insert(
        'suspended_sales',
        {
          'id': sale.id,
          'date': sale.date.toIso8601String(),
          'total': sale.total,
          'note': sale.note,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.delete('suspended_sale_items', where: 'suspendedSaleId = ?', whereArgs: [sale.id]);

      for (var item in sale.items) {
        await txn.insert('suspended_sale_items', {
          'suspendedSaleId': sale.id,
          'productId': item.productId,
          'productName': item.productName,
          'quantity': item.quantity,
          'price': item.price,
          'costPrice': item.costPrice,
        });
      }
    });
  }

  static Future<List<SuspendedSale>> getSuspendedSales() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('suspended_sales', orderBy: 'date DESC');
    
    List<SuspendedSale> results = [];
    for (var map in maps) {
      final List<Map<String, dynamic>> itemMaps = await db.query(
        'suspended_sale_items',
        where: 'suspendedSaleId = ?',
        whereArgs: [map['id']],
      );
      
      final items = itemMaps.map((i) => SaleItem.fromJson(i)).toList();
      results.add(SuspendedSale(
        id: map['id'].toString(),
        date: DateTime.parse(map['date'].toString()),
        total: double.tryParse(map['total'].toString()) ?? 0.0,
        note: map['note']?.toString(),
        items: items,
      ));
    }
    return results;
  }

  static Future<void> deleteSuspendedSale(String id) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      await txn.delete('suspended_sale_items', where: 'suspendedSaleId = ?', whereArgs: [id]);
      await txn.delete('suspended_sales', where: 'id = ?', whereArgs: [id]);
    });
  }
}
