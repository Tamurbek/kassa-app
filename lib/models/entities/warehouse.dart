import 'package:uuid/uuid.dart';

class Warehouse {
  final String id;
  final String name;
  final bool isMain;
  final bool isDeleted;

  Warehouse({
    required this.id, 
    required this.name, 
    this.isMain = false, 
    this.isDeleted = false
  });

  factory Warehouse.create(String name, {bool isMain = false}) =>
      Warehouse(id: const Uuid().v4(), name: name, isMain: isMain);

  Map<String, dynamic> toJson() => {
    'id': id, 
    'name': name, 
    'isMain': isMain ? 1 : 0, 
    'isDeleted': isDeleted ? 1 : 0
  };

  factory Warehouse.fromJson(Map<String, dynamic> json) => Warehouse(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Noma\'lum',
    isMain: json['isMain'] == true || json['isMain'] == 1,
    isDeleted: json['isDeleted'] == true || json['isDeleted'] == 1,
  );

  Warehouse copyWith({
    String? id,
    String? name,
    bool? isMain,
    bool? isDeleted,
  }) {
    return Warehouse(
      id: id ?? this.id,
      name: name ?? this.name,
      isMain: isMain ?? this.isMain,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
