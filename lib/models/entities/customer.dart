class Customer {
  final String id;
  final String name;
  final String? phone;
  final double debt;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.debt = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'debt': debt,
  };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Noma\'lum',
    phone: json['phone'],
    debt: double.tryParse(json['debt']?.toString() ?? '0') ?? 0.0,
  );
}
