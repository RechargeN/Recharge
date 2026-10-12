import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/repositories/catalog_collection_catalog_search_repository.dart';
import 'package:recharge/features/create/domain/entities/collection_content_publication.dart';
import 'package:recharge/features/create/domain/entities/collection_item_draft.dart';
import 'package:recharge/features/create/domain/repositories/collection_catalog_search_repository.dart';

/// D3.4 §2.3, §5.1: the Create item picker over the server Catalog. Each
/// allowed item type is asked as its own listing type; only allowlisted public
/// facts are read; any failure or contract violation is an empty page or
/// `unavailable`, never mock data.
void main() {
  final DateTime now = DateTime.utc(2026, 10, 12, 9);

  Map<String, Object?> object(
    String contentId,
    String typeId, {
    String title = 'Quiet garden',
    String marketId = 'LV',
  }) => <String, Object?>{
    'typeId': typeId,
    'contentId': contentId,
    'publishedRevisionId': '$contentId-r1',
    'pointerRevision': 1,
    'marketId': marketId,
    'title': title,
  };

  CatalogCollectionCatalogSearchRepository repository(
    Map<String, Object?> Function(Map<String, Object?> request) answer, {
    List<Map<String, Object?>>? requests,
  }) => CatalogCollectionCatalogSearchRepository(
    query: (Map<String, Object?> request) async {
      requests?.add(request);
      return answer(request);
    },
    marketId: 'LV',
    clock: () => now,
  );

  Map<String, Object?> ok(String type, Object? value) => <String, Object?>{
    'schemaVersion': 1,
    'kind': 'succeeded',
    type: value,
  };

  test(
    'search asks every allowed type as its listing type and skips excluded refs',
    () async {
      final List<Map<String, Object?>> requests = <Map<String, Object?>>[];
      final CatalogCollectionCatalogSearchRepository picker = repository((
        Map<String, Object?> request,
      ) {
        final Map<String, Object?> payload =
            request['payload']! as Map<String, Object?>;
        final String typeId = payload['typeId']! as String;
        return ok('publishedObjectCandidates', <String, Object?>{
          'status': 'available',
          'items': <Object?>[
            object('$typeId-1', typeId),
            object('$typeId-2', typeId),
          ],
          'nextCursor': null,
        });
      }, requests: requests);
      final List<CollectionCatalogSearchResult> results = await picker.search(
        CollectionCatalogSearchQuery(
          text: 'quiet',
          allowedTypes: <CollectionCatalogObjectType>{
            CollectionCatalogObjectType.rental,
            CollectionCatalogObjectType.place,
            CollectionCatalogObjectType.bookableSession,
          },
          marketCityId: 'riga',
          excludeRefs: <CollectionObjectRef>{
            const CollectionObjectRef(
              objectId: 'place-2',
              objectType: CollectionCatalogObjectType.place,
            ),
          },
        ),
      );
      expect(
        requests
            .map((Map<String, Object?> request) => request['queryType'])
            .toSet(),
        <String>{'publishedObjectCandidates'},
      );
      expect(
        requests
            .map(
              (Map<String, Object?> request) =>
                  (request['payload']! as Map<String, Object?>)['typeId'],
            )
            .toList(),
        <String>['place', 'session', 'rental'],
      );
      expect(
        results.map(
          (CollectionCatalogSearchResult result) => result.ref.stableKey,
        ),
        <String>[
          'place:place-1',
          'bookableSession:session-1',
          'bookableSession:session-2',
          'rental:rental-1',
          'rental:rental-2',
        ],
      );
      expect(results.first.snapshot.title, 'Quiet garden');
      expect(results.first.snapshot.checkedAtUtc, now);
    },
  );

  test(
    'an unavailable page or a contract violation yields no result for that type',
    () async {
      final CatalogCollectionCatalogSearchRepository picker = repository((
        Map<String, Object?> request,
      ) {
        final String typeId =
            (request['payload']! as Map<String, Object?>)['typeId']! as String;
        return switch (typeId) {
          'place' => ok('publishedObjectCandidates', <String, Object?>{
            'status': 'unavailable',
          }),
          'route' => ok('publishedObjectCandidates', <String, Object?>{
            'status': 'available',
            'items': <Object?>[
              object('wrong-type', 'place'),
              object('other-market', 'route', marketId: 'EE'),
              object('route-ok', 'route'),
            ],
            'nextCursor': null,
          }),
          _ => <String, Object?>{'schemaVersion': 1, 'kind': 'rejected'},
        };
      });
      final List<CollectionCatalogSearchResult> results = await picker.search(
        CollectionCatalogSearchQuery(
          text: '',
          allowedTypes: CollectionCatalogObjectType.values.toSet(),
          marketCityId: 'riga',
        ),
      );
      expect(
        results.map(
          (CollectionCatalogSearchResult result) => result.ref.stableKey,
        ),
        <String>['route:route-ok'],
      );
    },
  );

  test('search follows candidate pages within its bound', () async {
    final List<Map<String, Object?>> requests = <Map<String, Object?>>[];
    final CatalogCollectionCatalogSearchRepository picker = repository((
      Map<String, Object?> request,
    ) {
      final Map<String, Object?> payload =
          request['payload']! as Map<String, Object?>;
      final String? after = payload['after'] as String?;
      // Page 1 holds no match; page 2 holds one; every page has a next cursor.
      return ok('publishedObjectCandidates', <String, Object?>{
        'status': 'available',
        'items': after == 'cursor-1'
            ? <Object?>[object('place-late', 'place')]
            : const <Object?>[],
        'nextCursor': 'cursor-${(requests.length)}',
      });
    }, requests: requests);
    final List<CollectionCatalogSearchResult> results = await picker.search(
      const CollectionCatalogSearchQuery(
        text: '',
        allowedTypes: <CollectionCatalogObjectType>{
          CollectionCatalogObjectType.place,
        },
        marketCityId: 'riga',
      ),
    );
    expect(
      results.map(
        (CollectionCatalogSearchResult result) => result.ref.objectId,
      ),
      <String>['place-late'],
    );
    expect(
      requests,
      hasLength(CatalogCollectionCatalogSearchRepository.maxPages),
    );
    expect(
      (requests[1]['payload']! as Map<String, Object?>)['after'],
      'cursor-1',
    );
    expect(
      (requests.first['payload']! as Map<String, Object?>)['limit'],
      CatalogCollectionCatalogSearchRepository.pageSize,
    );
  });

  test(
    'statusOf maps the evaluator answer exactly; resolve keeps only eligible objects',
    () async {
      final Map<String, Object?> answers = <String, Object?>{
        'eligible-1': <String, Object?>{
          'status': 'eligible',
          'object': object('eligible-1', 'place', title: 'Kronvalda'),
        },
        'hidden': <String, Object?>{'status': 'withheld'},
        'nobody': <String, Object?>{'status': 'unknown'},
        'event': <String, Object?>{'status': 'forbidden'},
        'odd': <String, Object?>{'status': 'mystery'},
        'mismatch': <String, Object?>{
          'status': 'eligible',
          'object': object('someone-else', 'place'),
        },
      };
      final CatalogCollectionCatalogSearchRepository picker = repository((
        Map<String, Object?> request,
      ) {
        final String id =
            (request['payload']! as Map<String, Object?>)['contentId']!
                as String;
        if (id == 'down') throw StateError('transport');
        return ok('publishedObject', answers[id]);
      });
      CollectionObjectRef place(String id) => CollectionObjectRef(
        objectId: id,
        objectType: CollectionCatalogObjectType.place,
      );
      final Map<String, String> statuses = <String, String>{
        for (final String id in <String>[
          'eligible-1',
          'hidden',
          'nobody',
          'event',
          'odd',
          'mismatch',
          'down',
        ])
          id: (await picker.statusOf(place(id))).status,
      };
      expect(statuses, <String, String>{
        'eligible-1': 'eligible',
        'hidden': 'withheld',
        'nobody': 'unknown',
        'event': 'forbidden',
        'odd': 'unavailable',
        'mismatch': 'unavailable',
        'down': 'unavailable',
      });
      final CollectionMemberStatus eligible = await picker.statusOf(
        place('eligible-1'),
      );
      expect(eligible.title, 'Kronvalda');
      final Map<String, CollectionCatalogSearchResult> resolved = await picker
          .resolve(<CollectionObjectRef>[place('eligible-1'), place('hidden')]);
      expect(resolved.keys, <String>['place:eligible-1']);
      expect(resolved['place:eligible-1']!.snapshot.title, 'Kronvalda');
    },
  );
}
