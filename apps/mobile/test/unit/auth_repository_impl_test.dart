import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:recharge/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:recharge/features/auth/data/models/auth_session_model.dart';
import 'package:recharge/features/auth/data/models/auth_user_model.dart';
import 'package:recharge/features/auth/data/repositories/auth_repository_impl.dart';

void main() {
  test('restoreSession creates demo full-access session without cache', () async {
    final localDataSource = _MemoryAuthLocalDataSource();
    final repository = AuthRepositoryImpl(
      remoteDataSource: MockAuthRemoteDataSource(),
      localDataSource: localDataSource,
    );

    final result = await repository.restoreSession();

    expect(result, isNotNull);
    expect(result!.user.id, MockAuthRemoteDataSource.demoUserId);
    expect(result.user.role, 'creator');
    expect(result.user.capabilities, contains('create.event'));
    expect(result.user.capabilities, contains('scenario.generate'));
    expect(await localDataSource.readSession(), isNotNull);
    expect(await localDataSource.readUser(), isNotNull);
  });
}

class _MemoryAuthLocalDataSource extends AuthLocalDataSource {
  _MemoryAuthLocalDataSource() : super(const FlutterSecureStorage());

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
