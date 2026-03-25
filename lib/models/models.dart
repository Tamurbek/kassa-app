import 'package:uuid/uuid.dart';

class Warehouse {
  final String id;
  final String name;
  final bool isMain;

  Warehouse({required this.id, required this.name, this.isMain = false});

  factory Warehouse.create(String name, {bool isMain = false}) =>
      Warehouse(id: Uuid().v4(), name: name, isMain: isMain);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'isMain': isMain};
  factory Warehouse.fromJson(Map<String, dynamic> json) => Warehouse(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Noma\'lum',
    isMain: json['isMain'] == true || json['isMain'] == 1,
  );
}

class Register {
  final String id;
  final String name;
  final String warehouseId;

  final String? activeDeviceId;

  Register({
    required this.id,
    required this.name,
    required this.warehouseId,
    this.activeDeviceId,
  });

  factory Register.create(String name, String warehouseId) => Register(
    id: Uuid().v4(),
    name: name,
    warehouseId: warehouseId,
    activeDeviceId: null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'warehouseId': warehouseId,
    'activeDeviceId': activeDeviceId,
  };
  factory Register.fromJson(Map<String, dynamic> json) => Register(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Noma\'lum',
    warehouseId: json['warehouseId']?.toString() ?? '',
    activeDeviceId: json['activeDeviceId']?.toString(),
  );
}

class Category {
  final String id;
  final String name;
  final bool isDeleted;

  Category({required this.id, required this.name, this.isDeleted = false});

  factory Category.create(String name) => Category(id: Uuid().v4(), name: name);

  Category copyWith({
    String? name,
    bool? isDeleted,
  }) => Category(
    id: id,
    name: name ?? this.name,
    isDeleted: isDeleted ?? this.isDeleted,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isDeleted': isDeleted,
  };
  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Noma\'lum',
    isDeleted: json['isDeleted'] ?? false,
  );
}

class Product {
  final String id;
  final String name;
  final double price; // selling price
  final double costPrice; // NEW: tannarx
  final String categoryId;
  final String barcode;
  final List<String> additionalBarcodes;
  final Map<String, double> stocks;
  final String? imagePath;
  final bool isDeleted;
  final String unit; // 'dona', 'kg', 'litr', etc.
  final bool trackStock; // NEW: Should this item subtract from warehouse?

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.costPrice = 0.0,
    required this.categoryId,
    required this.barcode,
    this.additionalBarcodes = const [],
    required this.stocks,
    this.imagePath,
    this.isDeleted = false,
    this.unit = 'dona',
    this.trackStock = true,
  });

  double get stock => stocks.values.fold(0.0, (sum, val) => sum + val);

  factory Product.create(
    String name,
    double price,
    String categoryId,
    String barcode, {
    double costPrice = 0.0,
    String? imagePath,
    String unit = 'dona',
    bool trackStock = true,
  }) => Product(
    id: Uuid().v4(),
    name: name,
    price: price,
    costPrice: costPrice,
    categoryId: categoryId,
    barcode: barcode,
    additionalBarcodes: [],
    stocks: {},
    imagePath: imagePath,
    unit: unit,
    trackStock: trackStock,
  );

  Product copyWith({
    String? name,
    double? price,
    double? costPrice,
    String? categoryId,
    String? barcode,
    List<String>? additionalBarcodes,
    Map<String, double>? stocks,
    String? imagePath,
    bool? isDeleted,
    String? unit,
    bool? trackStock,
  }) => Product(
    id: id,
    name: name ?? this.name,
    price: price ?? this.price,
    costPrice: costPrice ?? this.costPrice,
    categoryId: categoryId ?? this.categoryId,
    barcode: barcode ?? this.barcode,
    additionalBarcodes: additionalBarcodes ?? this.additionalBarcodes,
    stocks: stocks ?? this.stocks,
    imagePath: imagePath ?? this.imagePath,
    isDeleted: isDeleted ?? this.isDeleted,
    unit: unit ?? this.unit,
    trackStock: trackStock ?? this.trackStock,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'costPrice': costPrice,
    'categoryId': categoryId,
    'barcode': barcode,
    'additionalBarcodes': additionalBarcodes,
    'imagePath': imagePath,
    'stocks': stocks,
    'isDeleted': isDeleted,
    'unit': unit,
    'trackStock': trackStock,
  };

  factory Product.fromJson(Map<String, dynamic> json) {
    var stockData = json['stocks'];
    Map<String, double> stocks = {};
    if (stockData != null && stockData is Map) {
      stocks = stockData.map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      );
    }

    var additionalB = json['additionalBarcodes'];
    List<String> barcodes = [];
    if (additionalB != null && additionalB is List) {
      barcodes = additionalB.map((e) => e.toString()).toList();
    }

    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Noma\'lum',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      costPrice: double.tryParse(json['costPrice']?.toString() ?? '0') ?? 0.0,
      categoryId: json['categoryId']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      additionalBarcodes: barcodes,
      stocks: stocks,
      imagePath: json['imagePath']?.toString(),
      isDeleted: json['isDeleted'] ?? false,
      unit: json['unit']?.toString() ?? 'dona',
      trackStock: json['trackStock'] ?? true,
    );
  }
}

