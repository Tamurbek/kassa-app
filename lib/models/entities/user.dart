enum UserRole { admin, seller }

class User {
  final String id;
  final String name;
  final String pin;
  final UserRole role;
  final bool isDeleted;

  User({
    required this.id,
    required this.name,
    required this.pin,
    required this.role,
    this.isDeleted = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pin': pin,
    'role': role.index,
    'isDeleted': isDeleted,
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Noma\'lum',
    pin: json['pin']?.toString() ?? '',
    role: UserRole.values[(json['role'] ?? 1) as int],
    isDeleted: json['isDeleted'] == 1 || json['isDeleted'] == true,
  );
}
