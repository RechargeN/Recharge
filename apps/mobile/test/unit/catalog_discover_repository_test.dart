import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/datasources/catalog_query_port.dart';
import 'package:recharge/features/discover/data/repositories/catalog_discover_repository.dart';
import 'package:recharge/features/discover/data/repositories/catalog_published_event_discovery.dart';
import 'package:recharge/features/discover/data/repositories/catalog_snapshot_session.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/event_occurrence.dart';
import 'package:recharge/features/discover/domain/entities/published_event_discovery_entity.dart';
import 'package:recharge/features/discover/domain/repositories/discover_repository.dart';
import 'package:recharge/shared/primitives/money/money.dart';

/// Answers each `queryType` with the next scripted response and records every
/// request exactly as sent.
final class _ScriptedPort implements CatalogQueryPort {
  _ScriptedPort(this.answers);

  final List<Object> answers;
  final List<Map<String, Object?>> requests = <Map<String, Object?>>[];

  @override
  Future<Map<String, Object?>> query(Map<String, Object?> request) async {
    requests.add(request);
    final Object next = answers.removeAt(0);
    if (next is CatalogTransportFailure) throw next;
    return next as Map<String, Object?>;
  }
}

Map<String, Object?> _card(String id, String revision, {bool pinned = true}) =>
    <String, Object?>{
      'ref': <String, Object?>{'typeId': 'event', 'contentId': id},
      'publishedRevisionId': revision,
      'title': 'Title $id',
      'shortDescription': 'Short $id',
      'categoryId': 'workshops_masterclasses',
      'subcategoryId': 'pottery',
      'format': 'offline',
      'city': 'Riga',
      'venueName': null,
      'point': pinned
          ? const <String, Object?>{'latitude': 56.95, 'longitude': 24.1}
          : null,
      'notMappable': null,
      'timezoneId': 'Europe/Riga',
      'occurrence': <String, Object?>{
        'id': 'occ-$id',
        'startAtUtc': '2035-10-10T15:00:00.000Z',
        'endAtUtc': '2035-10-10T17:00:00.000Z',
        'state': 'upcoming',
      },
      'remainingOccurrences': 1,
      'price': const <String, Object?>{'mode': 'free'},
      'coverMediaId': null,
      'distanceMeters': 1500,
      'availability': const <String, Object?>{'status': 'not_connected'},
      'changedSinceSnapshot': false,
      'projectedAtUtc': '2035-01-01T00:00:00.000Z',
    };

Map<String, Object?> _page(
  List<Map<String, Object?>> items, {
  String? cursor,
}) => <String, Object?>{
  'schemaVersion': 1,
  'queryType': 'feed',
  'requestId': 'r',
  'kind': 'succeeded',
  'page': <String, Object?>{
    'snapshotToken': 'snap-1',
    'projectionSetId': 'set-1',
    'projectionSetRevision': 3,
    'freshness': const <String, Object?>{'overall': 'fresh'},
    'items': items,
    'nextCursor': cursor,
    'totalEligible': items.length,
  },
};

Map<String, Object?> _item(String id, String revision) => <String, Object?>{
  'schemaRevision': 'catalog-event-projection-v2',
  'typeId': 'event',
  'contentId': id,
  'publishedRevisionId': revision,
  'publisherRef': const <String, Object?>{'type': 'page', 'id': 'page-1'},
  'title': 'Title $id',
  'shortDescription': 'Short $id',
  'fullDescription': 'Full description of $id',
  'categoryId': 'workshops_masterclasses',
  'subcategoryId': 'pottery',
  'city': 'Riga',
  'venueName': 'Studio',
  'point': const <String, Object?>{'latitude': 56.95, 'longitude': 24.1},
  'timezoneId': 'Europe/Riga',
  'scheduleMode': 'oneTime',
  'occurrences': <Object?>[
    <String, Object?>{
      'id': 'occ-$id',
      'startAtUtc': '2035-10-10T15:00:00.000Z',
      'endAtUtc': '2035-10-10T17:00:00.000Z',
    },
  ],
  'price': const <String, Object?>{
    'mode': 'fixed',
    'amountMinor': 1250,
    'currencyCode': 'EUR',
  },
  'publishedAtUtc': '2035-01-01T00:00:00.000Z',
};

