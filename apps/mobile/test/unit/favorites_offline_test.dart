import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/saved_owner.dart';
import 'package:recharge/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:recharge/features/auth/domain/entities/auth_result_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_user_entity.dart';
import 'package:recharge/features/auth/domain/repositories/auth_repository.dart';
import 'package:recharge/features/favorites/data/datasources/favorites_local_datasource.dart';
import 'package:recharge/features/favorites/data/models/favorite_item_model.dart';
import 'package:recharge/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:recharge/features/favorites/domain/entities/favorite_item_entity.dart';

// The owner's example of 2026-11-20: on the metro, without a network, the
// user opens Saved and sees what was saved on this phone.

const _storage = FlutterSecureStorage();
const _user = AuthUserEntity(
  id: 'alice',
  email: 'alice@example.test',
  role: 'user',
  capabilities: <String>[],
  profileStatus: 'active',
);

class _Auth implements AuthRepository {
  int reads = 0;
  Object? failure;

  @override
  Future<AuthUserEntity?> getCurrentUser() async {
    reads++;
    if (failure != null) throw failure!;
    return _user;
  }

  @override
  Future<AuthResultEntity?> restoreSession() async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthResultEntity> signIn({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
    required String appVersion,
  }) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('opens without a network and asks no server who the owner is', () async {
    const account = AuthLocalDataSource(_storage);
    await account.saveOfflineProfile(_user);
    final local = FavoritesLocalDataSource(_storage, legacyCurrencyCode: 'EUR');
    await local.writeFavorites('alice', <FavoriteItemModel>[
      FavoriteItemModel.fromEntity(
        FavoriteItemEntity(
          id: 'kept',
          objectType: 'event',
          title: 'Saved',
          subtitle: '',
          city: 'Riga',
          category: 'culture',
          startsAtUtc: null,
          distanceKm: null,
          priceAmount: null,
          isFree: false,
          savedAtUtc: DateTime.utc(2026, 11, 20),
          targetRoute: null,
        ),
      ),
    ]);
    final auth = _Auth()
      ..failure = const AuthException(code: 'NETWORK_UNAVAILABLE', message: '');
    final repository = FavoritesRepositoryImpl(
      localDataSource: local,
      currentOwnerId: () =>
          savedOwnerId(serverAuth: true, auth: auth, account: account),
    );

    expect((await repository.getFavorites()).single.id, 'kept');
    expect(auth.reads, 0);
  });

  test('without a kept profile there is no owner', () async {
    final owner = await savedOwnerId(
      serverAuth: true,
      auth: _Auth(),
      account: const AuthLocalDataSource(_storage),
    );
    expect(owner, isNull);
  });

  test('the local mock composition still asks its own repository', () async {
    final owner = await savedOwnerId(
      serverAuth: false,
      auth: _Auth(),
      account: const AuthLocalDataSource(_storage),
    );
    expect(owner, 'alice');
  });
}
