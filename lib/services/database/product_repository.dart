import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../models/models.dart';
import '../../core/utils/translit.dart';
import 'database_helper.dart';

class ProductRepository {
  static Future<List<Product>> getProducts({int? limit, int? offset, String? searchQuery, String? categoryId, bool includeDeleted = false}) async {
    final db = await DatabaseHelper.database;
    
    String whereClause = includeDeleted ? '1=1' : 'isDeleted = 0';
    List<dynamic> whereArgs = [];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final variations = Translit.getVariations(searchQuery);
      List<String> orGroups = [];
      for (var variant in variations) {
        orGroups.add('(name LIKE ? OR barcode LIKE ? OR pluCode LIKE ? OR boxBarcode LIKE ? OR id IN (SELECT productId FROM product_additional_barcodes WHERE barcode LIKE ?) OR id IN (SELECT productId FROM product_additional_box_barcodes WHERE barcode LIKE ?))');
        whereArgs.addAll(['%$variant%', '%$variant%', '%$variant%', '%$variant%', '%$variant%', '%$variant%']);
      }
      whereClause += ' AND (${orGroups.join(' OR ')})';
    }

    if (categoryId != null && categoryId.isNotEmpty) {
      whereClause += ' AND categoryId = ?';
      whereArgs.add(categoryId);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
      limit: limit,
      offset: offset,
    );

    if (maps.isEmpty) return [];

    final productIds = maps.map((m) => "'${m['id']}'").join(',');

    // Fetch all barcodes and stocks for these products in ONE query
    final List<Map<String, dynamic>> allBarcodes = await db.rawQuery(
      'SELECT * FROM product_additional_barcodes WHERE productId IN ($productIds)'
    );

    final List<Map<String, dynamic>> allBoxBarcodes = await db.rawQuery(
      'SELECT * FROM product_additional_box_barcodes WHERE productId IN ($productIds)'
    );

    final List<Map<String, dynamic>> allStocks = await db.rawQuery(
      'SELECT * FROM stocks WHERE productId IN ($productIds)'
    );

    // Categorize data by productId for O(1) lookup
    Map<String, List<String>> barcodeMap = {};
    for (var b in allBarcodes) {
      final pid = b['productId'] as String;
      barcodeMap.putIfAbsent(pid, () => []).add(b['barcode'] as String);
    }

    Map<String, List<String>> boxBarcodeMap = {};
    for (var b in allBoxBarcodes) {
      final pid = b['productId'] as String;
      boxBarcodeMap.putIfAbsent(pid, () => []).add(b['barcode'] as String);
    }

    Map<String, Map<String, double>> stockMap = {};
    for (var s in allStocks) {
      final pid = s['productId'] as String;
      stockMap.putIfAbsent(pid, () => {})[s['warehouseId'] as String] = (s['quantity'] as num).toDouble();
    }

    return maps.map((m) {
      final pid = m['id'] as String;
      final productMap = Map<String, dynamic>.from(m);
      productMap['additionalBarcodes'] = barcodeMap[pid] ?? [];
      productMap['additionalBoxBarcodes'] = boxBarcodeMap[pid] ?? [];
      productMap['stocks'] = stockMap[pid] ?? {};
      productMap['isDeleted'] = m['isDeleted'] == 1;
      productMap['trackStock'] = m['trackStock'] == 1;
      return Product.fromJson(productMap);
    }).toList();
  }

  static Future<void> saveProduct(Product product) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      await txn.insert(
        'products',
        {...product.toJson(), 'isDeleted': product.isDeleted ? 1 : 0, 'trackStock': product.trackStock ? 1 : 0, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0}
            ..remove('stocks')
            ..remove('additionalBarcodes')
            ..remove('additionalBoxBarcodes'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      await txn.delete('product_additional_barcodes', where: 'productId = ?', whereArgs: [product.id]);
      for (var barcode in product.additionalBarcodes.toSet()) {
        await txn.insert(
          'product_additional_barcodes', 
          {'productId': product.id, 'barcode': barcode},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await txn.delete('product_additional_box_barcodes', where: 'productId = ?', whereArgs: [product.id]);
      for (var barcode in product.additionalBoxBarcodes.toSet()) {
        await txn.insert(
          'product_additional_box_barcodes', 
          {'productId': product.id, 'barcode': barcode},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
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

  static Future<Product?> getProductById(String id) async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;

    final m = maps.first;
    final List<Map<String, dynamic>> barcodes = await db.query('product_additional_barcodes', where: 'productId = ?', whereArgs: [id]);
    final List<Map<String, dynamic>> boxBarcodes = await db.query('product_additional_box_barcodes', where: 'productId = ?', whereArgs: [id]);
    final List<Map<String, dynamic>> stocks = await db.query('stocks', where: 'productId = ?', whereArgs: [id]);

    final productMap = Map<String, dynamic>.from(m);
    productMap['additionalBarcodes'] = barcodes.map((b) => b['barcode'] as String).toList();
    productMap['additionalBoxBarcodes'] = boxBarcodes.map((b) => b['barcode'] as String).toList();
    productMap['stocks'] = {for (var s in stocks) s['warehouseId'].toString(): (s['quantity'] as num).toDouble()};
    productMap['isDeleted'] = m['isDeleted'] == 1;
    productMap['trackStock'] = m['trackStock'] == 1;

    return Product.fromJson(productMap);
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
