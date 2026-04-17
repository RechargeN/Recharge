import '../../domain/entities/auth_result_entity.dart';
import 'auth_session_model.dart';
import 'auth_user_model.dart';

class AuthResultModel {
  const AuthResultModel({
    required this.session,
    required this.user,
  });

  factory AuthResultModel.fromLoginJson(Map<String, dynamic> json) {
    return AuthResultModel(
      session: AuthSessionModel.fromJson(json),
      user: AuthUserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  final AuthSessionModel session;
  final AuthUserModel user;

  AuthResultEntity toEntity() {
    return AuthResultEntity(
      session: session.toEntity(),
      user: user.toEntity(),
    );
  }
}
