import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../models/models.dart';
import 'database_helper.dart';

class WarehouseRepository {
  static Future<List<Warehouse>> getWarehouses({bool includeDeleted = false}) async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'warehouses', 
      where: includeDeleted ? null : 'isDeleted = 0',
      orderBy: 'name ASC'
    );
    return List.generate(maps.length, (i) => Warehouse.fromJson(maps[i]));
  }

  static Future<void> saveWarehouse(Warehouse warehouse) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'warehouses',
      {...warehouse.toJson(), 'isDeleted': 0, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> deleteWarehouse(String id) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'warehouses', 
      {'isDeleted': 1, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0}, 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }
}
