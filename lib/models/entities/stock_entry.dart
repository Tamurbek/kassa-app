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
  final double costPrice; // tannarx at entry
  final double price; // NEW: selling price at entry
  final bool isBox; // NEW: true if added as a full block/box

  StockEntryItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.costPrice = 0.0,
    this.price = 0.0,
    this.isBox = false,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'costPrice': costPrice,
    'price': price,
    'isBox': isBox ? 1 : 0,
  };

  factory StockEntryItem.fromJson(Map<String, dynamic> json) => StockEntryItem(
    productId: json['productId']?.toString() ?? '',
    productName: json['productName']?.toString() ?? 'Noma\'lum',
    quantity: double.tryParse(json['quantity']?.toString() ?? '1') ?? 1.0,
    costPrice: double.tryParse(json['costPrice']?.toString() ?? '0') ?? 0.0,
    price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
    isBox: json['isBox'] == 1 || json['isBox'] == true,
  );
}
