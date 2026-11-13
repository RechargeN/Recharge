import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/datasources/catalog_query_port.dart';
import 'package:recharge/features/discover/data/repositories/catalog_discover_repository.dart';
import 'package:recharge/features/discover/data/repositories/catalog_published_find_people_discovery.dart';
import 'package:recharge/features/discover/data/repositories/catalog_snapshot_session.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/published_find_people_discovery_entity.dart';
import 'package:recharge/features/discover/domain/repositories/discover_repository.dart';

/// D3.7: the mobile Catalog/Map adapters show exactly the server's public
/// projection (the ~1 km cell centre) and refuse any private meeting field.
final class _ScriptedPort implements CatalogQueryPort {
  _ScriptedPort(this.answers);

  final List<Map<String, Object?>> answers;
  final List<Map<String, Object?>> requests = <Map<String, Object?>>[];

  @override
  Future<Map<String, Object?>> query(Map<String, Object?> request) async {
    requests.add(request);
    return answers.removeAt(0);
  }
}

const Map<String, Object?> _cell = <String, Object?>{
  'latitude': 56.94951,
  'longitude': 24.08419,
};

Map<String, Object?> _card({
  Map<String, Object?> extra = const {},
}) => <String, Object?>{
  'ref': <String, Object?>{'typeId': 'find_people', 'contentId': 'fp-1'},
  'publishedRevisionId': 'rev-1',
  'title': 'Morning run along the Daugava',
  'shortDescription': 'Easy 8 km jog at a relaxed pace, all levels welcome.',
  'categoryId': 'sport',
  'subcategoryId': 'running',
  'publicAreaLabel': 'Ķīpsala, Riga',
  'point': _cell,
  'publicGeoPrecisionMeters': 1000,
  'timezoneId': 'Europe/Riga',
  'occurrence': <String, Object?>{
    'id': 'slot-1',
    'startAtUtc': '2027-05-15T06:00:00.000Z',
    'endAtUtc': '2027-05-15T07:30:00.000Z',
    'state': 'upcoming',
  },
  'applicationDeadlineUtc': '2027-05-14T18:00:00.000Z',
  'skillLevel': 'beginner',
  'languageCodes': <String>['en', 'lv'],
  'targetGroupSize': 6,
  'costType': 'free',
  'expectedSpend': null,
  'distanceMeters': 900,
  'changedSinceSnapshot': false,
  'projectedAtUtc': '2026-10-19T10:00:00.000Z',
  ...extra,
};

Map<String, Object?> _feed(List<Map<String, Object?>> items) =>
    <String, Object?>{
      'schemaVersion': 1,
      'queryType': 'feed',
      'requestId': 'r',
      'kind': 'succeeded',
      'page': <String, Object?>{
        'snapshotToken': 'snap-1',
        'projectionSetId': 'set-1',
        'projectionSetRevision': 1,
        'items': items,
        'nextCursor': null,
        'totalEligible': items.length,
      },
    };

Map<String, Object?> _details(Map<String, Object?>? item) => <String, Object?>{
  'schemaVersion': 1,
  'queryType': 'details',
  'requestId': 'r',
  'kind': 'succeeded',
  'details': <String, Object?>{
    'state': item == null ? 'absent' : 'listed',
    'reason': null,
    'item': item,
    'changedSinceSnapshot': false,
  },
};

Map<String, Object?> _item({
  Map<String, Object?> extra = const {},
}) => <String, Object?>{
  'schemaRevision': 'catalog-find-people-projection-v1',
  'typeId': 'find_people',
  'contentId': 'fp-1',
  'publishedRevisionId': 'rev-1',
  'sourcePointerRevision': 1,
  'marketId': 'LV',
  'publisherRef': <String, Object?>{'type': 'user', 'id': 'user-1'},
  'hostUserId': 'user-1',
  'title': 'Morning run along the Daugava',
  'shortDescription': 'Easy 8 km jog at a relaxed pace, all levels welcome.',
  'fullDescription': 'We meet by the river and run an easy loop together.',
  'categoryId': 'sport',
  'subcategoryId': 'running',
  'tags': <String>['running'],
  'publicAreaLabel': 'Ķīpsala, Riga',
  'point': _cell,
  'publicGeoPrecisionMeters': 1000,
  'timezoneId': 'Europe/Riga',
  'occurrences': <Map<String, Object?>>[
    <String, Object?>{
      'id': 'slot-1',
      'startAtUtc': '2027-05-15T06:00:00.000Z',
      'endAtUtc': '2027-05-15T07:30:00.000Z',
    },
  ],
  'applicationDeadlineUtc': '2027-05-14T18:00:00.000Z',
  'skillLevel': 'beginner',
  'languageCodes': <String>['en', 'lv'],
  'participationGoal': 'social',
  'targetGroupSize': 6,
  'hostSeatCount': 1,
  'approvalMode': 'manual',
  'verificationRequirement': 'none',
  'costType': 'free',
  'expectedSpend': null,
  'coverMediaId': null,
  'referenceRevisions': <String, Object?>{},
  'publishedAtUtc': '2026-10-19T10:00:00.000Z',
  'searchText': 'morning run',
  ...extra,
};

