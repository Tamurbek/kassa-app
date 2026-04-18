import 'package:uuid/uuid.dart';

class Register {
  final String id;
  final String name;
  final String warehouseId;
  final String? activeDeviceId;
  final bool isDeleted;

  Register({
    required this.id,
    required this.name,
    required this.warehouseId,
    this.activeDeviceId,
    this.isDeleted = false,
  });

  factory Register.create(String name, String warehouseId) => Register(
    id: const Uuid().v4(),
    name: name,
    warehouseId: warehouseId,
    activeDeviceId: null,
    isDeleted: false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'warehouseId': warehouseId,
    'activeDeviceId': activeDeviceId,
    'isDeleted': isDeleted ? 1 : 0,
  };

  factory Register.fromJson(Map<String, dynamic> json) => Register(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Noma\'lum',
    warehouseId: json['warehouseId']?.toString() ?? '',
    activeDeviceId: json['activeDeviceId']?.toString(),
    isDeleted: json['isDeleted'] == true || json['isDeleted'] == 1,
  );

  Register copyWith({
    String? id,
    String? name,
    String? warehouseId,
    String? activeDeviceId,
    bool? isDeleted,
  }) {
    return Register(
      id: id ?? this.id,
      name: name ?? this.name,
      warehouseId: warehouseId ?? this.warehouseId,
      activeDeviceId: activeDeviceId ?? this.activeDeviceId,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
