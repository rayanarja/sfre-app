class UserModel {
  final int id;
  final String username;
  final String email;
  final String? phone;
  final String role;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.phone,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      phone: json['phone'],
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone': phone,
      'role': role,
    };
  }

  bool get isAdmin => role == 'admin';
  bool get isDriver => role == 'driver';
  bool get isPassenger => role == 'passenger';
}