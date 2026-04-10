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
