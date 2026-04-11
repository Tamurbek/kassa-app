class Sale {
  final String id;
  final DateTime date;
  final List<SaleItem> items;
  final double total;
  final String registerId;
  final String warehouseId;
  final double discount;
  final String? customerId;
  final String? customerName;

  Sale({
    required this.id,
    required this.date,
    required this.items,
    required this.total,
    required this.registerId,
    required this.warehouseId,
    this.discount = 0.0,
    this.customerId,
    this.customerName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
    'total': total,
    'registerId': registerId,
    'warehouseId': warehouseId,
    'discount': discount,
    'customerId': customerId,
    'customerName': customerName,
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
    discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0.0,
    customerId: json['customerId'],
    customerName: json['customerName'],
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
