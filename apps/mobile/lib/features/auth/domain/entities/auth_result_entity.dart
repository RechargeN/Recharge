import 'auth_session_entity.dart';
import 'auth_user_entity.dart';

class AuthResultEntity {
  const AuthResultEntity({
    required this.session,
    required this.user,
  });

  final AuthSessionEntity session;
  final AuthUserEntity user;
}
