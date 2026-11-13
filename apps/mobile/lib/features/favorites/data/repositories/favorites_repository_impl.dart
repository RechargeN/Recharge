import '../../domain/entities/favorite_item_entity.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../datasources/favorites_local_datasource.dart';
import '../models/favorite_item_model.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  FavoritesRepositoryImpl({
    required FavoritesLocalDataSource localDataSource,
    required Future<String?> Function() currentOwnerId,
  }) : _localDataSource = localDataSource,
       _currentOwnerId = currentOwnerId;

  final FavoritesLocalDataSource _localDataSource;
  final Future<String?> Function() _currentOwnerId;
  Future<void> _pending = Future<void>.value();

  // Serialize local read/modify/write commands in invocation order.
  Future<void> _enqueue(Future<void> Function() command) {
    final result = _pending.then((_) => command());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<String> _owner() async {
    final owner = await _currentOwnerId();
    if (owner == null || owner.trim().isEmpty) {
      throw StateError('Favorites require an authenticated owner');
    }
    return owner;
  }

  @override
  Future<List<FavoriteItemEntity>> getFavorites() async {
    final owner = await _currentOwnerId();
    if (owner == null || owner.trim().isEmpty) return const [];
    await _pending;
    final List<FavoriteItemModel> items = await _localDataSource.readFavorites(
      owner,
    );
    final List<FavoriteItemEntity> entities = items
        .map((FavoriteItemModel item) => item.toEntity())
        .toList(growable: false);
    entities.sort((FavoriteItemEntity a, FavoriteItemEntity b) {
      final byTime = b.savedAtUtc.compareTo(a.savedAtUtc);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return entities;
  }

  @override
  Future<void> addFavorite(FavoriteItemEntity item) {
    final ownerFuture = _owner();
    ownerFuture.ignore(); // The queued command below still propagates failures.
    return _enqueue(() async {
      final owner = await ownerFuture;
      final List<FavoriteItemModel> current = await _localDataSource
          .readFavorites(owner);
      if (current.any((element) => element.id == item.id)) return;
      final List<FavoriteItemModel> filtered = current
          .where((FavoriteItemModel element) => element.id != item.id)
          .toList(growable: true);
      filtered.insert(
        0,
        FavoriteItemModel.fromEntity(
          item.copyWith(savedAtUtc: DateTime.now().toUtc()),
        ),
      );
      await _localDataSource.writeFavorites(owner, filtered);
    });
  }

  @override
  Future<void> removeFavorite(String itemId) {
    final ownerFuture = _owner();
    ownerFuture.ignore();
    return _enqueue(() async {
      final owner = await ownerFuture;
      final List<FavoriteItemModel> current = await _localDataSource
          .readFavorites(owner);
      final List<FavoriteItemModel> filtered = current
          .where((FavoriteItemModel element) => element.id != itemId)
          .toList(growable: false);
      await _localDataSource.writeFavorites(owner, filtered);
    });
  }
}
