import 'dart:io';
import 'dart:async';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static Database? _db;
  static Future<Database>? _initFuture;
  static bool _factoryInitialized = false;

  static const int databaseVersion = 28;
  static const String databaseName = 'simple_sale.db';

  static Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    try {
      _initFuture ??= _initDb();
      _db = await _initFuture!;
      return _db!;
    } catch (e) {
      _initFuture = null;
      _db = null;
      rethrow;
    }
  }

  static Future<String> getDatabasePath() async {
    final supportDir = await getApplicationSupportDirectory();
    return join(supportDir.path, databaseName);
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

  static Future<Database> _initDb() async {
    if ((Platform.isWindows || Platform.isLinux || Platform.isMacOS) && !_factoryInitialized) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _factoryInitialized = true;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final supportDir = await getApplicationSupportDirectory();

    final oldPath = join(docsDir.path, databaseName);
    final newPath = join(supportDir.path, databaseName);

    // Migration: move existing DB from Documents to App Support if it exists
    final oldFile = File(oldPath);
    if (await oldFile.exists()) {
      if (!await supportDir.exists()) {
        await supportDir.create(recursive: true);
      }
      await oldFile.copy(newPath);
      await oldFile.delete();
    }

    return await openDatabase(
      newPath,
      version: databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
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
        isDeleted INTEGER NOT NULL DEFAULT 0,
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
        isDeleted INTEGER NOT NULL DEFAULT 0,
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
        quantityInBox REAL NOT NULL DEFAULT 1,
        boxPrice REAL,
        boxBarcode TEXT,
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
      CREATE TABLE product_additional_box_barcodes (
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
        discount REAL NOT NULL DEFAULT 0,
        customerId TEXT,
        customerName TEXT,
        isDeleted INTEGER NOT NULL DEFAULT 0,
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
        costPrice REAL NOT NULL DEFAULT 0,
        isBox INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE returns (
        id TEXT PRIMARY KEY,
        saleId TEXT NOT NULL,
        date TEXT NOT NULL,
        total REAL NOT NULL,
        warehouseId TEXT NOT NULL,
        isDeleted INTEGER NOT NULL DEFAULT 0,
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
        isDeleted INTEGER NOT NULL DEFAULT 0,
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
        isDeleted INTEGER NOT NULL DEFAULT 0,
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
        isDeleted INTEGER NOT NULL DEFAULT 0,
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
        costPrice REAL NOT NULL DEFAULT 0,
        price REAL NOT NULL DEFAULT 0,
        isBox INTEGER NOT NULL DEFAULT 0
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
        value TEXT,
        updatedAt TEXT,
        isSynced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE stock_transfers (
        id TEXT PRIMARY KEY,
        fromWarehouseId TEXT NOT NULL,
        toWarehouseId TEXT NOT NULL,
        date TEXT NOT NULL,
        description TEXT,
        isDeleted INTEGER NOT NULL DEFAULT 0,
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
      CREATE TABLE suspended_sales (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        total REAL NOT NULL,
        note TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE suspended_sale_items (
        suspendedSaleId TEXT NOT NULL,
        productId TEXT NOT NULL,
        productName TEXT NOT NULL,
        quantity REAL NOT NULL,
        price REAL NOT NULL,
        costPrice REAL NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE organizations (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT,
        instagram TEXT,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        updatedAt TEXT,
        isSynced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_products_name ON products (name)');
    await db.execute('CREATE INDEX idx_products_barcode ON products (barcode)');
    await db.execute('CREATE INDEX idx_products_deleted ON products (isDeleted)');
    await db.execute('CREATE INDEX idx_categories_deleted ON categories (isDeleted)');
    await db.execute('CREATE INDEX idx_sales_date ON sales (date)');
    await db.execute('CREATE INDEX idx_stock_entries_date ON stock_entries (date)');
    await db.execute('CREATE INDEX idx_additional_barcodes ON product_additional_barcodes (barcode)');
    await db.execute('CREATE INDEX idx_stocks_product ON stocks (productId)');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 25) {
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_products_name ON products (name)'); } catch(_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_products_barcode ON products (barcode)'); } catch(_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_products_deleted ON products (isDeleted)'); } catch(_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_categories_deleted ON categories (isDeleted)'); } catch(_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_date ON sales (date)'); } catch(_) {}
    }
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
    if (oldVersion < 18) {
      final tables = [
        'warehouses', 'registers', 'sales', 'returns', 'write_offs', 
        'inventories', 'stock_entries', 'stock_transfers', 'categories', 'products', 'users'
      ];
      for (var table in tables) {
        try {
           var columns = await db.rawQuery('PRAGMA table_info($table)');
           bool hasIsDeleted = columns.any((c) => c['name'] == 'isDeleted');
           if (!hasIsDeleted) {
             await db.execute('ALTER TABLE $table ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0');
           }
        } catch (e) {
           print("Migration 18 error ($table): $e");
        }
      }
    }
    if (oldVersion < 19) {
      try {
         var columns = await db.rawQuery('PRAGMA table_info(settings)');
         bool hasUpdatedAt = columns.any((c) => c['name'] == 'updatedAt');
         bool hasIsSynced = columns.any((c) => c['name'] == 'isSynced');
         
         if (!hasUpdatedAt) {
            await db.execute('ALTER TABLE settings ADD COLUMN updatedAt TEXT');
         }
         if (!hasIsSynced) {
            await db.execute('ALTER TABLE settings ADD COLUMN isSynced INTEGER NOT NULL DEFAULT 0');
         }
      } catch (e) {
         print("Migration 19 error (settings): $e");
      }
    }
    if (oldVersion < 20) {
      final tables = [
        'categories', 'products', 'warehouses', 'registers', 
        'sales', 'returns', 'write_offs', 'inventories', 
        'stock_entries', 'users', 'stock_transfers', 'settings'
      ];
      for (var table in tables) {
        try {
          var columns = await db.rawQuery('PRAGMA table_info($table)');
          if (table != 'settings') {
            bool hasIsDeleted = columns.any((c) => c['name'] == 'isDeleted');
            if (!hasIsDeleted) {
               await db.execute('ALTER TABLE $table ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0');
            }
          }
          bool hasUpdatedAt = columns.any((c) => c['name'] == 'updatedAt');
          if (!hasUpdatedAt) await db.execute('ALTER TABLE $table ADD COLUMN updatedAt TEXT');
          bool hasIsSynced = columns.any((c) => c['name'] == 'isSynced');
          if (!hasIsSynced) await db.execute('ALTER TABLE $table ADD COLUMN isSynced INTEGER NOT NULL DEFAULT 0');
        } catch (e) {
          print("Migration 20 error ($table): $e");
        }
      }
    }
    if (oldVersion < 21) {
      try {
        await db.execute('ALTER TABLE stock_entry_items ADD COLUMN price REAL NOT NULL DEFAULT 0');
      } catch (e) {
        print("Migration 21 error: $e");
      }
    }
    if (oldVersion < 22) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS suspended_sales (
          id TEXT PRIMARY KEY,
          date TEXT NOT NULL,
          total REAL NOT NULL,
          note TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS suspended_sale_items (
          suspendedSaleId TEXT NOT NULL,
          productId TEXT NOT NULL,
          productName TEXT NOT NULL,
          quantity REAL NOT NULL,
          price REAL NOT NULL,
          costPrice REAL NOT NULL DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 23) {
      try { await db.execute('ALTER TABLE sales ADD COLUMN discount REAL NOT NULL DEFAULT 0'); } catch(_) {}
      try { await db.execute('ALTER TABLE sales ADD COLUMN customerId TEXT'); } catch(_) {}
      try { await db.execute('ALTER TABLE sales ADD COLUMN customerName TEXT'); } catch(_) {}
    }
    if (oldVersion < 24) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS organizations (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          address TEXT,
          instagram TEXT,
          isDeleted INTEGER NOT NULL DEFAULT 0,
          updatedAt TEXT,
          isSynced INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 27) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN quantityInBox REAL NOT NULL DEFAULT 1');
        await db.execute('ALTER TABLE products ADD COLUMN boxPrice REAL');
        await db.execute('ALTER TABLE products ADD COLUMN boxBarcode TEXT');
        await db.execute('ALTER TABLE sale_items ADD COLUMN isBox INTEGER NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE stock_entry_items ADD COLUMN isBox INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        print("Migration 27 error: $e");
      }
    }
    if (oldVersion < 28) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS product_additional_box_barcodes (
          productId TEXT NOT NULL,
          barcode TEXT NOT NULL,
          PRIMARY KEY (productId, barcode)
        )
      ''');
    }
  }

  static Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
        final tables = [
          'categories', 'products', 'warehouses', 'registers', 
          'sales', 'sale_items', 'returns', 'return_items', 
          'write_offs', 'write_off_items', 'inventories', 'inventory_items', 
          'stock_entries', 'stock_entry_items', 'users', 'settings', 
          'stock_transfers', 'stock_transfer_items', 'stocks', 
          'product_additional_barcodes', 'product_additional_box_barcodes',
          'suspended_sales', 'suspended_sale_items', 'organizations'
        ];
        for (var t in tables) {
          try { await txn.delete(t); } catch(_) {}
        }
    });
  }
}
