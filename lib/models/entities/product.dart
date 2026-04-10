import 'package:uuid/uuid.dart';

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
      isDeleted: json['isDeleted'] == 1 || json['isDeleted'] == true,
      unit: json['unit']?.toString() ?? 'dona',
      trackStock: json['trackStock'] == 1 || json['trackStock'] == true || json['trackStock'] == null,
    );
  }
}
