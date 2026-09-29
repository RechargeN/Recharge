import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/features/create/application/collection_create_config.dart';
import 'package:recharge/features/discover/domain/entities/published_collection_discovery_entity.dart';
import 'package:recharge/features/discover/domain/repositories/collection_item_resolution_repository.dart';
import 'package:recharge/features/discover/domain/repositories/published_collection_discovery_port.dart';
import 'package:recharge/features/discover/presentation/pages/collection_details_page.dart';

/// `docs/product/DTL_CLG_01_COLLECTION_SHELL_MIGRATION_SLICE_SPEC.md` §2:
/// parity (same sections/content before/after the `DetailsShell` move) and
/// the unavailable-item hide policy (CLG-D-AC-05).
void main() {
  setUp(() async {
    await sl.reset();
    // CLG-CRT-01 §15 kill switch: `collectionDiscoverEnabled` gates the
    // same read providers this shell-migration test exercises. Production
    // composition always registers this; this test's manual `sl` bootstrap
    // must too, or every read throws "not registered" instead of exercising
    // the actual DetailsShell rendering this file is about.
    sl.registerSingleton<CollectionCreateRuntimeConfig>(
      const CollectionCreateRuntimeConfig(collectionDiscoverEnabled: true),
    );
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets(
    'renders the same title/description/chips/mini-map/sections order '
    'through DetailsShell',
    (tester) async {
      sl
        ..registerSingleton<PublishedCollectionDiscoveryPort>(
          _FakePort(entity: _entity()),
        )
        ..registerSingleton<CollectionItemResolutionRepository>(
          _FakeResolutionRepository(_readyItems()),
        );

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('RECHARGE'), findsOneWidget);
      expect(find.text('Riga guide'), findsOneWidget);
      expect(find.text('A short guide.'), findsOneWidget);
      expect(find.text('Old Town'), findsOneWidget);
      expect(find.text('low'), findsOneWidget);
      expect(find.text('2 items'), findsOneWidget);
      expect(find.text('By Recharge'), findsOneWidget);
      expect(find.text('Highlights'), findsOneWidget);
      expect(find.text('Cafe'), findsOneWidget);
      expect(find.text('Museum'), findsOneWidget);

      // Section header appears above both of its item cards on screen —
      // the pre-slice order is preserved, not reordered to the parent
      // doc's idealized §8 shape.
      final double sectionY = tester.getTopLeft(find.text('Highlights')).dy;
      final double cafeY = tester.getTopLeft(find.text('Cafe')).dy;
      final double museumY = tester.getTopLeft(find.text('Museum')).dy;
      expect(sectionY, lessThan(cafeY));
      expect(cafeY, lessThan(museumY));

      // Chips/mini-map area appears above the section header — the
      // title/description → chips → mini-map → sections order is intact.
      final double areaChipY = tester.getTopLeft(find.text('Old Town')).dy;
      expect(areaChipY, lessThan(sectionY));
    },
  );

  testWidgets(
    'an unavailable item is hidden, not shown with a status badge',
    (tester) async {
      sl
        ..registerSingleton<PublishedCollectionDiscoveryPort>(
          _FakePort(entity: _entity()),
        )
        ..registerSingleton<CollectionItemResolutionRepository>(
          _FakeResolutionRepository(<String, CollectionResolvedItem>{
            'place:place-1': const CollectionResolvedItem(
              ref: PublishedCollectionItemRef(
                objectId: 'place-1',
                objectType: 'place',
                sectionId: 'sec-1',
                order: 0,
                curatorNote: '',
                highlight: false,
              ),
              status: PublishedCollectionItemStatus.unavailable,
            ),
            // 'event:evt-1' deliberately absent from the resolved map too
            // — the same hidden treatment as an explicit `unavailable`.
          }),
        );

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Cafe'), findsNothing);
      expect(find.text('Museum'), findsNothing);
      expect(find.textContaining('unavailable'), findsNothing);
      expect(find.textContaining('Unavailable'), findsNothing);
      // The section header itself still renders — only the item card is
      // suppressed.
      expect(find.text('Highlights'), findsOneWidget);
    },
  );

  testWidgets('a missing collection renders the shell notFound state', (
    tester,
  ) async {
    sl
      ..registerSingleton<PublishedCollectionDiscoveryPort>(
        _FakePort(entity: null),
      )
      ..registerSingleton<CollectionItemResolutionRepository>(
        _FakeResolutionRepository(const <String, CollectionResolvedItem>{}),
      );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Недоступно'), findsOneWidget);
  });

  testWidgets(
    'no sticky action container is rendered — Collection has no primary CTA',
    (tester) async {
      sl
        ..registerSingleton<PublishedCollectionDiscoveryPort>(
          _FakePort(entity: _entity()),
        )
        ..registerSingleton<CollectionItemResolutionRepository>(
          _FakeResolutionRepository(_readyItems()),
        );

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.bottomNavigationBar, isNull);
    },
  );
}

Widget _app() {
  return const ProviderScope(
    child: MaterialApp(
      home: CollectionDetailsPage(collectionId: 'col-1'),
    ),
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
      PublishedCollectionItemRef(
        objectId: 'evt-1',
        objectType: 'event',
        sectionId: 'sec-1',
        order: 1,
        curatorNote: '',
        highlight: false,
      ),
    ],
    publishedAtUtc: DateTime.utc(2026, 8, 1),
  );
}

Map<String, CollectionResolvedItem> _readyItems() {
  return <String, CollectionResolvedItem>{
    'place:place-1': const CollectionResolvedItem(
      ref: PublishedCollectionItemRef(
        objectId: 'place-1',
        objectType: 'place',
        sectionId: 'sec-1',
        order: 0,
        curatorNote: '',
        highlight: false,
      ),
      status: PublishedCollectionItemStatus.ready,
      card: CollectionResolvedCardProjection(title: 'Cafe'),
    ),
    'event:evt-1': const CollectionResolvedItem(
      ref: PublishedCollectionItemRef(
        objectId: 'evt-1',
        objectType: 'event',
        sectionId: 'sec-1',
        order: 1,
        curatorNote: '',
        highlight: false,
      ),
      status: PublishedCollectionItemStatus.ready,
      card: CollectionResolvedCardProjection(title: 'Museum'),
    ),
  };
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
  _FakeResolutionRepository(this._byKey);

  final Map<String, CollectionResolvedItem> _byKey;

  @override
  Future<Map<String, CollectionResolvedItem>> resolveMany(
    List<PublishedCollectionItemRef> refs,
  ) async {
    return <String, CollectionResolvedItem>{
      for (final PublishedCollectionItemRef ref in refs)
        if (_byKey.containsKey(ref.stableKey)) ref.stableKey: _byKey[ref.stableKey]!,
    };
  }
}
