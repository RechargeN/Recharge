import '../../domain/entities/auth_result_entity.dart';
import '../../domain/entities/auth_user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_result_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  @override
  Future<AuthResultEntity> signIn({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
    required String appVersion,
  }) async {
    try {
      final result = await _remoteDataSource.login(
        email: email,
        password: password,
        deviceName: deviceName,
        platform: platform,
        appVersion: appVersion,
      );
      await _persistResult(result);
      return result.toEntity();
    } on AuthRemoteException catch (e) {
      throw AuthException(code: e.code, message: e.message);
    }
  }

  @override
  Future<AuthResultEntity?> restoreSession() async {
    final cachedSession = await _localDataSource.readSession();
    if (cachedSession == null) {
      return null;
    }

    try {
      final refreshedSession = await _remoteDataSource.refresh(
        refreshToken: cachedSession.refreshToken,
        sessionId: cachedSession.sessionId,
      );
      final user = await _remoteDataSource.me(
        accessToken: refreshedSession.accessToken,
      );
      final result = AuthResultModel(session: refreshedSession, user: user);
      await _persistResult(result);
      return result.toEntity();
    } on AuthRemoteException catch (e) {
      await _localDataSource.clear();
      throw AuthException(code: e.code, message: e.message);
    }
  }

  @override
  Future<AuthUserEntity?> getCurrentUser() async {
    final user = await _localDataSource.readUser();
    return user?.toEntity();
  }

  @override
  Future<void> signOut() async {
    final cachedSession = await _localDataSource.readSession();
    if (cachedSession != null) {
      try {
        await _remoteDataSource.logout(sessionId: cachedSession.sessionId);
      } on AuthRemoteException {
        // Offline/local logout policy: local cleanup is still success.
      }
    }
    await _localDataSource.clear();
  }

  Future<void> _persistResult(AuthResultModel result) async {
    await _localDataSource.saveSession(result.session);
    await _localDataSource.saveUser(result.user);
  }
}
