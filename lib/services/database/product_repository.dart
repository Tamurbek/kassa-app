import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../models/models.dart';
import 'database_helper.dart';

class ProductRepository {
  static Future<List<Product>> getProducts() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products', 
      where: 'isDeleted = 0',
      orderBy: 'name ASC'
    );
    
    List<Product> products = [];
    for (var m in maps) {
      final additionalBarcodes = await db.query(
        'product_additional_barcodes',
        where: 'productId = ?',
        whereArgs: [m['id']],
      );
      
      final stocksList = await db.query(
        'stocks',
        where: 'productId = ?',
        whereArgs: [m['id']],
      );
      
      Map<String, double> stocks = {};
      for (var s in stocksList) {
        stocks[s['warehouseId'] as String] = (s['quantity'] as num).toDouble();
      }

      final productMap = Map<String, dynamic>.from(m);
      productMap['additionalBarcodes'] = additionalBarcodes.map((e) => e['barcode']).toList();
      productMap['stocks'] = stocks;
      productMap['isDeleted'] = m['isDeleted'] == 1;
      productMap['trackStock'] = m['trackStock'] == 1;
      
      products.add(Product.fromJson(productMap));
    }
    return products;
  }

  static Future<void> saveProduct(Product product) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      await txn.insert(
        'products',
        {...product.toJson(), 'isDeleted': product.isDeleted ? 1 : 0, 'trackStock': product.trackStock ? 1 : 0, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0}..remove('stocks')..remove('additionalBarcodes'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      await txn.delete('product_additional_barcodes', where: 'productId = ?', whereArgs: [product.id]);
      for (var barcode in product.additionalBarcodes) {
        await txn.insert('product_additional_barcodes', {'productId': product.id, 'barcode': barcode});
      }
      
      for (var entry in product.stocks.entries) {
        await txn.insert(
          'stocks',
          {'productId': product.id, 'warehouseId': entry.key, 'quantity': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static Future<void> deleteProduct(String id) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'products', 
      {'isDeleted': 1, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0}, 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }
}
