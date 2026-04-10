import 'package:uuid/uuid.dart';

class Warehouse {
  final String id;
  final String name;
  final bool isMain;

  Warehouse({required this.id, required this.name, this.isMain = false});

  factory Warehouse.create(String name, {bool isMain = false}) =>
      Warehouse(id: Uuid().v4(), name: name, isMain: isMain);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'isMain': isMain};
  factory Warehouse.fromJson(Map<String, dynamic> json) => Warehouse(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Noma\'lum',
    isMain: json['isMain'] == true || json['isMain'] == 1,
  );
}
