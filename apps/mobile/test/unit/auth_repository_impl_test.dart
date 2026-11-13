import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/auth/domain/repositories/auth_repository.dart';
import 'package:recharge/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:recharge/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:recharge/features/auth/data/models/auth_session_model.dart';
import 'package:recharge/features/auth/data/models/auth_user_model.dart';
import 'package:recharge/features/auth/data/repositories/auth_repository_impl.dart';

void main() {
  for (final environment in [
    AuthCacheEnvironment.emulator,
    AuthCacheEnvironment.dev,
  ]) {
    test(
      '$environment cannot restore, read or persist mock authority',
      () async {
        final local = _MemoryAuthLocalDataSource(environment: environment);
        final repository = AuthRepositoryImpl(
          remoteDataSource: MockAuthRemoteDataSource(),
          localDataSource: local,
        );
        expect(await repository.restoreSession(), isNull);
        expect(await repository.getCurrentUser(), isNull);
        await expectLater(
          repository.signIn(
            email: 'user@example.com',
            password: 'password123',
            deviceName: 'test',
            platform: 'android',
            appVersion: '1',
          ),
          throwsA(isA<AuthException>()),
        );
        expect(await local.readSession(), isNull);
        expect(await local.readUser(), isNull);
      },
    );
  }

  test(
    'secure cache keys isolate Local, Emulator and exact dev project',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const storage = FlutterSecureStorage();
      final local = AuthLocalDataSource(storage);
      final repository = AuthRepositoryImpl(
        remoteDataSource: MockAuthRemoteDataSource(),
        localDataSource: local,
      );
      await repository.restoreSession();
      for (final environment in [
        AuthCacheEnvironment.emulator,
        AuthCacheEnvironment.dev,
      ]) {
        final isolated = AuthLocalDataSource(storage, environment: environment);
        expect(await isolated.readSession(), isNull);
        expect(await isolated.readUser(), isNull);
        await isolated.clear();
      }
      expect(await local.readSession(), isNotNull);
      expect(await local.readUser(), isNotNull);
    },
  );

  test(
    'restoreSession creates demo full-access session without cache',
    () async {
      final localDataSource = _MemoryAuthLocalDataSource();
      final repository = AuthRepositoryImpl(
        remoteDataSource: MockAuthRemoteDataSource(),
        localDataSource: localDataSource,
      );

      final result = await repository.restoreSession();

      expect(result, isNotNull);
      expect(result!.user.id, MockAuthRemoteDataSource.demoUserId);
      expect(result.user.role, 'admin');
      expect(result.user.capabilities, contains('create.event'));
      expect(result.user.capabilities, contains('scenario.generate'));
      expect(result.user.capabilities, contains('admin.tools.view'));
      expect(await localDataSource.readSession(), isNotNull);
      expect(await localDataSource.readUser(), isNotNull);
    },
  );
}

class _MemoryAuthLocalDataSource extends AuthLocalDataSource {
  _MemoryAuthLocalDataSource({
    AuthCacheEnvironment environment = AuthCacheEnvironment.local,
  }) : super(const FlutterSecureStorage(), environment: environment);

  AuthSessionModel? _session;
  AuthUserModel? _user;

  @override
  Future<void> saveSession(AuthSessionModel session) async {
    _session = session;
  }

  @override
  Future<AuthSessionModel?> readSession() async => _session;

  @override
  Future<void> saveUser(AuthUserModel user) async {
    _user = user;
  }

  @override
  Future<AuthUserModel?> readUser() async => _user;

  @override
  Future<void> clear() async {
    _session = null;
    _user = null;
  }
}
