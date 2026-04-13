import 'package:uuid/uuid.dart';

class Organization {
  final String id;
  final String name;
  final String address;
  final String? instagram;
  final bool isDeleted; // This behaves as 'Disabled' as per user request

  Organization({
    required this.id,
    required this.name,
    this.address = '',
    this.instagram,
    this.isDeleted = false,
  });

  factory Organization.create(String name, {String address = '', String? instagram}) =>
      Organization(
        id: const Uuid().v4(),
        name: name,
        address: address,
        instagram: instagram,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'instagram': instagram,
        'isDeleted': isDeleted ? 1 : 0,
      };

  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Noma\'lum Tashkilot',
        address: json['address']?.toString() ?? '',
        instagram: json['instagram']?.toString(),
        isDeleted: json['isDeleted'] == true || json['isDeleted'] == 1,
      );

  Organization copyWith({
    String? name,
    String? address,
    String? instagram,
    bool? isDeleted,
  }) {
    return Organization(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      instagram: instagram ?? this.instagram,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
