import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' hide Category;
import '../models/models.dart';

class DatabaseService {
  static Database? _db;
  static Future<Database>? _initFuture;

  static Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _initFuture ??= _initDb();
    _db = await _initFuture!;
    return _db!;
  }

  static Future<String> getDatabasePath() async {
    final supportDir = await getApplicationSupportDirectory();
    return join(supportDir.path, 'simple_sale.db');
  }

  static Future<void> closeDatabase() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
    }
    _db = null;
    _initFuture = null;
  }

  static Future<void> replaceDatabase(File newFile) async {
    if (!await newFile.exists()) {
      throw Exception("Tiklash uchun fayl topilmadi: ${newFile.path}");
    }
    await closeDatabase();
    final path = await getDatabasePath();
    final dbFile = File(path);
    if (!await dbFile.parent.exists()) {
      await dbFile.parent.create(recursive: true);
    }
    await newFile.copy(path);
  }

  static bool _factoryInitialized = false;

  static Future<Database> _initDb() async {
    if ((Platform.isWindows || Platform.isLinux || Platform.isMacOS) && !_factoryInitialized) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _factoryInitialized = true;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final supportDir = await getApplicationSupportDirectory();

    final oldPath = join(docsDir.path, 'simple_sale.db');
    final newPath = join(supportDir.path, 'simple_sale.db');

    // Migration: move existing DB from Documents to App Support if it exists
    final oldFile = File(oldPath);
    if (await oldFile.exists()) {
      if (!await supportDir.exists()) {
        await supportDir.create(recursive: true);
      }
      await oldFile.copy(newPath);
      await oldFile.delete(); // Delete old risky file
    }

    return await openDatabase(
      newPath,
      version: 17,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            isDeleted INTEGER NOT NULL DEFAULT 0,
            updatedAt TEXT,
            isSynced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE warehouses (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            isMain INTEGER NOT NULL DEFAULT 0,
            updatedAt TEXT,
            isSynced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE registers (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            warehouseId TEXT NOT NULL,
            activeDeviceId TEXT,
            updatedAt TEXT,
            isSynced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE products (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            price REAL NOT NULL,
            costPrice REAL NOT NULL DEFAULT 0,
            categoryId TEXT NOT NULL,
            barcode TEXT NOT NULL,
            imagePath TEXT,
            isDeleted INTEGER NOT NULL DEFAULT 0,
            unit TEXT NOT NULL DEFAULT 'dona',
            trackStock INTEGER NOT NULL DEFAULT 1,
            updatedAt TEXT,
            isSynced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE product_additional_barcodes (
            productId TEXT NOT NULL,
            barcode TEXT NOT NULL,
            PRIMARY KEY (productId, barcode)
          )
        ''');
        await db.execute('''
          CREATE TABLE stocks (
            productId TEXT NOT NULL,
            warehouseId TEXT NOT NULL,
            quantity REAL NOT NULL,
            PRIMARY KEY (productId, warehouseId)
          )
        ''');
        await db.execute('''
          CREATE TABLE sales (
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            total REAL NOT NULL,
            registerId TEXT NOT NULL,
            warehouseId TEXT NOT NULL,
            updatedAt TEXT,
            isSynced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE sale_items (
            saleId TEXT NOT NULL,
            productId TEXT NOT NULL,
            productName TEXT NOT NULL,
            quantity REAL NOT NULL,
            price REAL NOT NULL,
            costPrice REAL NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE returns (
            id TEXT PRIMARY KEY,
            saleId TEXT NOT NULL,
            date TEXT NOT NULL,
            total REAL NOT NULL,
            warehouseId TEXT NOT NULL,
            updatedAt TEXT,
            isSynced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE return_items (
            returnId TEXT NOT NULL,
            productId TEXT NOT NULL,
            productName TEXT NOT NULL,
            quantity REAL NOT NULL,
            price REAL NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE write_offs (
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            warehouseId TEXT NOT NULL,
            description TEXT,
            updatedAt TEXT,
            isSynced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE write_off_items (
            writeOffId TEXT NOT NULL,
            productId TEXT NOT NULL,
            productName TEXT NOT NULL,
            quantity REAL NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE inventories (
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            warehouseId TEXT NOT NULL,
            description TEXT,
            updatedAt TEXT,
            isSynced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE inventory_items (
            inventoryId TEXT NOT NULL,
            productId TEXT NOT NULL,
            productName TEXT NOT NULL,
            expectedQuantity REAL NOT NULL,
            actualQuantity REAL NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE stock_entries (
            id TEXT PRIMARY KEY,
            warehouseId TEXT NOT NULL,
            date TEXT NOT NULL,
            description TEXT,
            updatedAt TEXT,
            isSynced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE stock_entry_items (
            entryId TEXT NOT NULL,
            productId TEXT NOT NULL,
            quantity REAL NOT NULL,
            productName TEXT NOT NULL,
            costPrice REAL NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE users (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            pin TEXT NOT NULL,
            role INTEGER NOT NULL,
            isDeleted INTEGER NOT NULL DEFAULT 0,
            updatedAt TEXT,
            isSynced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE stock_transfers (
            id TEXT PRIMARY KEY,
            fromWarehouseId TEXT NOT NULL,
            toWarehouseId TEXT NOT NULL,
            date TEXT NOT NULL,
            description TEXT,
            updatedAt TEXT,
            isSynced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE stock_transfer_items (
            transferId TEXT NOT NULL,
            productId TEXT NOT NULL,
            productName TEXT NOT NULL,
            quantity REAL NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS stocks (
            productId TEXT,
            warehouseId TEXT,
            quantity REAL,
            PRIMARY KEY (productId, warehouseId)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS stock_entries (
              id TEXT PRIMARY KEY,
              warehouseId TEXT NOT NULL,
              date TEXT NOT NULL,
              description TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS stock_entry_items (
              entryId TEXT NOT NULL,
              productId TEXT NOT NULL,
              quantity REAL NOT NULL,
              productName TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS users (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              pin TEXT NOT NULL,
              role INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS sale_items (
              saleId TEXT NOT NULL,
              productId TEXT NOT NULL,
              productName TEXT NOT NULL,
              quantity REAL NOT NULL,
              price REAL NOT NULL
            )
          ''');
        }
        if (oldVersion < 5) {
          try { await db.execute('ALTER TABLE products ADD COLUMN imagePath TEXT'); } catch(_) {}
        }
        if (oldVersion < 6) {
          try { await db.execute('ALTER TABLE categories ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0'); } catch(_) {}
          try { await db.execute('ALTER TABLE products ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0'); } catch(_) {}
          try { await db.execute('ALTER TABLE users ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0'); } catch(_) {}
        }
        if (oldVersion < 7) {
          try { await db.execute("ALTER TABLE products ADD COLUMN unit TEXT NOT NULL DEFAULT 'dona'"); } catch(_) {}
        }
        if (oldVersion < 8) {
          try { await db.execute('ALTER TABLE registers ADD COLUMN activeDeviceId TEXT'); } catch(_) {}
        }
        if (oldVersion < 9) {
          try { await db.execute('ALTER TABLE products ADD COLUMN trackStock INTEGER NOT NULL DEFAULT 1'); } catch(_) {}
          await db.execute('''
            CREATE TABLE IF NOT EXISTS product_additional_barcodes (
              productId TEXT NOT NULL,
              barcode TEXT NOT NULL,
              PRIMARY KEY (productId, barcode)
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS returns (
              id TEXT PRIMARY KEY,
              saleId TEXT NOT NULL,
              date TEXT NOT NULL,
              total REAL NOT NULL,
              warehouseId TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS return_items (
              returnId TEXT NOT NULL,
              productId TEXT NOT NULL,
              productName TEXT NOT NULL,
              quantity REAL NOT NULL,
              price REAL NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS write_offs (
              id TEXT PRIMARY KEY,
              date TEXT NOT NULL,
              warehouseId TEXT NOT NULL,
              description TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS write_off_items (
              writeOffId TEXT NOT NULL,
              productId TEXT NOT NULL,
              productName TEXT NOT NULL,
              quantity REAL NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS inventories (
              id TEXT PRIMARY KEY,
              date TEXT NOT NULL,
              warehouseId TEXT NOT NULL,
              description TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS inventory_items (
              inventoryId TEXT NOT NULL,
              productId TEXT NOT NULL,
              productName TEXT NOT NULL,
              expectedQuantity REAL NOT NULL,
              actualQuantity REAL NOT NULL
            )
          ''');
        }
        if (oldVersion < 10) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS settings (
              key TEXT PRIMARY KEY,
              value TEXT
            )
          ''');
        }
        if (oldVersion < 11) {
          try { await db.execute('ALTER TABLE products ADD COLUMN costPrice REAL NOT NULL DEFAULT 0'); } catch(_) {}
          try { await db.execute('ALTER TABLE sale_items ADD COLUMN costPrice REAL NOT NULL DEFAULT 0'); } catch(_) {}
        }
        if (oldVersion < 12) {
          try { await db.execute('ALTER TABLE warehouses ADD COLUMN isMain INTEGER NOT NULL DEFAULT 0'); } catch(_) {}
          await db.execute('''
            CREATE TABLE IF NOT EXISTS stock_transfers (
              id TEXT PRIMARY KEY,
              fromWarehouseId TEXT NOT NULL,
              toWarehouseId TEXT NOT NULL,
              date TEXT NOT NULL,
              description TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS stock_transfer_items (
              transferId TEXT NOT NULL,
              productId TEXT NOT NULL,
              productName TEXT NOT NULL,
              quantity REAL NOT NULL
            )
          ''');
        }
        if (oldVersion < 14) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS stocks (
              productId TEXT,
              warehouseId TEXT,
              quantity REAL,
              PRIMARY KEY (productId, warehouseId)
            )
          ''');
        }
        if (oldVersion < 15) {
          try {
            await db.execute('ALTER TABLE stock_entry_items ADD COLUMN costPrice REAL NOT NULL DEFAULT 0');
          } catch (e) {
            print("Migration 15 error: $e");
          }
        }
        if (oldVersion < 16) {
          final tables = [
            'categories', 'products', 'warehouses', 'registers', 
            'sales', 'returns', 'write_offs', 'inventories', 
            'stock_entries', 'users', 'stock_transfers'
          ];
          for (var table in tables) {
            try {
              await db.execute('ALTER TABLE $table ADD COLUMN updatedAt TEXT');
              await db.execute('ALTER TABLE $table ADD COLUMN isSynced INTEGER NOT NULL DEFAULT 0');
            } catch (e) {
              print("Migration 16 error ($table): $e");
            }
          }
        }
        if (oldVersion < 17) {
          final tables = [
            'categories', 'products', 'warehouses', 'registers', 
            'sales', 'returns', 'write_offs', 'inventories', 
            'stock_entries', 'users', 'stock_transfers'
          ];
          for (var table in tables) {
            try {
              // We check if column exists by trying to add it and catching error, 
              // but a better way is to check pragma table_info
              var columns = await db.rawQuery('PRAGMA table_info($table)');
              bool hasUpdatedAt = columns.any((c) => c['name'] == 'updatedAt');
              bool hasIsSynced = columns.any((c) => c['name'] == 'isSynced');
              
              if (!hasUpdatedAt) {
                 await db.execute('ALTER TABLE $table ADD COLUMN updatedAt TEXT');
              }
              if (!hasIsSynced) {
                 await db.execute('ALTER TABLE $table ADD COLUMN isSynced INTEGER NOT NULL DEFAULT 0');
              }
            } catch (e) {
              print("Migration 17 error ($table): $e");
            }
          }
        }
      },
    );
  }

  // --- Categories ---
  static Future<void> saveCategory(Category category) async {
    final db = await database;
    final json = category.toJson();
    json['isDeleted'] = category.isDeleted ? 1 : 0;
    json['updatedAt'] = DateTime.now().toIso8601String();
    json['isSynced'] = 0;
    await db.insert(
      'categories',
      json,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Category>> getCategories() async {
    final db = await database;
    final res = await db.query('categories', orderBy: 'name ASC');
    return res
        .map(
          (c) => Category.fromJson({
            'id': c['id']?.toString() ?? '',
            'name': c['name']?.toString() ?? 'Noma\'lum',
            'isDeleted': c['isDeleted'] == 1,
          }),
        )
        .toList();
  }

  static Future<void> deleteCategory(String id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // --- Warehouses ---
  static Future<void> saveWarehouse(Warehouse warehouse) async {
    final db = await database;
    await db.insert('warehouses', {
      'id': warehouse.id,
      'name': warehouse.name,
      'isMain': warehouse.isMain ? 1 : 0,
      'updatedAt': DateTime.now().toIso8601String(),
      'isSynced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Warehouse>> getWarehouses() async {
    final db = await database;
    final res = await db.query('warehouses', orderBy: 'name ASC');
    return res
        .map(
          (w) => Warehouse.fromJson({
            'id': w['id']?.toString() ?? '',
            'name': w['name']?.toString() ?? 'Noma\'lum',
            'isMain': w['isMain'] == 1,
          }),
        )
        .toList();
  }

  static Future<void> deleteWarehouse(String id) async {
    final db = await database;
    await db.delete('warehouses', where: 'id = ?', whereArgs: [id]);
  }

  // --- Registers ---
  static Future<void> saveRegister(Register register) async {
    final db = await database;
    await db.insert('registers', {
      'id': register.id,
      'name': register.name,
      'warehouseId': register.warehouseId,
      'activeDeviceId': register.activeDeviceId,
      'updatedAt': DateTime.now().toIso8601String(),
      'isSynced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Register>> getRegisters() async {
    final db = await database;
    final res = await db.query('registers', orderBy: 'name ASC');
    return res
        .map(
          (r) => Register.fromJson({
            'id': r['id']?.toString() ?? '',
            'name': r['name']?.toString() ?? 'Noma\'lum',
            'warehouseId': r['warehouseId']?.toString() ?? '',
            'activeDeviceId': r['activeDeviceId']?.toString(),
          }),
        )
        .toList();
  }

  static Future<void> deleteRegister(String id) async {
    final db = await database;
    await db.delete('registers', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateRegisterDevice(String id, String? deviceId) async {
    final db = await database;
    await db.update('registers', {'activeDeviceId': deviceId}, where: 'id = ?', whereArgs: [id]);
  }

  // --- Products & Stocks ---
  static Future<void> saveProduct(Product product) async {
    final db = await database;
    await db.insert('products', {
      'id': product.id,
      'name': product.name,
      'price': product.price,
      'costPrice': product.costPrice,
      'categoryId': product.categoryId,
      'barcode': product.barcode,
      'imagePath': product.imagePath,
      'isDeleted': product.isDeleted ? 1 : 0,
      'unit': product.unit,
      'trackStock': product.trackStock ? 1 : 0,
      'updatedAt': DateTime.now().toIso8601String(),
      'isSynced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Save additional barcodes
    await db.delete(
      'product_additional_barcodes',
      where: 'productId = ?',
      whereArgs: [product.id],
    );
    for (var b in product.additionalBarcodes) {
      if (b.isNotEmpty) {
        await db.insert(
          'product_additional_barcodes',
          {'productId': product.id, 'barcode': b},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    // Save stocks separately
    for (var entry in product.stocks.entries) {
      await db.insert('stocks', {
        'productId': product.id,
        'warehouseId': entry.key,
        'quantity': entry.value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<List<Product>> getProducts() async {
    final db = await database;
    
    // Safety check for stocks table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stocks (
        productId TEXT,
        warehouseId TEXT,
        quantity REAL,
        PRIMARY KEY (productId, warehouseId)
      )
    ''');

    final prodRes = await db.query('products', orderBy: 'name ASC');
    
    // Auto-recalculate if stocks are missing/empty (only happens once on migration)
    final anyStock = await db.query('stocks', limit: 1);
    if (anyStock.isEmpty) {
       await recalculateStocks();
    }
    
    final List<Product> products = [];

    for (var pMap in prodRes) {
      final stockRes = await db.query(
        'stocks',
        where: 'productId = ?',
        whereArgs: [pMap['id']],
      );
      final stocks = {
        for (var s in stockRes)
          (s['warehouseId']?.toString() ?? 'null'):
              double.tryParse(s['quantity']?.toString() ?? '0') ?? 0.0,
      };

      products.add(
        Product(
          id: pMap['id']?.toString() ?? '',
          name: pMap['name']?.toString() ?? 'Noma\'lum',
          price: double.tryParse(pMap['price']?.toString() ?? '0') ?? 0.0,
          costPrice: double.tryParse(pMap['costPrice']?.toString() ?? '0') ?? 0.0,
          categoryId: pMap['categoryId']?.toString() ?? '',
          barcode: pMap['barcode']?.toString() ?? '',
          stocks: stocks,
          imagePath: pMap['imagePath']?.toString(),
          isDeleted: pMap['isDeleted'] == 1,
          unit: pMap['unit']?.toString() ?? 'dona',
          trackStock: pMap['trackStock'] == 1,
          additionalBarcodes: (await db.query(
            'product_additional_barcodes',
            where: 'productId = ?',
            whereArgs: [pMap['id']],
          )).map((b) => b['barcode'].toString()).toList(),
        ),
      );
    }
    return products;
  }

  static Future<void> deleteProduct(String id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
    await db.delete('stocks', where: 'productId = ?', whereArgs: [id]);
  }

  static Future<void> updateStock(
    String productId,
    String warehouseId,
    double newQuantity,
  ) async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stocks (
        productId TEXT,
        warehouseId TEXT,
        quantity REAL,
        PRIMARY KEY (productId, warehouseId)
      )
    ''');
    await db.insert('stocks', {
      'productId': productId,
      'warehouseId': warehouseId,
      'quantity': newQuantity,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateProductCostPrice(String id, double costPrice) async {
    final db = await database;
    await db.update('products', {'costPrice': costPrice}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateProductImagePath(String id, String path) async {
    final db = await database;
    await db.update('products', {'imagePath': path}, where: 'id = ?', whereArgs: [id]);
  }

  // --- Bulk Sync ---
  static Future<void> clearAllAndReplace({
    required List<Category> categories,
    required List<Product> products,
    required List<Warehouse> warehouses,
    required List<Register> registers,
    List<User> users = const [],
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('categories');
      await txn.delete('products');
      await txn.delete('warehouses');
      await txn.delete('registers');
      await txn.delete('stocks');
      if (users.isNotEmpty) await txn.delete('users');

      for (var c in categories) {
        final json = c.toJson();
        json['isDeleted'] = c.isDeleted ? 1 : 0;
        json['updatedAt'] = DateTime.now().toIso8601String();
        json['isSynced'] = 1; // Already from server
        await txn.insert('categories', json);
      }
      for (var w in warehouses) {
        final json = w.toJson();
        json['isMain'] = w.isMain ? 1 : 0;
        json['updatedAt'] = DateTime.now().toIso8601String();
        json['isSynced'] = 1;
        await txn.insert('warehouses', json);
      }
      for (var r in registers) {
        final json = r.toJson();
        json['updatedAt'] = DateTime.now().toIso8601String();
        json['isSynced'] = 1;
        await txn.insert('registers', json);
      }
      for (var u in users) {
        final json = u.toJson();
        json['isDeleted'] = u.isDeleted ? 1 : 0;
        json['updatedAt'] = DateTime.now().toIso8601String();
        json['isSynced'] = 1;
        await txn.insert(
          'users',
          json,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (var p in products) {
        await txn.insert('products', {
          'id': p.id,
          'name': p.name,
          'price': p.price,
          'costPrice': p.costPrice,
          'categoryId': p.categoryId,
          'barcode': p.barcode,
          'imagePath': p.imagePath,
          'isDeleted': p.isDeleted ? 1 : 0,
          'unit': p.unit,
          'trackStock': p.trackStock ? 1 : 0,
          'updatedAt': DateTime.now().toIso8601String(),
          'isSynced': 1,
        });
        for (var entry in p.stocks.entries) {
          await txn.insert('stocks', {
            'productId': p.id,
            'warehouseId': entry.key,
            'quantity': entry.value,
          });
        }
      }
    });
  }

  // --- Settings ---
  static Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<String?> getSetting(String key) async {
    final db = await database;
    final res = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (res.isNotEmpty) {
      return res.first['value']?.toString();
    }
    return null;
  }

  static Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final res = await db.query('settings');
    return {
      for (var row in res)
        row['key'].toString(): row['value'].toString(),
    };
  }

  // --- Stock Entries ---
  static Future<void> saveStockEntry(StockEntry entry) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('stock_entries', {
        'id': entry.id,
        'warehouseId': entry.warehouseId,
        'date': entry.date.toIso8601String(),
        'description': entry.description,
        'updatedAt': DateTime.now().toIso8601String(),
        'isSynced': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      for (var item in entry.items) {
        await txn.insert('stock_entry_items', {
          'entryId': entry.id,
          'productId': item.productId,
          'productName': item.productName,
          'quantity': item.quantity,
          'costPrice': item.costPrice,
        });

        // Update product's general costPrice to the latest entry price
        if (item.costPrice > 0) {
          await txn.update('products', {'costPrice': item.costPrice}, 
            where: 'id = ?', whereArgs: [item.productId]);
        }

        // Atomic STOCK update
        await _increaseStockTxn(txn, item.productId, entry.warehouseId, item.quantity);
      }
    });
  }

  static Future<List<StockEntry>> getStockEntries() async {
    final db = await database;
    final entriesRes = await db.query('stock_entries', orderBy: 'date DESC');
    final List<StockEntry> entries = [];

    for (var eMap in entriesRes) {
      final itemsRes = await db.query(
        'stock_entry_items',
        where: 'entryId = ?',
        whereArgs: [eMap['id']],
      );
      final items = itemsRes
          .map(
            (i) => StockEntryItem.fromJson({
              'productId': i['productId'],
              'productName': i['productName'],
              'quantity': i['quantity'],
              'costPrice': i['costPrice'],
            }),
          )
          .toList();

      entries.add(
        StockEntry(
          id: eMap['id']?.toString() ?? '',
          warehouseId: eMap['warehouseId']?.toString() ?? '',
          date: eMap['date'] != null
              ? DateTime.parse(eMap['date'].toString())
              : DateTime.now(),
          description: eMap['description']?.toString() ?? '',
          items: items,
        ),
      );
    }
    return entries;
  }

  // --- Sales ---
  static Future<void> saveSale(Sale sale) async {
    debugPrint('DatabaseService: Saving sale ${sale.id} for warehouse ${sale.warehouseId}');
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('sales', {
        'id': sale.id,
        'date': sale.date.toIso8601String(),
        'total': sale.total,
        'registerId': sale.registerId,
        'warehouseId': sale.warehouseId,
        'updatedAt': DateTime.now().toIso8601String(),
        'isSynced': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      for (var item in sale.items) {
        await txn.insert('sale_items', {
          'saleId': sale.id,
          'productId': item.productId,
          'productName': item.productName,
          'quantity': item.quantity,
          'price': item.price,
          'costPrice': item.costPrice,
        });

        // Atomic STOCK update
        final pRes = await txn.query('products', columns: ['trackStock'], where: 'id = ?', whereArgs: [item.productId]);
        if (pRes.isNotEmpty && pRes.first['trackStock'] == 1) {
          debugPrint('DatabaseService: Deducting ${item.quantity} from stock for product ${item.productId}');
          await _decreaseStockTxn(txn, item.productId, sale.warehouseId, item.quantity);
        } else {
          debugPrint('DatabaseService: Skipping stock deduction for ${item.productId} (trackStock=0 or not found)');
        }
      }
    });
  }

  static Future<List<Sale>> getSales() async {
    final db = await database;
    final salesRes = await db.query('sales', orderBy: 'date DESC');
    final List<Sale> sales = [];

    for (var sMap in salesRes) {
      final itemsRes = await db.query(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: [sMap['id']],
      );
      final items = itemsRes
          .map(
            (i) => SaleItem.fromJson({
              'productId': i['productId'],
              'productName': i['productName'],
              'quantity': i['quantity'],
              'price': i['price'],
              'costPrice': i['costPrice'],
            }),
          )
          .toList();

      sales.add(
        Sale(
          id: sMap['id']?.toString() ?? '',
          date: sMap['date'] != null
              ? DateTime.parse(sMap['date'].toString())
              : DateTime.now(),
          items: items,
          total: double.tryParse(sMap['total']?.toString() ?? '0') ?? 0.0,
          registerId: sMap['registerId']?.toString() ?? '',
          warehouseId: sMap['warehouseId']?.toString() ?? '',
        ),
      );
    }
    return sales;
  }

  // --- Users ---
  static Future<void> saveUser(User user) async {
    final db = await database;
    await db.insert('users', {
      'id': user.id,
      'name': user.name,
      'pin': user.pin,
      'role': user.role.index,
      'isDeleted': user.isDeleted ? 1 : 0,
      'updatedAt': DateTime.now().toIso8601String(),
      'isSynced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<User>> getUsers() async {
    final db = await database;
    final res = await db.query('users', orderBy: 'name ASC');
    return res
        .map(
          (u) => User.fromJson({
            'id': u['id']?.toString() ?? '',
            'name': u['name']?.toString() ?? 'Noma\'lum',
            'pin': u['pin']?.toString() ?? '',
            'role': u['role'] ?? 1,
            'isDeleted': u['isDeleted'] == 1,
          }),
        )
        .toList();
  }

  static Future<void> deleteUser(String id) async {
    final db = await database;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // --- Returns ---
  static Future<void> saveReturn(SaleReturn ret) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('returns', {
        'id': ret.id,
        'saleId': ret.saleId,
        'date': ret.date.toIso8601String(),
        'total': ret.total,
        'warehouseId': ret.warehouseId,
        'updatedAt': DateTime.now().toIso8601String(),
        'isSynced': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      for (var item in ret.items) {
        await txn.insert('return_items', {
          'returnId': ret.id,
          'productId': item.productId,
          'productName': item.productName,
          'quantity': item.quantity,
          'price': item.price,
        });

        // Atomic STOCK update
        await _increaseStockTxn(txn, item.productId, ret.warehouseId, item.quantity);
      }
    });
  }

  static Future<List<SaleReturn>> getReturns() async {
    final db = await database;
    final res = await db.query('returns', orderBy: 'date DESC');
    final List<SaleReturn> returns = [];
    for (var rMap in res) {
      final itemsRes = await db.query(
        'return_items',
        where: 'returnId = ?',
        whereArgs: [rMap['id']],
      );
      final items = itemsRes
          .map(
            (i) => SaleReturnItem.fromJson({
              'productId': i['productId'],
              'productName': i['productName'],
              'quantity': i['quantity'],
              'price': i['price'],
            }),
          )
          .toList();
      returns.add(
        SaleReturn(
          id: rMap['id'].toString(),
          saleId: rMap['saleId'].toString(),
          date: DateTime.parse(rMap['date'].toString()),
          total: (rMap['total'] as num).toDouble(),
          warehouseId: rMap['warehouseId'].toString(),
          items: items,
        ),
      );
    }
    return returns;
  }

  // --- Write Offs ---
  static Future<void> saveWriteOff(WriteOff wo) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('write_offs', {
        'id': wo.id,
        'date': wo.date.toIso8601String(),
        'warehouseId': wo.warehouseId,
        'description': wo.description,
        'updatedAt': DateTime.now().toIso8601String(),
        'isSynced': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      for (var item in wo.items) {
        await txn.insert('write_off_items', {
          'writeOffId': wo.id,
          'productId': item.productId,
          'productName': item.productName,
          'quantity': item.quantity,
        });

        // Atomic STOCK update
        await _decreaseStockTxn(txn, item.productId, wo.warehouseId, item.quantity);
      }
    });
  }

  static Future<List<WriteOff>> getWriteOffs() async {
    final db = await database;
    final res = await db.query('write_offs', orderBy: 'date DESC');
    final List<WriteOff> results = [];
    for (var map in res) {
      final itemsRes = await db.query(
        'write_off_items',
        where: 'writeOffId = ?',
        whereArgs: [map['id']],
      );
      final items = itemsRes
          .map(
            (i) => WriteOffItem.fromJson({
              'productId': i['productId'],
              'productName': i['productName'],
              'quantity': i['quantity'],
            }),
          )
          .toList();
      results.add(
        WriteOff(
          id: map['id'].toString(),
          date: DateTime.parse(map['date'].toString()),
          warehouseId: map['warehouseId'].toString(),
          description: map['description']?.toString() ?? '',
          items: items,
        ),
      );
    }
    return results;
  }

  // --- Inventories ---
  static Future<void> saveInventory(InventoryEntry inv) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('inventories', {
        'id': inv.id,
        'date': inv.date.toIso8601String(),
        'warehouseId': inv.warehouseId,
        'description': inv.description,
        'updatedAt': DateTime.now().toIso8601String(),
        'isSynced': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      for (var item in inv.items) {
        await txn.insert('inventory_items', {
          'inventoryId': inv.id,
          'productId': item.productId,
          'productName': item.productName,
          'expectedQuantity': item.expectedQuantity,
          'actualQuantity': item.actualQuantity,
        });

        // Atomic STOCK update (Inventory sets actual stock)
        await txn.insert('stocks', {
          'productId': item.productId,
          'warehouseId': inv.warehouseId,
          'quantity': item.actualQuantity,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<List<InventoryEntry>> getInventories() async {
    final db = await database;
    final res = await db.query('inventories', orderBy: 'date DESC');
    final List<InventoryEntry> results = [];
    for (var map in res) {
      final itemsRes = await db.query(
        'inventory_items',
        where: 'inventoryId = ?',
        whereArgs: [map['id']],
      );
      final items = itemsRes
          .map(
            (i) => InventoryItem.fromJson({
              'productId': i['productId'],
              'productName': i['productName'],
              'expectedQuantity': i['expectedQuantity'],
              'actualQuantity': i['actualQuantity'],
            }),
          )
          .toList();
      results.add(
        InventoryEntry(
          id: map['id'].toString(),
          date: DateTime.parse(map['date'].toString()),
          warehouseId: map['warehouseId'].toString(),
          description: map['description']?.toString() ?? '',
          items: items,
        ),
      );
    }
    return results;
  }

  static Future<void> deleteReturn(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      final entryRes = await txn.query('returns', where: 'id = ?', whereArgs: [id]);
      if (entryRes.isEmpty) return;
      final wId = entryRes.first['warehouseId'].toString();
      final items = await txn.query('return_items', where: 'returnId = ?', whereArgs: [id]);

      for (var item in items) {
        final pId = item['productId'].toString();
        final qty = double.tryParse(item['quantity'].toString()) ?? 0;
        await _decreaseStockTxn(txn, pId, wId, qty); // Revert increase
      }

      await txn.delete('returns', where: 'id = ?', whereArgs: [id]);
      await txn.delete('return_items', where: 'returnId = ?', whereArgs: [id]);
    });
  }

  static Future<void> deleteWriteOff(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      final entryRes = await txn.query('write_offs', where: 'id = ?', whereArgs: [id]);
      if (entryRes.isEmpty) return;
      final wId = entryRes.first['warehouseId'].toString();
      final items = await txn.query('write_off_items', where: 'writeOffId = ?', whereArgs: [id]);

      for (var item in items) {
        final pId = item['productId'].toString();
        final qty = double.tryParse(item['quantity'].toString()) ?? 0;
        await _increaseStockTxn(txn, pId, wId, qty); // Revert decrease
      }

      await txn.delete('write_offs', where: 'id = ?', whereArgs: [id]);
      await txn.delete(
        'write_off_items',
        where: 'writeOffId = ?',
        whereArgs: [id],
      );
    });
  }

  static Future<void> deleteStockEntry(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      final entryRes = await txn.query('stock_entries', where: 'id = ?', whereArgs: [id]);
      if (entryRes.isEmpty) return;
      final wId = entryRes.first['warehouseId'].toString();
      final items = await txn.query('stock_entry_items', where: 'entryId = ?', whereArgs: [id]);

      for (var item in items) {
        final pId = item['productId'].toString();
        final qty = double.tryParse(item['quantity'].toString()) ?? 0;
        await _decreaseStockTxn(txn, pId, wId, qty); // Revert increase
      }

      await txn.delete('stock_entries', where: 'id = ?', whereArgs: [id]);
      await txn.delete(
        'stock_entry_items',
        where: 'entryId = ?',
        whereArgs: [id],
      );
    });
  }

  static Future<void> deleteInventory(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('inventories', where: 'id = ?', whereArgs: [id]);
      await txn.delete(
        'inventory_items',
        where: 'inventoryId = ?',
        whereArgs: [id],
      );
    });
  }

  static Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('categories');
      await txn.delete('warehouses');
      await txn.delete('registers');
      await txn.delete('products');
      await txn.delete('product_additional_barcodes');
      await txn.delete('stocks');
      await txn.delete('sales');
      await txn.delete('sale_items');
      await txn.delete('returns');
      await txn.delete('return_items');
      await txn.delete('write_offs');
      await txn.delete('write_off_items');
      await txn.delete('inventories');
      await txn.delete('inventory_items');
      await txn.delete('stock_entries');
      await txn.delete('stock_entry_items');
      await txn.delete('stock_transfers');
      await txn.delete('stock_transfer_items');
      await txn.delete('users');
      await txn.delete('settings');
    });
  }

  // --- Stock Transfers ---
  static Future<void> saveStockTransfer(StockTransfer transfer) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('stock_transfers', {
        'id': transfer.id,
        'fromWarehouseId': transfer.fromWarehouseId,
        'toWarehouseId': transfer.toWarehouseId,
        'date': transfer.date.toIso8601String(),
        'description': transfer.description,
        'updatedAt': DateTime.now().toIso8601String(),
        'isSynced': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      for (var item in transfer.items) {
        await txn.insert('stock_transfer_items', {
          'transferId': transfer.id,
          'productId': item.productId,
          'productName': item.productName,
          'quantity': item.quantity,
        });

        // Atomic STOCK update
        await _decreaseStockTxn(txn, item.productId, transfer.fromWarehouseId, item.quantity);
        await _increaseStockTxn(txn, item.productId, transfer.toWarehouseId, item.quantity);
      }
    });
  }

  static Future<List<StockTransfer>> getStockTransfers() async {
    final db = await database;
    final res = await db.query('stock_transfers', orderBy: 'date DESC');
    final List<StockTransfer> transfers = [];

    for (var m in res) {
      final itemsRes = await db.query(
        'stock_transfer_items',
        where: 'transferId = ?',
        whereArgs: [m['id']],
      );
      final items = itemsRes
          .map((i) => StockTransferItem.fromJson({
                'productId': i['productId'],
                'productName': i['productName'],
                'quantity': i['quantity'],
              }))
          .toList();

      transfers.add(StockTransfer(
        id: m['id']?.toString() ?? '',
        fromWarehouseId: m['fromWarehouseId']?.toString() ?? '',
        toWarehouseId: m['toWarehouseId']?.toString() ?? '',
        date: m['date'] != null ? DateTime.parse(m['date'].toString()) : DateTime.now(),
        description: m['description']?.toString() ?? '',
        items: items,
      ));
    }
    return transfers;
  }

  static Future<void> recalculateStocks({bool force = false}) async {
    try {
      final db = await database;
      
      if (!force) {
        final existing = await db.query('stocks', limit: 1);
        if (existing.isNotEmpty) {
          debugPrint('RecalculateStocks skipped (already has data)');
          return;
        }
      }
      
      await db.transaction((txn) async {
        // 1. Reset
        await txn.delete('stocks');

        // 2. Fetch all documents that affect stock
        final entries = await _safeQuery(txn, 'stock_entries');
        final sales = await _safeQuery(txn, 'sales');
        final returns = await _safeQuery(txn, 'returns');
        final woffs = await _safeQuery(txn, 'write_offs');
        final transfers = await _safeQuery(txn, 'stock_transfers');
        final inventories = await _safeQuery(txn, 'inventories');

        // 3. Flatten and unify into a timeline
        List<Map<String, dynamic>> timeline = [];

        for (var d in entries) timeline.add({'type': 'entry', 'date': d['date'], 'doc': d});
        for (var d in sales) timeline.add({'type': 'sale', 'date': d['date'], 'doc': d});
        for (var d in returns) timeline.add({'type': 'return', 'date': d['date'], 'doc': d});
        for (var d in woffs) timeline.add({'type': 'woff', 'date': d['date'], 'doc': d});
        for (var d in transfers) timeline.add({'type': 'transfer', 'date': d['date'], 'doc': d});
        for (var d in inventories) timeline.add({'type': 'inventory', 'date': d['date'], 'doc': d});

        // 4. Sort by date (ascending)
        timeline.sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));

        // 5. Process chronologically
        for (var step in timeline) {
          final type = step['type'];
          final doc = step['doc'];
          final dId = doc['id'];

          try {
            switch (type) {
              case 'entry':
                final wId = doc['warehouseId'].toString();
                final items = await txn.query('stock_entry_items', where: 'entryId = ?', whereArgs: [dId]);
                for (var it in items) {
                  await _increaseStockTxn(txn, it['productId'].toString(), wId, double.tryParse(it['quantity'].toString()) ?? 0);
                }
                break;

              case 'sale':
                final wId = doc['warehouseId'].toString();
                final items = await txn.query('sale_items', where: 'saleId = ?', whereArgs: [dId]);
                for (var it in items) {
                  final pId = it['productId'].toString();
                  final pRes = await txn.query('products', columns: ['trackStock'], where: 'id = ?', whereArgs: [pId]);
                  if (pRes.isNotEmpty && pRes.first['trackStock'] == 1) {
                    await _decreaseStockTxn(txn, pId, wId, double.tryParse(it['quantity'].toString()) ?? 0);
                  }
                }
                break;

              case 'return':
                final wId = doc['warehouseId'].toString();
                final items = await txn.query('return_items', where: 'returnId = ?', whereArgs: [dId]);
                for (var it in items) {
                  await _increaseStockTxn(txn, it['productId'].toString(), wId, double.tryParse(it['quantity'].toString()) ?? 0);
                }
                break;

              case 'woff':
                final wId = doc['warehouseId'].toString();
                final items = await txn.query('write_off_items', where: 'writeOffId = ?', whereArgs: [dId]);
                for (var it in items) {
                  await _decreaseStockTxn(txn, it['productId'].toString(), wId, double.tryParse(it['quantity'].toString()) ?? 0);
                }
                break;

              case 'transfer':
                final from = doc['fromWarehouseId'].toString();
                final to = doc['toWarehouseId'].toString();
                final items = await txn.query('stock_transfer_items', where: 'transferId = ?', whereArgs: [dId]);
                for (var it in items) {
                  final pId = it['productId'].toString();
                  final qty = double.tryParse(it['quantity'].toString()) ?? 0;
                  await _decreaseStockTxn(txn, pId, from, qty);
                  await _increaseStockTxn(txn, pId, to, qty);
                }
                break;

              case 'inventory':
                final wId = doc['warehouseId'].toString();
                final items = await txn.query('inventory_items', where: 'inventoryId = ?', whereArgs: [dId]);
                for (var it in items) {
                  final actual = double.tryParse(it['actualQuantity'].toString()) ?? 0;
                  await txn.insert('stocks', {
                    'productId': it['productId'].toString(),
                    'warehouseId': wId,
                    'quantity': actual
                  }, conflictAlgorithm: ConflictAlgorithm.replace);
                }
                break;
            }
          } catch (e) {
            debugPrint('Recalculate step error ($type, ID: $dId): $e');
          }
        }
      });
    } catch (e) {
      debugPrint('Overall recalculateStocks error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> _safeQuery(dynamic dbOrTxn, String table) async {
    try {
      return await dbOrTxn.query(table);
    } catch (e) {
      debugPrint('Safe query failed for table $table: $e');
      return [];
    }
  }

  static Future<void> _increaseStockTxn(Transaction txn, String pId, String wId, double qty) async {
    final cur = await txn.query('stocks', where: 'productId=? AND warehouseId=?', whereArgs:[pId, wId]);
    double curQty = cur.isNotEmpty ? (double.tryParse(cur.first['quantity']?.toString() ?? '0') ?? 0) : 0;
    await txn.insert('stocks', {'productId':pId, 'warehouseId':wId, 'quantity':curQty + qty}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> _decreaseStockTxn(Transaction txn, String pId, String wId, double qty) async {
    final cur = await txn.query('stocks', where: 'productId=? AND warehouseId=?', whereArgs:[pId, wId]);
    double curQty = cur.isNotEmpty ? (double.tryParse(cur.first['quantity']?.toString() ?? '0') ?? 0) : 0;
    await txn.insert('stocks', {'productId':pId, 'warehouseId':wId, 'quantity':curQty - qty}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteStockTransfer(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('stock_transfers', where: 'id = ?', whereArgs: [id]);
      await txn.delete('stock_transfer_items', where: 'transferId = ?', whereArgs: [id]);
    });
  }

  static Future<void> deleteSetting(String key) async {
    final db = await DatabaseService.database;
    await db.delete('settings', where: 'key = ?', whereArgs: [key]);
  }

  static Future<void> markAsSynced(String table, String id) async {
    final db = await database;
    await db.update(
      table,
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<Map<String, List<Map<String, dynamic>>>> getUnsyncedRecords() async {
    final db = await database;
    final tables = [
      'categories', 'products', 'warehouses', 'registers', 
      'sales', 'returns', 'write_offs', 'inventories', 
      'stock_entries', 'users', 'stock_transfers'
    ];
    
    final Map<String, List<Map<String, dynamic>>> result = {};
    for (var table in tables) {
      try {
        final records = await db.query(table, where: 'isSynced = 0');
        if (records.isNotEmpty) {
          final List<Map<String, dynamic>> enriched = [];
          for (var record in records) {
            final Map<String, dynamic> mutable = Map.from(record);
            final id = record['id'];

            // Enrich with child items if needed
            if (table == 'sales') {
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
      } catch (e) {
        debugPrint('Sync query failed enriched for table $table: $e');
      }
    }
    return result;
  }

  static Future<void> saveSyncedRecord(String table, Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      final Map<String, dynamic> mutable = Map.from(data);
      final List<dynamic>? items = mutable.remove('items') as List<dynamic>?;
      mutable['isSynced'] = 1;
      final id = mutable['id'];

      await txn.insert(table, mutable, conflictAlgorithm: ConflictAlgorithm.replace);

      if (items != null) {
        if (table == 'sales') {
          await txn.delete('sale_items', where: 'saleId = ?', whereArgs: [id]);
          for (var item in items) {
            await txn.insert('sale_items', Map<String, dynamic>.from(item));
          }
        } else if (table == 'returns') {
          await txn.delete('return_items', where: 'returnId = ?', whereArgs: [id]);
          for (var item in items) {
            await txn.insert('return_items', Map<String, dynamic>.from(item));
          }
        } else if (table == 'write_offs') {
          await txn.delete('write_off_items', where: 'writeOffId = ?', whereArgs: [id]);
          for (var item in items) {
            await txn.insert('write_off_items', Map<String, dynamic>.from(item));
          }
        } else if (table == 'inventories') {
          await txn.delete('inventory_items', where: 'inventoryId = ?', whereArgs: [id]);
          for (var item in items) {
            await txn.insert('inventory_items', Map<String, dynamic>.from(item));
          }
        } else if (table == 'stock_entries') {
          await txn.delete('stock_entry_items', where: 'entryId = ?', whereArgs: [id]);
          for (var item in items) {
            await txn.insert('stock_entry_items', Map<String, dynamic>.from(item));
          }
        } else if (table == 'stock_transfers') {
          await txn.delete('stock_transfer_items', where: 'transferId = ?', whereArgs: [id]);
          for (var item in items) {
            await txn.insert('stock_transfer_items', Map<String, dynamic>.from(item));
          }
        }
      }
    });

    // If transactions are changed, we should eventually recalculate stocks
    if (['sales', 'returns', 'write_offs', 'stock_entries', 'stock_transfers', 'inventories'].contains(table)) {
      await recalculateStocks();
    }
  }
}
