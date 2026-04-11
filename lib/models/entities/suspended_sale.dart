import 'sale.dart';

class SuspendedSale {
  final String id;
  final DateTime date;
  final List<SaleItem> items;
  final double total;
  final String? note;

  SuspendedSale({
    required this.id,
    required this.date,
    required this.items,
    required this.total,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
    'total': total,
    'note': note,
  };

  factory SuspendedSale.fromJson(Map<String, dynamic> json) => SuspendedSale(
    id: json['id']?.toString() ?? '',
    date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    items: (json['items'] as List?)?.map((i) => SaleItem.fromJson(i)).toList() ?? [],
    total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
    note: json['note']?.toString(),
  );
}
