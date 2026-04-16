import 'package:uuid/uuid.dart';

class Product {
  final String id;
  final String name;
  final double price; // selling price
  final double costPrice; // NEW: tannarx
  final String categoryId;
  final String barcode;
  final List<String> additionalBarcodes;
  final List<String> additionalBoxBarcodes;
  final Map<String, double> stocks;
  final String? imagePath;
  final bool isDeleted;
  final String unit; // 'dona', 'kg', 'litr', etc.
  final bool trackStock; // NEW: Should this item subtract from warehouse?
  final double quantityInBox; // NEW: How many units in a box/block
  final double? boxPrice; // NEW: Optional special price for a full box
  final String? boxBarcode; // NEW: Barcode for the full box
  
  // Performance optimization: pre-calculate normalized strings for search
  late final String normalizedName;
  late final String normalizedBarcode;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.costPrice = 0.0,
    required this.categoryId,
    required this.barcode,
    this.additionalBarcodes = const [],
    this.additionalBoxBarcodes = const [],
    required this.stocks,
    this.imagePath,
    this.isDeleted = false,
    this.unit = 'dona',
    this.trackStock = true,
    this.quantityInBox = 1.0,
    this.boxPrice,
    this.boxBarcode,
  }) {
    normalizedName = _normalize(name);
    normalizedBarcode = _normalize(barcode);
  }

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll('\u02bb', "'")
        .replaceAll('\u02bc', "'")
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'");
  }

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
    double quantityInBox = 1.0,
    double? boxPrice,
    String? boxBarcode,
  }) => Product(
    id: Uuid().v4(),
    name: name,
    price: price,
    costPrice: costPrice,
    categoryId: categoryId,
    barcode: barcode,
    additionalBarcodes: [],
    additionalBoxBarcodes: [],
    stocks: {},
    imagePath: imagePath,
    unit: unit,
    trackStock: trackStock,
    quantityInBox: quantityInBox,
    boxPrice: boxPrice,
    boxBarcode: boxBarcode,
  );

  Product copyWith({
    String? name,
    double? price,
    double? costPrice,
    String? categoryId,
    String? barcode,
    List<String>? additionalBarcodes,
    List<String>? additionalBoxBarcodes,
    Map<String, double>? stocks,
    String? imagePath,
    bool? isDeleted,
    String? unit,
    bool? trackStock,
    double? quantityInBox,
    double? boxPrice,
    String? boxBarcode,
  }) => Product(
    id: id,
    name: name ?? this.name,
    price: price ?? this.price,
    costPrice: costPrice ?? this.costPrice,
    categoryId: categoryId ?? this.categoryId,
    barcode: barcode ?? this.barcode,
    additionalBarcodes: additionalBarcodes ?? this.additionalBarcodes,
    additionalBoxBarcodes: additionalBoxBarcodes ?? this.additionalBoxBarcodes,
    stocks: stocks ?? this.stocks,
    imagePath: imagePath ?? this.imagePath,
    isDeleted: isDeleted ?? this.isDeleted,
    unit: unit ?? this.unit,
    trackStock: trackStock ?? this.trackStock,
    quantityInBox: quantityInBox ?? this.quantityInBox,
    boxPrice: boxPrice ?? this.boxPrice,
    boxBarcode: boxBarcode ?? this.boxBarcode,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'costPrice': costPrice,
    'categoryId': categoryId,
    'barcode': barcode,
    'additionalBarcodes': additionalBarcodes,
    'additionalBoxBarcodes': additionalBoxBarcodes,
    'imagePath': imagePath,
    'stocks': stocks,
    'isDeleted': isDeleted,
    'unit': unit,
    'trackStock': trackStock,
    'quantityInBox': quantityInBox,
    'boxPrice': boxPrice,
    'boxBarcode': boxBarcode,
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

    var additionalBoxB = json['additionalBoxBarcodes'];
    List<String> boxBarcodes = [];
    if (additionalBoxB != null && additionalBoxB is List) {
      boxBarcodes = additionalBoxB.map((e) => e.toString()).toList();
    }

    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Noma\'lum',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      costPrice: double.tryParse(json['costPrice']?.toString() ?? '0') ?? 0.0,
      categoryId: json['categoryId']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      additionalBarcodes: barcodes,
      additionalBoxBarcodes: boxBarcodes,
      stocks: stocks,
      imagePath: json['imagePath']?.toString(),
      isDeleted: json['isDeleted'] == 1 || json['isDeleted'] == true,
      unit: json['unit']?.toString() ?? 'dona',
      trackStock: json['trackStock'] == 1 || json['trackStock'] == true || json['trackStock'] == null,
      quantityInBox: double.tryParse(json['quantityInBox']?.toString() ?? '1') ?? 1.0,
      boxPrice: double.tryParse(json['boxPrice']?.toString() ?? ''),
      boxBarcode: json['boxBarcode']?.toString(),
    );
  }
}
