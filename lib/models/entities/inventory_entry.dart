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
