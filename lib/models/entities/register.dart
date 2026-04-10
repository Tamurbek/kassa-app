import 'package:uuid/uuid.dart';

class Register {
  final String id;
  final String name;
  final String warehouseId;
  final String? activeDeviceId;

  Register({
    required this.id,
    required this.name,
    required this.warehouseId,
    this.activeDeviceId,
  });

  factory Register.create(String name, String warehouseId) => Register(
    id: Uuid().v4(),
    name: name,
    warehouseId: warehouseId,
    activeDeviceId: null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'warehouseId': warehouseId,
    'activeDeviceId': activeDeviceId,
  };
  factory Register.fromJson(Map<String, dynamic> json) => Register(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Noma\'lum',
    warehouseId: json['warehouseId']?.toString() ?? '',
    activeDeviceId: json['activeDeviceId']?.toString(),
  );
}
