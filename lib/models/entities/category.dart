import 'package:uuid/uuid.dart';

class Category {
  final String id;
  final String name;
  final bool isDeleted;

  Category({required this.id, required this.name, this.isDeleted = false});

  factory Category.create(String name) => Category(id: Uuid().v4(), name: name);

  Category copyWith({
    String? name,
    bool? isDeleted,
  }) => Category(
    id: id,
    name: name ?? this.name,
    isDeleted: isDeleted ?? this.isDeleted,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isDeleted': isDeleted,
  };
  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Noma\'lum',
    isDeleted: json['isDeleted'] ?? false,
  );
}
