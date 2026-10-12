class UserModel {
  final int? id;
  final String username;
  final String password;
  final String role; // 'admin' or 'user'
  final String? fullName;
  final bool forcePasswordChange;

  UserModel({
    this.id,
    required this.username,
    required this.password,
    required this.role,
    this.fullName,
    this.forcePasswordChange = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'role': role,
      'full_name': fullName,
      'force_password_change': forcePasswordChange ? 1 : 0,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      username: map['username'],
      password: map['password'],
      role: map['role'],
      fullName: map['full_name'],
      forcePasswordChange: map['force_password_change'] == 1,
    );
  }

  UserModel copyWith({
    int? id,
    String? username,
    String? password,
    String? role,
    String? fullName,
    bool? forcePasswordChange,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      forcePasswordChange: forcePasswordChange ?? this.forcePasswordChange,
    );
  }
}