CatalogDiscoverRepository _repository(
  _ScriptedPort port, {
  bool findPeopleEnabled = true,
}) => CatalogDiscoverRepository(
  port: port,
  session: CatalogSnapshotSession(),
  marketId: 'LV',
  currencyCode: 'EUR',
  findPeopleEnabled: findPeopleEnabled,
  newRequestId: () => 'request-1',
);

DiscoverQuery _query() => DiscoverQuery.defaults(
  centerLat: 56.95,
  centerLng: 24.1,
  nowUtc: DateTime.utc(2027),
);

void main() {
  test(
    'Feed and Map get the server cell centre as the MapObject point',
    () async {
      final _ScriptedPort port = _ScriptedPort(<Map<String, Object?>>[
        _feed(<Map<String, Object?>>[_card()]),
      ]);
      final List<DiscoverItemEntity> items = await _repository(
        port,
      ).getFeed(_query());
      final DiscoverItemEntity item = items.single;
      expect(item.objectKind, DiscoverObjectKind.findPeople);
      expect(item.catalogObjectType.name, 'findPeople');
      expect(item.latitude, 56.94951);
      expect(item.longitude, 24.08419);
      expect(item.venueName, 'Ķīpsala, Riga');
      final Map<String, Object?> query =
          (port.requests.single['payload']! as Map<String, Object?>)['query']!
              as Map<String, Object?>;
      expect(query['typeIds'], <String>['event', 'find_people']);
    },
  );

  test('without its own define the type is neither asked nor shown', () async {
    final _ScriptedPort port = _ScriptedPort(<Map<String, Object?>>[
      _feed(<Map<String, Object?>>[]),
    ]);
    await _repository(port, findPeopleEnabled: false).getFeed(_query());
    final Map<String, Object?> query =
        (port.requests.single['payload']! as Map<String, Object?>)['query']!
            as Map<String, Object?>;
    expect(query['typeIds'], <String>['event']);
    final _ScriptedPort leaked = _ScriptedPort(<Map<String, Object?>>[
      _feed(<Map<String, Object?>>[_card()]),
    ]);
    await expectLater(
      _repository(leaked, findPeopleEnabled: false).getFeed(_query()),
      throwsA(
        isA<DiscoverException>().having(
          (DiscoverException e) => e.code,
          'code',
          'CATALOG_FIND_PEOPLE_DISABLED',
        ),
      ),
    );
  });

  test(
    'an answer with any private meeting field is refused, never shown',
    () async {
      for (final Map<String, Object?> extra in <Map<String, Object?>>[
        <String, Object?>{
          'exact': <String, Object?>{
            'latitude': 56.95182,
            'longitude': 24.08571,
          },
        },
        <String, Object?>{'addressLine': 'Ķīpsalas iela 6, Riga'},
        <String, Object?>{'placeName': 'Ķīpsala riverside steps'},
        <String, Object?>{'instructions': 'By the blue bench.'},
      ]) {
        final _ScriptedPort port = _ScriptedPort(<Map<String, Object?>>[
          _feed(<Map<String, Object?>>[_card(extra: extra)]),
        ]);
        await expectLater(
          _repository(port).getFeed(_query()),
          throwsA(
            isA<DiscoverException>().having(
              (DiscoverException e) => e.code,
              'code',
              'CATALOG_CONTRACT_INVALID',
            ),
          ),
        );
      }
    },
  );

  test(
    'Details maps the public projection; hidden requests are null',
    () async {
      final _ScriptedPort port = _ScriptedPort(<Map<String, Object?>>[
        _details(_item()),
        _details(null),
      ]);
      final CatalogPublishedFindPeopleDiscovery details =
          CatalogPublishedFindPeopleDiscovery(
            port: port,
            session: CatalogSnapshotSession(),
            newRequestId: () => 'request-1',
          );
      final PublishedFindPeopleDiscoveryEntity? entity = await details
          .getActiveFindPeopleRequest('fp-1');
      expect(entity, isNotNull);
      final PublishedFindPeoplePublicLocation location = entity!.publicLocation;
      expect(location, isA<PublishedFindPeoplePointLocation>());
      location as PublishedFindPeoplePointLocation;
      expect(location.latitude, 56.94951);
      expect(location.longitude, 24.08419);
      expect(location.areaLabel, 'Ķīpsala, Riga');
      expect(entity.timeOptions.single.id, 'slot-1');
      expect(await details.getActiveFindPeopleRequest('fp-1'), isNull);
      await expectLater(
        CatalogPublishedFindPeopleDiscovery(
          port: _ScriptedPort(<Map<String, Object?>>[
            _details(
              _item(
                extra: <String, Object?>{
                  'exact': <String, Object?>{'latitude': 56.95182},
                },
              ),
            ),
          ]),
          session: CatalogSnapshotSession(),
        ).getActiveFindPeopleRequest('fp-1'),
        throwsA(isA<DiscoverException>()),
      );
    },
  );
}
