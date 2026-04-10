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
