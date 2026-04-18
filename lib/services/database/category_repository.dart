import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../models/models.dart';
import 'database_helper.dart';

class CategoryRepository {
  static Future<List<Category>> getCategories({bool includeDeleted = false}) async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories', 
      where: includeDeleted ? null : 'isDeleted = 0',
      orderBy: 'name ASC'
    );
    return List.generate(maps.length, (i) => Category.fromJson(maps[i]));
  }

  static Future<void> saveCategory(Category category) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'categories',
      {...category.toJson(), 'isDeleted': category.isDeleted ? 1 : 0, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> deleteCategory(String id) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'categories', 
      {'isDeleted': 1, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0}, 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }
}