class Sale {
  final String id;
  final DateTime date;
  final List<SaleItem> items;
  final double total;
  final String registerId;
  final String warehouseId;

  Sale({
    required this.id,
    required this.date,
    required this.items,
    required this.total,
    required this.registerId,
    required this.warehouseId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
    'total': total,
    'registerId': registerId,
    'warehouseId': warehouseId,
  };

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
    id: json['id']?.toString() ?? '',
    date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    items:
        (json['items'] as List?)?.map((i) => SaleItem.fromJson(i)).toList() ??
        [],
    total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
    registerId: json['registerId']?.toString() ?? '',
    warehouseId: json['warehouseId']?.toString() ?? '',
  );
}

class SaleItem {
  final String productId;
  final String productName;
  final double quantity;
  final double price; // selling price
  final double costPrice; // NEW: cost at time of sale

  SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.costPrice = 0.0,
  });

  SaleItem copyWith({
    String? productId,
    String? productName,
    double? quantity,
    double? price,
    double? costPrice,
  }) => SaleItem(
    productId: productId ?? this.productId,
    productName: productName ?? this.productName,
    quantity: quantity ?? this.quantity,
    price: price ?? this.price,
    costPrice: costPrice ?? this.costPrice,
  );

  double get subtotal => quantity * price;
  double get profit => quantity * (price - costPrice);

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'price': price,
    'costPrice': costPrice,
  };

  factory SaleItem.fromJson(Map<String, dynamic> json) => SaleItem(
    productId: json['productId']?.toString() ?? '',
    productName: json['productName']?.toString() ?? 'Noma\'lum',
    quantity: double.tryParse(json['quantity']?.toString() ?? '1') ?? 1.0,
    price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
    costPrice: double.tryParse(json['costPrice']?.toString() ?? '0') ?? 0.0,
  );
}

class StockEntry {
  final String id;
  final String warehouseId;
  final DateTime date;
  final List<StockEntryItem> items;
  final String description;

  StockEntry({
    required this.id,
    required this.warehouseId,
    required this.date,
    required this.items,
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'warehouseId': warehouseId,
    'date': date.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
    'description': description,
  };

  factory StockEntry.fromJson(Map<String, dynamic> json) => StockEntry(
    id: json['id']?.toString() ?? '',
    warehouseId: json['warehouseId']?.toString() ?? '',
    date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    items:
        (json['items'] as List?)
            ?.map((i) => StockEntryItem.fromJson(i))
            .toList() ??
        [],
    description: json['description']?.toString() ?? '',
  );
}

class StockEntryItem {
  final String productId;
  final String productName;
  final double quantity;
  final double costPrice; // NEW: tannarx at entry

  StockEntryItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.costPrice = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'costPrice': costPrice,
  };

  factory StockEntryItem.fromJson(Map<String, dynamic> json) => StockEntryItem(
    productId: json['productId']?.toString() ?? '',
    productName: json['productName']?.toString() ?? 'Noma\'lum',
    quantity: double.tryParse(json['quantity']?.toString() ?? '1') ?? 1.0,
    costPrice: double.tryParse(json['costPrice']?.toString() ?? '0') ?? 0.0,
  );
}

// --- NEW: Stock Transfer (Omborlararo ko'chirish) ---
class StockTransfer {
  final String id;
  final String fromWarehouseId;
  final String toWarehouseId;
  final DateTime date;
  final List<StockTransferItem> items;
  final String description;

  StockTransfer({
    required this.id,
    required this.fromWarehouseId,
    required this.toWarehouseId,
    required this.date,
    required this.items,
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromWarehouseId': fromWarehouseId,
    'toWarehouseId': toWarehouseId,
    'date': date.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
    'description': description,
  };

  factory StockTransfer.fromJson(Map<String, dynamic> json) => StockTransfer(
    id: json['id']?.toString() ?? '',
    fromWarehouseId: json['fromWarehouseId']?.toString() ?? '',
    toWarehouseId: json['toWarehouseId']?.toString() ?? '',
    date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    items:
        (json['items'] as List?)
            ?.map((i) => StockTransferItem.fromJson(i))
            .toList() ??
        [],
    description: json['description']?.toString() ?? '',
  );
}

class StockTransferItem {
  final String productId;
  final String productName;
  final double quantity;

