import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../shared/primitives/time/utc_instant.dart';
import '../../shared/primitives/time/local_date.dart';
import '../../features/favorites/data/datasources/favorites_local_datasource.dart';
import '../../features/favorites/data/models/favorite_item_model.dart';
import '../../features/favorites/domain/entities/favorite_item_entity.dart';
import '../../features/favorites/domain/repositories/favorites_repository.dart';
import '../../features/visited/domain/entities/visited_place_entity.dart';
import '../../features/visited/domain/repositories/visited_places_repository.dart';
import '../../features/library/data/library_sync_client.dart';

Map<String, Object?> _snapshot(Map<String, Object?> entry) =>
    Map<String, Object?>.from(entry['snapshot']! as Map);

/// App-level mapping keeps Library, Favorites and Visit History feature boundaries separate.
final class ServerFavoritesRepository implements FavoritesRepository {
  const ServerFavoritesRepository(
    this.client, {
    this.savedCopy,
    this.currentOwnerId,
  });
  final LibrarySyncClient client;
  final FavoritesLocalDataSource? savedCopy;
  final Future<String?> Function()? currentOwnerId;

  /// Failures that say nothing about the list. `unauthenticated` is one of
  /// them: a cold start without a network has no armed token yet, and an
  /// ended sign-in has no kept owner to read a copy for.
  static bool _noAnswer(Object error) => switch (error) {
    LibraryFailure(:final code) => const <String>{
      'unavailable',
      'deadline-exceeded',
      'unauthenticated',
    }.contains(code),
    FirebaseAuthException(:final code) => code == 'network-request-failed',
    SocketException() => true,
    _ => false,
  };

  @override
  Future<List<FavoriteItemEntity>> getFavorites() async {
    try {
      await client.refresh();
    } catch (error) {
      if (!_noAnswer(error)) rethrow;
      final owner = await currentOwnerId?.call();
      final copy = savedCopy;
      if (owner == null || copy == null || !await copy.hasFavorites(owner)) {
        rethrow;
      }
      final saved = await copy.readFavorites(owner);
      return saved.map((item) => item.toEntity()).toList(growable: false);
    }
    final items = _serverFavorites();
    final owner = client.ownerId;
    if (owner != null) {
      try {
        await savedCopy?.writeFavorites(
          owner,
          items.map(FavoriteItemModel.fromEntity).toList(growable: false),
        );
      } on Exception catch (error) {
        debugPrint('recharge-favorites: copy not saved ${error.runtimeType}');
      }
    }
    return items;
  }

  List<FavoriteItemEntity> _serverFavorites() {
    final result = client.entries.where((e) => e['kind'] == 'favorite').map((
      e,
    ) {
      final snapshot = _snapshot(e);
      return FavoriteItemEntity(
        id: e['objectId']! as String,
        objectType: e['objectType']! as String,
        title: snapshot['title']! as String,
        subtitle: '',
        city: snapshot['city']! as String,
        category: snapshot['category']! as String,
        startsAtUtc: null,
        distanceKm: null,
        priceAmount: null,
        isFree: false,
        savedAtUtc: UtcInstant.parse(e['updatedAtUtc']! as String).value,
        targetRoute: null,
      );
    }).toList();
    result.sort((a, b) {
      final time = b.savedAtUtc.compareTo(a.savedAtUtc);
      return time != 0 ? time : a.id.compareTo(b.id);
    });
    return result;
  }

  @override
  Future<void> addFavorite(FavoriteItemEntity item) {
    if (item.objectType == null || item.planningTargetKind != null) {
      throw const LibraryFailure('public_object_reference_required');
    }
    return client.mutate(
      action: 'addFavorite',
      objectType: item.objectType!,
      objectId: item.id,
    );
  }

  @override
  Future<void> removeFavorite(String itemId) async {
    await client.refresh();
    final matches = client.entries.where(
      (e) => e['kind'] == 'favorite' && e['objectId'] == itemId,
    );
    if (matches.isEmpty) return;
    await client.mutate(
      action: 'removeFavorite',
      objectType: matches.first['objectType']! as String,
      objectId: itemId,
    );
  }
}

final class ServerVisitedPlacesRepository implements VisitedPlacesRepository {
  const ServerVisitedPlacesRepository(this.client);
  final LibrarySyncClient client;

  VisitedPlaceEntity _entity(Map<String, Object?> e, String localUserId) {
    final snapshot = _snapshot(e);
    return VisitedPlaceEntity(
      id: e['entryId']! as String,
      userId: localUserId,
      placeId: e['objectId']! as String,
      title: snapshot['title']! as String,
      subtitle: '',
      city: snapshot['city']! as String,
      category: snapshot['category']! as String,
      visitedOn: _localCalendar(e['visitedOn']! as String),
      timezoneId: e['timezoneId']! as String,
      evidence: VisitEvidence.selfReported,
      recordedAtUtc: UtcInstant.parse(e['updatedAtUtc']! as String).value,
    );
  }

  @override
  Future<List<VisitedPlaceEntity>> getVisitedPlaces({
    required String userId,
  }) async {
    await client.refresh();
    final result = client.entries
        .where((e) => e['kind'] == 'visit')
        .map((e) => _entity(e, userId))
        .toList();
    result.sort((a, b) {
      final day = b.localDayKey.compareTo(a.localDayKey);
      return day != 0 ? day : a.id.compareTo(b.id);
    });
    return result;
  }

  @override
  Future<VisitedPlaceEntity> recordVisit(VisitedPlaceEntity visit) async {
    if (visit.evidence != VisitEvidence.selfReported) {
      throw const LibraryFailure('explicit_self_report_required');
    }
    await client.mutate(
      action: 'recordVisit',
      objectType: 'place',
      objectId: visit.placeId,
      visitedOn: visit.localDayKey,
    );
    return _entity(
      client.entries.singleWhere(
        (e) =>
            e['kind'] == 'visit' &&
            e['objectId'] == visit.placeId &&
            e['visitedOn'] == visit.localDayKey,
      ),
      visit.userId,
    );
  }

  @override
  Future<void> removeVisit({
    required String userId,
    required String visitId,
  }) async {
    await client.refresh();
    final matches = client.entries.where(
      (e) => e['kind'] == 'visit' && e['entryId'] == visitId,
    );
    if (matches.isEmpty) return;
    final entry = matches.first;
    await client.mutate(
      action: 'removeVisit',
      objectType: 'place',
      objectId: entry['objectId']! as String,
      visitedOn: entry['visitedOn']! as String,
    );
  }
}

// Legacy Visit API exposes DateTime; the stored contract is a local date.
DateTime _localCalendar(String text) {
  final date = LocalDate.parse(text);
  return DateTime(date.year, date.month, date.day);
}