Map<String, Object?> _details(
  String state, {
  Map<String, Object?>? item,
  bool changed = false,
}) => <String, Object?>{
  'schemaVersion': 1,
  'queryType': 'details',
  'requestId': 'r',
  'kind': 'succeeded',
  'details': <String, Object?>{
    'state': state,
    'reason': state == 'listed' ? null : 'withdrawn',
    'item': item,
    'changedSinceSnapshot': changed,
  },
};

DiscoverQuery _query({String text = ''}) => DiscoverQuery.defaults(
  centerLat: 56.95,
  centerLng: 24.1,
  nowUtc: DateTime.utc(2035),
).copyWith(queryText: text);

void main() {
  test(
    'Activity reads Catalog facts without Event price/time and honors local kill switch',
    () async {
      final Map<String, Object?> activity = <String, Object?>{
        'schemaRevision': 'catalog-activity-projection-v1',
        'typeId': 'activity',
        'ref': <String, Object?>{'typeId': 'activity', 'contentId': 'a'},
        'contentId': 'a',
        'publishedRevisionId': 'r',
        'title': 'Forest walk',
        'shortDescription': 'A quiet walk along the forest trail',
        'categoryId': 'outdoor_nature_walking',
        'subcategoryId': 'forest_walk',
        'point': <String, Object?>{'latitude': 56.95, 'longitude': 24.1},
        'typicalDurationMinutes': <String, Object?>{'min': 60, 'max': 120},
        'bestTime': <String, Object?>{'timeOfDay': 'morning', 'season': 'any'},
        'galleryMediaIds': <String>[],
        'referenceRevisions': <String, Object?>{
          'taxonomyRevisionId':
              'taxonomy-1.4.3-sha256:d5d4472629d52b8f3db883d9a449bcbfd5fa18e5f87a6d6aa26ae5b98168c822',
        },
      };
      final _ScriptedPort port = _ScriptedPort(<Object>[
        _page(<Map<String, Object?>>[activity]),
        <String, Object?>{
          'schemaVersion': 1,
          'kind': 'succeeded',
          'details': <String, Object?>{
            'state': 'listed',
            'reason': null,
            'item': activity,
            'changedSinceSnapshot': false,
          },
        },
      ]);
      final CatalogDiscoverRepository repo = CatalogDiscoverRepository(
        port: port,
        session: CatalogSnapshotSession(),
        marketId: 'LV',
        currencyCode: 'EUR',
        activityEnabled: true,
      );
      final DiscoverItemEntity card = (await repo.getFeed(
        DiscoverQuery.defaults(centerLat: 56.95, centerLng: 24.1),
      )).single;
      expect(card.objectKind, DiscoverObjectKind.activity);
      expect(card.startsAtUtc, isNull);
      expect(card.priceAmount, isNull);
      expect(card.isFree, isFalse);
      expect(card.activityCatalog!.durationMaxMinutes, 120);
      expect(
        (await repo.getDetails('a')).activityCatalog!.timeOfDay,
        'morning',
      );
      final changed = CatalogDiscoverRepository(
        port: _ScriptedPort(<Object>[
          <String, Object?>{
            'schemaVersion': 1,
            'kind': 'succeeded',
            'details': <String, Object?>{
              'state': 'listed',
              'reason': null,
              'item': activity,
              'changedSinceSnapshot': true,
            },
          },
        ]),
        session: CatalogSnapshotSession()
          ..remember('snap', <String, Object?>{}),
        marketId: 'LV',
        currencyCode: 'EUR',
        activityEnabled: true,
      );
      await expectLater(
        changed.getDetails('a'),
        throwsA(
          isA<DiscoverException>().having(
            (e) => e.code,
            'code',
            'CATALOG_REVISION_CHANGED',
          ),
        ),
      );
      final CatalogDiscoverRepository disabled = CatalogDiscoverRepository(
        port: _ScriptedPort(<Object>[
          _page(<Map<String, Object?>>[activity]),
        ]),
        session: CatalogSnapshotSession(),
        marketId: 'LV',
        currencyCode: 'EUR',
      );
      await expectLater(
        disabled.getFeed(
          DiscoverQuery.defaults(centerLat: 56.95, centerLng: 24.1),
        ),
        throwsA(isA<DiscoverException>()),
      );
    },
  );

  test(
    'a listing reads every page on the first snapshot and keeps it',
    () async {
      final _ScriptedPort port = _ScriptedPort(<Object>[
        _page(<Map<String, Object?>>[_card('a', 'ra')], cursor: 'cur-1'),
        _page(<Map<String, Object?>>[_card('b', 'rb', pinned: false)]),
      ]);
      final CatalogSnapshotSession session = CatalogSnapshotSession();
      final CatalogDiscoverRepository repository = CatalogDiscoverRepository(
        port: port,
        session: session,
        marketId: 'LV',
        currencyCode: 'EUR',
        newRequestId: () => 'req',
      );
      final List<DiscoverItemEntity> items = await repository.getFeed(_query());
      expect(items.map((DiscoverItemEntity item) => item.id), <String>[
        'a',
        'b',
      ]);
      expect(items.first.revisionRef, 'ra');
      expect(items.first.objectKind, DiscoverObjectKind.event);
      expect(items.first.distanceKm, 1.5);
      expect(items.first.isFree, isTrue);
      expect(items.first.priceAmount, Money.zero('EUR'));
      expect(items.last.latitude.isNaN, isTrue, reason: 'no fake coordinate');
      final Map<String, Object?> second = port.requests[1];
      expect(second['queryType'], 'feed');
      expect(second['payload'], containsPair('snapshotToken', 'snap-1'));
      expect(second['payload'], containsPair('cursor', 'cur-1'));
      expect(session.snapshotToken, 'snap-1');
      expect(session.query, (port.requests.first['payload']! as Map)['query']);
    },
  );

  test(
    'text makes it a literal Search; Booking availability is never faked',
    () async {
      final _ScriptedPort port = _ScriptedPort(<Object>[
        _page(const <Map<String, Object?>>[]),
      ]);
      await CatalogDiscoverRepository(
        port: port,
        session: CatalogSnapshotSession(),
        marketId: 'LV',
        currencyCode: 'EUR',
      ).getFeed(_query(text: '  clay  ').copyWith(onlyAvailable: true));
      final Map<String, Object?> request = port.requests.single;
      expect(request['queryType'], 'search');
      final Map<String, Object?> wire =
          (request['payload']! as Map<String, Object?>)['query']!
              as Map<String, Object?>;
      expect(wire['literalText'], 'clay');
      expect(wire['onlyAvailable'], isTrue);
      expect(wire['typeIds'], <String>['event']);
      expect(wire['geo'], <String, Object?>{
        'center': <String, Object?>{'latitude': 56.95, 'longitude': 24.1},
        'radiusKm': 5.0,
      });
    },
  );

  test('a filter the Catalog cannot apply is refused by name', () {
    expect(
      () => catalogWireQuery(
        _query().copyWith(
          peopleCount: 2,
          budgetMin: const Money(minorUnits: 100, currencyCode: 'EUR'),
        ),
        marketId: 'LV',
      ),
      throwsA(
        isA<DiscoverException>().having(
          (DiscoverException error) => error.code,
          'code',
          'CATALOG_FILTER_UNSUPPORTED:budgetMin,peopleCount',
        ),
      ),
    );
  });

  test('a typed server refusal and a lost answer stay typed', () async {
    Future<String> codeOf(Object answer) async {
      try {
        await CatalogDiscoverRepository(
          port: _ScriptedPort(<Object>[answer]),
          session: CatalogSnapshotSession(),
          marketId: 'LV',
          currencyCode: 'EUR',
        ).getFeed(_query());
      } on DiscoverException catch (error) {
        return error.code;
      }
      return 'no error';
    }

    expect(
      await codeOf(const <String, Object?>{
        'schemaVersion': 1,
        'kind': 'unsupported',
        'code': 'market_disabled',
      }),
      'CATALOG_UNSUPPORTED:market_disabled',
    );
    expect(
      await codeOf(const CatalogTransportFailure('unknown_outcome')),
      'CATALOG_TRANSPORT_unknown_outcome',
    );
    expect(
      await codeOf(const <String, Object?>{
        'schemaVersion': 1,
        'kind': 'succeeded',
      }),
      'CATALOG_CONTRACT_INVALID',
    );
  });

  test(
    'Details reads the listed revision against the listing snapshot',
    () async {
      final CatalogSnapshotSession session = CatalogSnapshotSession()
        ..remember('snap-1', const <String, Object?>{'schemaVersion': 1});
      final _ScriptedPort port = _ScriptedPort(<Object>[
        _details('listed', item: _item('a', 'ra')),
      ]);
      final PublishedEventDiscoveryEntity? event =
          await CatalogPublishedEventDiscovery(
            port: port,
            session: session,
            currencyCode: 'EUR',
            nowUtc: () => DateTime.utc(2035),
          ).getActiveEvent('a');
      expect(port.requests.single['payload'], <String, Object?>{
        'contentId': 'a',
        'snapshotToken': 'snap-1',
        'query': const <String, Object?>{'schemaVersion': 1},
      });
      expect(event, isNotNull);
      expect(event!.revisionRef, 'ra');
      expect(event.changedSinceListing, isFalse);
      expect(event.fullDescription, 'Full description of a');
      expect(event.priceAmount, 12.5);
      expect(event.isFree, isFalse);
      expect(event.scheduleMode, EventScheduleMode.oneTime);
      expect(event.displayOccurrenceId, 'occ-a');
    },
  );

  test(
    'a changed or unconfirmable revision is marked; hidden content is null',
    () async {
      final CatalogSnapshotSession session = CatalogSnapshotSession()
        ..remember('snap-1', const <String, Object?>{'schemaVersion': 1});
      CatalogPublishedEventDiscovery details(_ScriptedPort port) =>
          CatalogPublishedEventDiscovery(
            port: port,
            session: session,
            currencyCode: 'EUR',
            nowUtc: () => DateTime.utc(2035),
          );

      final PublishedEventDiscoveryEntity? changed = await details(
        _ScriptedPort(<Object>[
          _details('listed', item: _item('a', 'ra-2'), changed: true),
        ]),
      ).getActiveEvent('a');
      expect(changed!.changedSinceListing, isTrue);

      final _ScriptedPort stalePort = _ScriptedPort(<Object>[
        const <String, Object?>{
          'schemaVersion': 1,
          'kind': 'stale',
          'code': 'snapshot_expired',
        },
        _details('listed', item: _item('a', 'ra-3')),
      ]);
      final PublishedEventDiscoveryEntity? stale = await details(
        stalePort,
      ).getActiveEvent('a');
      expect(stale!.changedSinceListing, isTrue, reason: 'cannot confirm');
      expect(stalePort.requests.last['payload'], <String, Object?>{
        'contentId': 'a',
      });

      final PublishedEventDiscoveryEntity? hidden = await details(
        _ScriptedPort(<Object>[_details('excluded', changed: true)]),
      ).getActiveEvent('a');
      expect(hidden, isNull);
    },
  );
}
