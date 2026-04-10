class SaleReturn {
  final String id;
  final String saleId;
  final DateTime date;
  final List<SaleReturnItem> items;
  final double totalAmount;
  final String warehouseId;

  SaleReturn({
    required this.id,
    required this.saleId,
    required this.date,
    required this.items,
    required this.totalAmount,
    required this.warehouseId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'saleId': saleId,
    'date': date.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
    'total': totalAmount,
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
    totalAmount: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
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