  StockTransferItem({
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
  };

  factory StockTransferItem.fromJson(Map<String, dynamic> json) => StockTransferItem(
    productId: json['productId']?.toString() ?? '',
    productName: json['productName']?.toString() ?? 'Noma\'lum',
    quantity: double.tryParse(json['quantity']?.toString() ?? '1') ?? 1.0,
  );
}

// --- NEW: Returns (Vazvrat) ---
class SaleReturn {
  final String id;
  final String saleId;
  final DateTime date;
  final List<SaleReturnItem> items;
  final double total;
  final String warehouseId;

  SaleReturn({
    required this.id,
    required this.saleId,
    required this.date,
    required this.items,
    required this.total,
    required this.warehouseId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'saleId': saleId,
    'date': date.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
    'total': total,
    'warehouseId': warehouseId,
  };

  factory SaleReturn.fromJson(Map<String, dynamic> json) => SaleReturn(
    id: json['id']?.toString() ?? '',
    saleId: json['saleId']?.toString() ?? '',
    date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    items:
        (json['items'] as List?)
            ?.map((i) => SaleReturnItem.fromJson(i))
            .toList() ??
        [],
    total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
    warehouseId: json['warehouseId']?.toString() ?? '',
  );
}

class SaleReturnItem {
  final String productId;
  final String productName;
  final double quantity;
  final double price;

  SaleReturnItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'price': price,
  };

  factory SaleReturnItem.fromJson(Map<String, dynamic> json) => SaleReturnItem(
    productId: json['productId']?.toString() ?? '',
    productName: json['productName']?.toString() ?? 'Noma\'lum',
    quantity: double.tryParse(json['quantity']?.toString() ?? '1') ?? 1.0,
    price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
  );
}

// --- NEW: Write Off (Hisobdan chiqarish) ---
class WriteOff {
  final String id;
  final DateTime date;
  final String warehouseId;
  final List<WriteOffItem> items;
  final String description;

  WriteOff({
    required this.id,
    required this.date,
    required this.warehouseId,
    required this.items,
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'warehouseId': warehouseId,
    'items': items.map((i) => i.toJson()).toList(),
    'description': description,
  };

  factory WriteOff.fromJson(Map<String, dynamic> json) => WriteOff(
    id: json['id']?.toString() ?? '',
    date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    warehouseId: json['warehouseId']?.toString() ?? '',
    items:
        (json['items'] as List?)
            ?.map((i) => WriteOffItem.fromJson(i))
            .toList() ??
        [],
    description: json['description']?.toString() ?? '',
  );
}

class WriteOffItem {
  final String productId;
  final String productName;
  final double quantity;

  WriteOffItem({
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
  };

  factory WriteOffItem.fromJson(Map<String, dynamic> json) => WriteOffItem(
    productId: json['productId']?.toString() ?? '',
    productName: json['productName']?.toString() ?? 'Noma\'lum',
    quantity: double.tryParse(json['quantity']?.toString() ?? '1') ?? 1.0,
  );
}

// --- NEW: Inventory Adjustment ---
class InventoryEntry {
  final String id;
  final DateTime date;
  final String warehouseId;
  final List<InventoryItem> items;
  final String description;

  InventoryEntry({
    required this.id,
    required this.date,
    required this.warehouseId,
    required this.items,
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'warehouseId': warehouseId,
    'items': items.map((i) => i.toJson()).toList(),
    'description': description,
  };

  factory InventoryEntry.fromJson(Map<String, dynamic> json) => InventoryEntry(
    id: json['id']?.toString() ?? '',
    date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    warehouseId: json['warehouseId']?.toString() ?? '',
    items:
        (json['items'] as List?)
            ?.map((i) => InventoryItem.fromJson(i))
            .toList() ??
        [],
    description: json['description']?.toString() ?? '',
  );
}

class InventoryItem {
  final String productId;
  final String productName;
  final double expectedQuantity;
  final double actualQuantity;

  InventoryItem({
    required this.productId,
    required this.productName,
    required this.expectedQuantity,
    required this.actualQuantity,
  });

  double get difference => actualQuantity - expectedQuantity;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'expectedQuantity': expectedQuantity,
    'actualQuantity': actualQuantity,
  };

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
    productId: json['productId']?.toString() ?? '',
    productName: json['productName']?.toString() ?? 'Noma\'lum',
    expectedQuantity:
        double.tryParse(json['expectedQuantity']?.toString() ?? '0') ?? 0.0,
    actualQuantity:
        double.tryParse(json['actualQuantity']?.toString() ?? '0') ?? 0.0,
  );
}

enum UserRole { admin, seller }

class User {
  final String id;
  final String name;
  final String pin;
  final UserRole role;
  final bool isDeleted;

  User({
    required this.id,
    required this.name,
    required this.pin,
    required this.role,
    this.isDeleted = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pin': pin,
    'role': role.index,
    'isDeleted': isDeleted,
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Noma\'lum',
    pin: json['pin']?.toString() ?? '',
    role: UserRole.values[(json['role'] ?? 1) as int],
    isDeleted: json['isDeleted'] ?? false,
  );
}
