import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/published_collection_discovery_entity.dart';

/// Persisted local/mock index of active Collection versions
/// (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §14) — same storage shape as
/// `PublishedRouteDiscoveryLocalDataSource`. A corrupt or unreadable record
/// degrades to an empty index rather than crashing Discover.
class PublishedCollectionDiscoveryLocalDataSource {
  PublishedCollectionDiscoveryLocalDataSource(this._storage);

  static const String storageKey = 'recharge.collection.discovery.index.v1';

  final FlutterSecureStorage _storage;

  Future<List<PublishedCollectionDiscoveryEntity>> loadAll() async {
    final String? raw = await _storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <PublishedCollectionDiscoveryEntity>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != 1) {
        return const <PublishedCollectionDiscoveryEntity>[];
      }
      final Object? collections = decoded['collections'];
      if (collections is! List<dynamic>) {
        return const <PublishedCollectionDiscoveryEntity>[];
      }
      return collections
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> map) => _fromMap(
              map.map(
                (Object? key, Object? value) =>
                    MapEntry<String, Object?>(key.toString(), value),
              ),
            ),
          )
          .where((PublishedCollectionDiscoveryEntity c) => c.isCoherent)
          .toList(growable: false);
    } on FormatException {
      return const <PublishedCollectionDiscoveryEntity>[];
    } on TypeError {
      return const <PublishedCollectionDiscoveryEntity>[];
    }
  }

  Future<void> upsert(PublishedCollectionDiscoveryEntity collection) async {
    if (!collection.isCoherent) {
      throw ArgumentError.value(
        collection,
        'collection',
        'Collection index entry is incoherent.',
      );
    }
    final List<PublishedCollectionDiscoveryEntity> current = await loadAll();
    final List<PublishedCollectionDiscoveryEntity> next =
        <PublishedCollectionDiscoveryEntity>[
          for (final PublishedCollectionDiscoveryEntity value in current)
            if (value.collectionId != collection.collectionId) value,
          collection,
        ]..sort(
          (
            PublishedCollectionDiscoveryEntity left,
            PublishedCollectionDiscoveryEntity right,
          ) => left.collectionId.compareTo(right.collectionId),
        );
    await _write(next);
  }

  Future<void> remove(String collectionId) async {
    final List<PublishedCollectionDiscoveryEntity> current = await loadAll();
    final List<PublishedCollectionDiscoveryEntity> next = current
        .where(
          (PublishedCollectionDiscoveryEntity c) =>
              c.collectionId != collectionId,
        )
        .toList(growable: false);
    await _write(next);
  }

  Future<void> clear() => _storage.delete(key: storageKey);

  Future<void> _write(List<PublishedCollectionDiscoveryEntity> collections) {
    return _storage.write(
      key: storageKey,
      value: jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'collections': collections.map(_toMap).toList(growable: false),
      }),
    );
  }

  static Map<String, Object?> _toMap(
    PublishedCollectionDiscoveryEntity value,
  ) => <String, Object?>{
    'collectionId': value.collectionId,
    'versionId': value.versionId,
    'title': value.title,
    'shortDescription': value.shortDescription,
    'publisherName': value.publisherName,
    'marketCityId': value.marketCityId,
    'areaLabel': value.areaLabel,
    'areaId': value.areaId,
    'budgetTier': value.budgetTier,
    'coverImage': value.coverImage,
    'sections': value.sections
        .map(
          (PublishedCollectionSectionRef s) => <String, Object?>{
            'id': s.id,
            'title': s.title,
            'order': s.order,
          },
        )
        .toList(growable: false),
    'items': value.items
        .map(
          (PublishedCollectionItemRef i) => <String, Object?>{
            'objectId': i.objectId,
            'objectType': i.objectType,
            'sectionId': i.sectionId,
            'order': i.order,
            'curatorNote': i.curatorNote,
            'highlight': i.highlight,
          },
        )
        .toList(growable: false),
    'publishedAtUtc': value.publishedAtUtc.toIso8601String(),
  };

  static PublishedCollectionDiscoveryEntity _fromMap(
    Map<String, Object?> map,
  ) {
    final List<dynamic> rawSections =
        map['sections'] as List<dynamic>? ?? <dynamic>[];
    final List<dynamic> rawItems = map['items'] as List<dynamic>? ?? <dynamic>[];
    return PublishedCollectionDiscoveryEntity(
      collectionId: map['collectionId']! as String,
      versionId: map['versionId']! as String,
      title: map['title'] as String? ?? '',
      shortDescription: map['shortDescription'] as String? ?? '',
      publisherName: map['publisherName'] as String? ?? '',
      marketCityId: map['marketCityId'] as String? ?? '',
      areaLabel: map['areaLabel'] as String? ?? '',
      areaId: map['areaId'] as String?,
      budgetTier: map['budgetTier'] as String?,
      coverImage: map['coverImage'] as String? ?? '',
      sections: rawSections
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> s) => PublishedCollectionSectionRef(
              id: s['id']! as String,
              title: s['title'] as String? ?? '',
              order: (s['order'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(growable: false),
      items: rawItems
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> i) => PublishedCollectionItemRef(
              objectId: i['objectId']! as String,
              objectType: i['objectType']! as String,
              sectionId: i['sectionId'] as String?,
              order: (i['order'] as num?)?.toInt() ?? 0,
              curatorNote: i['curatorNote'] as String? ?? '',
              highlight: i['highlight'] as bool? ?? false,
            ),
          )
          .toList(growable: false),
      publishedAtUtc: DateTime.parse(
        map['publishedAtUtc']! as String,
      ).toUtc(),
    );
  }
}
