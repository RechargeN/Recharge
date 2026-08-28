import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/application/collection_discover_providers.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/features/create/application/collection_create_config.dart';
import 'package:recharge/features/discover/domain/entities/published_collection_discovery_entity.dart';
import 'package:recharge/features/discover/domain/repositories/collection_item_resolution_repository.dart';
import 'package:recharge/features/discover/domain/repositories/published_collection_discovery_port.dart';

/// Review finding: every other test of the three CLG-CRT-01 kill switches
/// explicitly overrides `CollectionCreateRuntimeConfig`, so none of them
/// actually exercises the *real* default the app ships with. This file
/// registers `const CollectionCreateRuntimeConfig()` — the exact literal
/// `service_locator.dart` registers, not a test-chosen override — so a
/// silent flip of that default would fail here even if every other
/// Collection test still passed.
void main() {
  setUp(() async {
    await sl.reset();
  });

  tearDown(() async {
    await sl.reset();
  });

  test(
    'CollectionCreateRuntimeConfig defaults ship with authoring on, '
    'publishing and Discover off',
    () {
      const CollectionCreateRuntimeConfig config = CollectionCreateRuntimeConfig();
      expect(config.collectionCreateEnabled, isTrue);
      expect(config.collectionPublishingEnabled, isFalse);
      expect(config.collectionDiscoverEnabled, isFalse);
    },
  );

  test(
    'with the real default config, an active Collection in the port is '
    'still invisible through activeCollectionsProvider/collectionByIdProvider',
    () async {
      // The exact same literal service_locator.dart registers — not an
      // override chosen to make this test pass.
      sl
        ..registerSingleton<CollectionCreateRuntimeConfig>(
          const CollectionCreateRuntimeConfig(),
        )
        ..registerSingleton<PublishedCollectionDiscoveryPort>(
          _FakePort(entity: _entity()),
        )
        ..registerSingleton<CollectionItemResolutionRepository>(
          _FakeResolutionRepository(),
        );

      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final List<PublishedCollectionDiscoveryEntity> feed = await container
          .read(activeCollectionsProvider.future);
      final PublishedCollectionDiscoveryEntity? single = await container.read(
        collectionByIdProvider('col-1').future,
      );

      expect(feed, isEmpty);
      expect(single, isNull);
    },
  );

  test(
    'flipping collectionDiscoverEnabled to true (still via CollectionCreateRuntimeConfig, '
    'not an ad-hoc override) makes the same active Collection visible',
    () async {
      sl
        ..registerSingleton<CollectionCreateRuntimeConfig>(
          const CollectionCreateRuntimeConfig(collectionDiscoverEnabled: true),
        )
        ..registerSingleton<PublishedCollectionDiscoveryPort>(
          _FakePort(entity: _entity()),
        )
        ..registerSingleton<CollectionItemResolutionRepository>(
          _FakeResolutionRepository(),
        );

      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final List<PublishedCollectionDiscoveryEntity> feed = await container
          .read(activeCollectionsProvider.future);

      expect(feed, hasLength(1));
      expect(feed.single.collectionId, 'col-1');
    },
  );
}

PublishedCollectionDiscoveryEntity _entity() {
  return PublishedCollectionDiscoveryEntity(
    collectionId: 'col-1',
    versionId: 'v1',
    title: 'Riga guide',
    shortDescription: 'A short guide.',
    publisherName: 'Recharge',
    marketCityId: 'riga',
    areaLabel: 'Old Town',
    budgetTier: 'low',
    coverImage: '',
    sections: const <PublishedCollectionSectionRef>[
      PublishedCollectionSectionRef(id: 'sec-1', title: 'Highlights', order: 0),
    ],
    items: const <PublishedCollectionItemRef>[
      PublishedCollectionItemRef(
        objectId: 'place-1',
        objectType: 'place',
        sectionId: 'sec-1',
        order: 0,
        curatorNote: '',
        highlight: false,
      ),
    ],
    publishedAtUtc: DateTime.utc(2026, 8, 1),
  );
}

class _FakePort implements PublishedCollectionDiscoveryPort {
  _FakePort({required this.entity});

  final PublishedCollectionDiscoveryEntity? entity;

  @override
  Future<PublishedCollectionDiscoveryEntity?> getActiveCollection(
    String collectionId,
  ) async => entity;

  @override
  Future<List<PublishedCollectionDiscoveryEntity>> loadActiveCollections() async {
    return entity == null
        ? const <PublishedCollectionDiscoveryEntity>[]
        : <PublishedCollectionDiscoveryEntity>[entity!];
  }
}

class _FakeResolutionRepository implements CollectionItemResolutionRepository {
  @override
  Future<Map<String, CollectionResolvedItem>> resolveMany(
    List<PublishedCollectionItemRef> refs,
  ) async => const <String, CollectionResolvedItem>{};
}
