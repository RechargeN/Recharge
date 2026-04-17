import '../entities/auth_result_entity.dart';
import '../entities/auth_user_entity.dart';

class AuthException implements Exception {
  const AuthException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;
}

abstract class AuthRepository {
  Future<AuthResultEntity> signIn({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
    required String appVersion,
  });

  Future<AuthResultEntity?> restoreSession();

  Future<AuthUserEntity?> getCurrentUser();

  Future<void> signOut();
}
