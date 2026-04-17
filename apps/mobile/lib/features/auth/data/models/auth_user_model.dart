import '../../domain/entities/auth_user_entity.dart';

class AuthUserModel {
  const AuthUserModel({
    required this.id,
    required this.email,
    required this.role,
    required this.capabilities,
    required this.profileStatus,
  });

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      capabilities: List<String>.from(json['capabilities'] as List<dynamic>),
      profileStatus: json['profile_status'] as String? ?? 'active',
    );
  }

  final String id;
  final String email;
  final String role;
  final List<String> capabilities;
  final String profileStatus;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'role': role,
      'capabilities': capabilities,
      'profile_status': profileStatus,
    };
  }

  AuthUserEntity toEntity() {
    return AuthUserEntity(
      id: id,
      email: email,
      role: role,
      capabilities: capabilities,
      profileStatus: profileStatus,
    );
  }
}
