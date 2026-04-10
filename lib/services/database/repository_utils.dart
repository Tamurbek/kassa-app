import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../models/models.dart';
import 'database_helper.dart';

class RegisterRepository {
  static Future<List<Register>> getRegisters() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('registers', where: 'isDeleted = 0', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => Register.fromJson(maps[i]));
  }

  static Future<void> saveRegister(Register register) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'registers',
      {...register.toJson(), 'isDeleted': 0, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> deleteRegister(String id) async {
    final db = await DatabaseHelper.database;
    await db.update('registers', {'isDeleted': 1, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0}, where: 'id = ?', whereArgs: [id]);
  }
}

class SettingsRepository {
  static Future<Map<String, String>> getSettings() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('settings');
    return {for (var m in maps) m['key'] as String: m['value'] as String};
  }

  static Future<void> saveSetting(String key, String value) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'settings',
      {'key': key, 'value': value, 'updatedAt': DateTime.now().toIso8601String(), 'isSynced': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
