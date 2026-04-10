import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../models/models.dart';
import 'database_helper.dart';

class UserRepository {
  static Future<List<User>> getUsers() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users', 
      where: 'isDeleted = 0',
      orderBy: 'name ASC'
    );
    return List.generate(maps.length, (i) => User.fromJson(maps[i]));
  }

  static Future<void> saveUser(User user) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'users',
      {...user.toJson(), 'isDeleted': user.isDeleted ? 1 : 0, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> deleteUser(String id) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'users', 
      {'isDeleted': 1, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0}, 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }
}
