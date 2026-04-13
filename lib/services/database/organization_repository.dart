import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../models/models.dart';
import 'database_helper.dart';

class OrganizationRepository {
  static Future<List<Organization>> getOrganizations() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('organizations');
    return List.generate(maps.length, (i) {
      return Organization.fromJson(maps[i]);
    });
  }

  static Future<void> saveOrganization(Organization org) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'organizations',
      {
        ...org.toJson(),
        'updatedAt': DateTime.now().toIso8601String(),
        'isSynced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> deleteOrganization(String id) async {
    final db = await DatabaseHelper.database;
    // Soft delete (Disable)
    await db.update(
      'organizations',
      {
        'isDeleted': 1,
        'updatedAt': DateTime.now().toIso8601String(),
        'isSynced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> restoreOrganization(String id) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'organizations',
      {
        'isDeleted': 0,
        'updatedAt': DateTime.now().toIso8601String(),
        'isSynced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> permanentDeleteOrganization(String id) async {
    final db = await DatabaseHelper.database;
    await db.delete('organizations', where: 'id = ?', whereArgs: [id]);
  }
}
