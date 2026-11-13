import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/favorites/data/datasources/favorites_local_datasource.dart';
import 'package:recharge/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:recharge/features/favorites/domain/entities/favorite_item_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String? owner;
  late FavoritesRepositoryImpl repository;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'favorites_items_v1': '[{"id":"unowned"}]',
    });
    owner = 'user:1';
    repository = FavoritesRepositoryImpl(
      localDataSource: FavoritesLocalDataSource(
        const FlutterSecureStorage(),
        defaultCurrencyCode: 'EUR',
      ),
      currentOwnerId: () async => owner,
    );
  });

  test('legacy data is not adopted; exact owners stay isolated', () async {
    expect(await repository.getFavorites(), isEmpty);
    await repository.addFavorite(_item('one'));
    owner = 'user_1';
    expect(await repository.getFavorites(), isEmpty);
    await repository.addFavorite(_item('two'));
    owner = 'user:1';
    expect((await repository.getFavorites()).single.id, 'one');
    owner = null;
    expect(await repository.getFavorites(), isEmpty);
    await expectLater(
      repository.addFavorite(_item('denied')),
      throwsStateError,
    );
  });

  test(
    'concurrent commands retain items and duplicate add preserves date',
    () async {
      await Future.wait([
        repository.addFavorite(_item('one')),
        repository.addFavorite(_item('two')),
      ]);
      final before = await repository.getFavorites();
      expect(before.length, 2);
      await repository.addFavorite(_item('one'));
      final after = await repository.getFavorites();
      expect(
        after.firstWhere((e) => e.id == 'one').savedAtUtc,
        before.firstWhere((e) => e.id == 'one').savedAtUtc,
      );
      await repository.removeFavorite('one');
      await repository.removeFavorite('one');
      expect((await repository.getFavorites()).single.id, 'two');
    },
  );
}

FavoriteItemEntity _item(String id) => FavoriteItemEntity(
  id: id,
  title: id,
  subtitle: '',
  city: 'Riga',
  category: 'place',
  startsAtUtc: null,
  distanceKm: 0,
  priceAmount: null,
  isFree: true,
  savedAtUtc: DateTime.utc(2026),
  targetRoute: null,
);
