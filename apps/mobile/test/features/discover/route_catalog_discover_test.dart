import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:recharge/features/discover/data/datasources/catalog_query_port.dart';
import 'package:recharge/features/discover/data/models/catalog_wire_models.dart';
import 'package:recharge/features/discover/data/repositories/catalog_discover_repository.dart';
import 'package:recharge/features/discover/data/repositories/catalog_snapshot_session.dart';
import 'package:recharge/features/discover/data/repositories/discover_item_details_lookup.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/route_catalog_facts.dart';
import 'package:recharge/features/discover/domain/repositories/discover_repository.dart';
import 'package:recharge/features/discover/domain/usecases/get_discover_details_usecase.dart';
import 'package:recharge/features/discover/presentation/renderers/route_details_renderer.dart';
import 'package:recharge/features/discover/presentation/shell/details_shell.dart';
import 'package:recharge/features/discover/presentation/widgets/route_catalog_labels.dart';
import 'package:recharge/features/discover/presentation/widgets/route_segment_polylines.dart';
import 'package:recharge/shared/models/catalog_object_ref.dart';
import 'package:recharge/shared/primitives/geo/geo_point.dart';
import 'package:recharge/shared/primitives/geo/geometry_encoding.dart';

import '../../widget/widget_test_viewport.dart';
import 'package:recharge/core/localization/l10n_context.dart';

/// DTL-RTE-02 (`docs/product/discover/DTL_RTE_02_ROUTE_CATALOG_DISCOVER_SLICE_SPEC.md`):
/// a published J2 Route read from the server Catalog, shown in Discover and
/// Details without invented metrics, joined gaps or private fields.
const GeometryEncodingPolicy _e7 = GeometryEncodingPolicy(precision: 7);

String _line(int from, int count, {double lat = 56.95}) =>
    GeometryEncoding.encode(
      List<GeoPoint>.generate(
        count,
        (int i) =>
            GeoPoint(latitude: lat, longitude: 24.1 + (from + i) * 0.001),
      ),
      policy: _e7,
    );

/// A backend `catalog-route-projection-v1` answer: two parts with a gap, the
/// second ending in a direct segment, a Page publisher and no elevation.
Map<String, Object?> _projection({
  bool card = true,
  String publisher = 'page',
  double? ascent,
  Map<String, Object?> extra = const <String, Object?>{},
}) => <String, Object?>{
  'schemaRevision': 'catalog-route-projection-v1',
  'typeId': 'route',
  'contentId': 'route-1',
  'publishedRevisionId': 'rev-1',
  'sourcePointerRevision': 1,
  'marketId': 'LV',
  'publisherRef': <String, Object?>{'type': publisher, 'id': 'publisher-1'},
  'title': 'Riverside walk',
  'shortDescription': 'A calm riverside walk',
  'fullDescription': 'A calm riverside walk with a gap at the bridge.',
  'categoryId': 'art_culture_museums',
  'subcategoryId': 'art_walk',
  'shape': 'oneWay',
  'profileId': 'walking',
  'summary': <String, Object?>{
    'distanceMeters': 2345.6,
    'ascentMeters': ascent,
    'descentMeters': null,
    'minElevationMeters': null,
    'maxElevationMeters': null,
    'segmentCount': 3,
    'gapCount': 1,
  },
  'directSegmentCount': 1,
  'point': const <String, Object?>{'latitude': 56.95, 'longitude': 24.1},
  'notMappable': null,
  'preview': <String, Object?>{
    'policy': 'route-preview-dp-v1',
    'segments': <Object?>[
      <String, Object?>{'polyline': _line(0, 5), 'connected': false},
      <String, Object?>{'polyline': _line(10, 4), 'connected': false},
      <String, Object?>{'polyline': _line(13, 2), 'connected': true},
    ],
  },
  if (!card)
    'track': <String, Object?>{
      'segments': <Object?>[
        <String, Object?>{
          'sourceKind': 'importedGpx',
          'polyline': _line(0, 9),
          'elevation': null,
          'connected': false,
        },
        <String, Object?>{
          'sourceKind': 'freehand',
          'polyline': _line(10, 4),
          'elevation': null,
          'connected': false,
        },
        <String, Object?>{
          'sourceKind': 'intentionalDirect',
          'polyline': _line(13, 2),
          'elevation': null,
          'connected': true,
        },
      ],
      'waypoints': <Object?>[
        <String, Object?>{
          'typeId': 'viewpoint',
          'title': 'Bridge view',
          'safetyNote': 'Slippery after rain',
          'latE7': 569_500_000,
          'lonE7': 241_050_000,
          'eleDm': null,
          'distanceFromStartMeters': 450.2,
        },
      ],
    },
  'coverMediaId': null,
  'referenceRevisions': const <String, Object?>{},
  'publishedAtUtc': '2035-01-01T00:00:00.000Z',
  'searchText': 'riverside walk',
  ...extra,
};

Map<String, Object?> _card() => <String, Object?>{
  ..._projection(),
  'ref': const <String, Object?>{'typeId': 'route', 'contentId': 'route-1'},
  'distanceMeters': 1200,
  'changedSinceSnapshot': false,
  'projectedAtUtc': '2035-01-01T00:00:00.000Z',
}..remove('contentId');

Map<String, Object?> _feed(List<Object?> items) => <String, Object?>{
  'schemaVersion': 1,
  'kind': 'succeeded',
  'page': <String, Object?>{
    'snapshotToken': 'snap-1',
    'projectionSetId': 'set-1',
    'projectionSetRevision': 3,
    'freshness': const <String, Object?>{'overall': 'fresh'},
    'items': items,
    'nextCursor': null,
    'totalEligible': items.length,
  },
};

Map<String, Object?> _details(
  String state, {
  Map<String, Object?>? item,
  bool changed = false,
}) => <String, Object?>{
  'schemaVersion': 1,
  'kind': 'succeeded',
  'details': <String, Object?>{
    'state': state,
    'reason': state == 'listed' ? null : 'withdrawn',
    'item': item,
    'changedSinceSnapshot': changed,
  },
};

final class _Port implements CatalogQueryPort {
  _Port(this.answers);
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

DiscoverQuery _query({String text = ''}) => DiscoverQuery.defaults(
  centerLat: 56.95,
  centerLng: 24.1,
  nowUtc: DateTime.utc(2035),
).copyWith(queryText: text);

CatalogDiscoverRepository _repository(
  _Port port, {
  CatalogSnapshotSession? session,
  bool routeEnabled = true,
}) => CatalogDiscoverRepository(
  port: port,
  session: session ?? CatalogSnapshotSession(),
  marketId: 'LV',
  currencyCode: 'EUR',
  routeEnabled: routeEnabled,
);

void main() {
  group('wire (RD-01, RD-10)', () {
    test('a card keeps segments and gaps, a Page publisher and no metrics', () {
      final CatalogCard card = CatalogCard.fromWire(_card());
      final RouteCatalogFacts facts = card.route!.facts;
      expect(card.contentId, 'route-1');
      expect(facts.publisherKind, RouteCatalogPublisherKind.page);
      expect(facts.preview.map((RouteCatalogSegment s) => s.connected), <bool>[
        false,
        false,
        true,
      ]);
      expect(facts.preview.first.points, hasLength(5));
      expect(facts.ascentMeters, isNull);
      expect(facts.track, isNull);
      expect(facts.gapCount, 1);
      expect(facts.directSegmentCount, 1);
    });

    test('Details carry the full track with direct segments and waypoints', () {
      final CatalogDetails details = CatalogDetails.fromWire(
        _details('listed', item: _projection(card: false))['details'],
      );
      final RouteCatalogFacts facts = details.route!.facts;
      expect(facts.track!.map((RouteCatalogSegment s) => s.direct), <bool>[
        false,
        false,
        true,
      ]);
      expect(facts.waypoints!.single.title, 'Bridge view');
      expect(facts.waypoints!.single.safetyNote, 'Slippery after rain');
    });

    test(
      'owner-only fields, a track on a card or a big preview are refused',
      () {
        for (final String field in <String>[
          'anchors',
          'privacyTrim',
          'provenance',
          'bounds',
          'durationSeconds',
        ]) {
          expect(
            () => CatalogRouteItem.fromWire(
              _projection(extra: <String, Object?>{field: <Object?>[]}),
              card: true,
            ),
            throwsFormatException,
            reason: field,
          );
        }
        expect(
          () => CatalogRouteItem.fromWire(_projection(card: false), card: true),
          throwsFormatException,
        );
        final Map<String, Object?> withNote = _projection(card: false);
        ((withNote['track']! as Map)['waypoints'] as List)
            .add(<String, Object?>{
              'typeId': 'x',
              'title': null,
              'safetyNote': null,
              'note': 'PRIVATE-note',
              'latE7': 1,
              'lonE7': 1,
              'eleDm': null,
              'distanceFromStartMeters': 1,
            });
        expect(
          () => CatalogRouteItem.fromWire(withNote, card: false),
          throwsFormatException,
        );
        final Map<String, Object?> big = _projection(
          extra: <String, Object?>{
            'preview': <String, Object?>{
              'policy': 'route-preview-dp-v1',
              'segments': <Object?>[
                <String, Object?>{
                  'polyline': _line(0, 257),
                  'connected': false,
                },
              ],
            },
          },
        );
        expect(
          () => CatalogRouteItem.fromWire(big, card: true),
          throwsFormatException,
        );
      },
    );
  });

  group('repository (RD-05, RD-07)', () {
    test(
      'the default feed asks for no Routes; a query with text does',
      () async {
        final _Port port = _Port(<Object>[
          _feed(<Object?>[]),
          _feed(<Object?>[]),
        ]);
        final CatalogDiscoverRepository repository = _repository(port);
        await repository.getFeed(_query());
        await repository.getFeed(_query(text: 'river'));
        List<Object?> types(int i) =>
            ((port.requests[i]['payload']! as Map)['query']! as Map)['typeIds']!
                as List<Object?>;
        expect(types(0), isNot(contains('route')));
        expect(types(1), contains('route'));
        final _Port off = _Port(<Object>[_feed(<Object?>[])]);
        await _repository(
          off,
          routeEnabled: false,
        ).getFeed(_query(text: 'river'));
        expect(
          ((off.requests.single['payload']! as Map)['query']!
              as Map)['typeIds'],
          isNot(contains('route')),
        );
      },
    );

    test(
      'a card becomes a Route map object without date, price or duration',
      () async {
        final List<DiscoverItemEntity> items = await _repository(
          _Port(<Object>[
            _feed(<Object?>[_card()]),
          ]),
        ).getFeed(_query(text: 'river'));
        final DiscoverItemEntity item = items.single;
        expect(item.objectKind, DiscoverObjectKind.route);
        expect(item.catalogObjectType, CatalogObjectType.route);
        expect(item.isCatalogRoute, isTrue);
        expect(item.isPublishedRoute, isFalse);
        expect(item.startsAtUtc, isNull);
        expect(item.priceAmount, isNull);
        expect(item.durationMinutes, isNull);
        expect(item.latitude, 56.95);
        expect(item.distanceKm, 1.2);
      },
    );

    test(
      'a newer revision drops the snapshot and is reported, never shown',
      () async {
        final CatalogSnapshotSession session = CatalogSnapshotSession();
        final _Port port = _Port(<Object>[
          _feed(<Object?>[_card()]),
          _details('listed', item: _projection(card: false), changed: true),
          _details('listed', item: _projection(card: false)),
        ]);
        final CatalogDiscoverRepository repository = _repository(
          port,
          session: session,
        );
        await repository.getFeed(_query(text: 'river'));
        await expectLater(
          repository.getDetails('route-1'),
          throwsA(
            isA<DiscoverException>().having(
              (DiscoverException e) => e.code,
              'code',
              routeRevisionChangedCode,
            ),
          ),
        );
        expect(session.snapshotToken, isNull);
        final DiscoverItemEntity fresh = await repository.getDetails('route-1');
        expect(fresh.routeCatalog!.hasFullTrack, isTrue);
        expect(
          (port.requests.last['payload']! as Map).containsKey('snapshotToken'),
          isFalse,
        );
      },
    );

    test('a withdrawn, restricted or deleted Route is not found', () async {
      await expectLater(
        _repository(
          _Port(<Object>[_details('excluded')]),
        ).getDetails('route-1'),
        throwsA(
          isA<DiscoverException>().having(
            (DiscoverException e) => e.code,
            'code',
            'DISCOVER_NOT_FOUND',
          ),
        ),
      );
    });
  });

  group('lookup (RD-07, RD-08)', () {
    test(
      'offline and a newer revision are retryable; not found is null',
      () async {
        DiscoverItemDetailsLookup lookup(Object answer) =>
            DiscoverItemDetailsLookup(
              GetDiscoverDetailsUseCase(_repository(_Port(<Object>[answer]))),
            );
        await expectLater(
          lookup(
            const CatalogTransportFailure('unavailable'),
          ).lookup('route-1'),
          throwsA(isA<DiscoverException>()),
        );
        await expectLater(
          lookup(
            _details('listed', item: _projection(card: false), changed: true),
          ).lookup('route-1'),
          throwsA(isA<DiscoverException>()),
        );
        expect(await lookup(_details('absent')).lookup('route-1'), isNull);
      },
    );
  });

  group('presentation (RD-03, RD-04, RD-09, RD-11, RD-12)', () {
    test('one line per segment, gaps open, direct dashed', () {
      final RouteCatalogFacts facts = CatalogRouteItem.fromWire(
        _projection(card: false),
        card: false,
      ).facts;
      final List<Polyline> lines = buildRouteSegmentPolylines(
        facts.track!,
        idPrefix: 't',
      ).toList();
      expect(lines, hasLength(3));
      expect(lines.last.patterns, isNotEmpty);
      expect(lines.first.patterns, isEmpty);
      expect(routeSegmentsCameraBounds(facts.track!), isNotNull);
    });

    test('labels never invent a metric', () {
      final RouteCatalogFacts without = CatalogRouteItem.fromWire(
        _projection(),
        card: true,
      ).facts;
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
      final AppLocalizations ru = lookupAppLocalizations(const Locale('ru'));
      expect(
        routeCatalogMetricLabel(en, without),
        '2.3 km · direct segments: 1',
      );
      expect(
        routeCatalogMetricLabel(ru, without),
        '2,3 км · прямых участков: 1',
      );
      final RouteCatalogFacts withAscent = CatalogRouteItem.fromWire(
        _projection(ascent: 23.6, publisher: 'user'),
        card: true,
      ).facts;
      expect(routeCatalogMetricLabel(en, withAscent), contains('↑ 24 m'));
      expect(routeCatalogMetricLabel(ru, withAscent), contains('↑ 24 м'));
      expect(routeCatalogPublisherLabel(en, withAscent), 'Author');
      expect(routeCatalogPublisherLabel(ru, withAscent), 'Автор');
      expect(routeCatalogPublisherLabel(ru, without), 'Страница');
    });

    fullPageTestWidgets('Details show the track, facts and waypoints only', (
      WidgetTester tester,
    ) async {
      final DiscoverItemEntity item = DiscoverItemEntity(
        id: 'route-1',
        title: 'Riverside walk',
        subtitle: 'A calm riverside walk',
        city: '',
        category: 'art_culture_museums',
        startsAtUtc: null,
        latitude: 56.95,
        longitude: 24.1,
        priceAmount: null,
        distanceKm: 0,
        isFree: false,
        objectKind: DiscoverObjectKind.route,
        routeCatalog: CatalogRouteItem.fromWire(
          _projection(card: false),
          card: false,
        ).facts,
      );
      bool reported = false;
      final RouteDetailsRenderer renderer = RouteDetailsRenderer(
        item: item,
        isFavorite: false,
        ctaSubmitted: false,
        onFavoriteTap: () {},
        onShareTap: () {},
        onMap: () {},
        onRouteMap: () {},
        onAddToScenario: () {},
        onSearch: () {},
        onCreateSimilar: () {},
        onCreateRoute: () {},
        onMarkVisited: () {},
        onCtaTap: () {},
        onReportRoute: () => reported = true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DetailsShell(state: DetailsScreenAvailable(renderer: renderer)),
        ),
      );
      await tester.pumpAndSettle();
      final GoogleMap map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.polylines, hasLength(3));
      expect(find.text('Riverside walk'), findsOneWidget);
      expect(find.text('2.3 km'), findsOneWidget);
      expect(find.text('Ascent'), findsNothing);
      expect(find.text('Page'), findsOneWidget);
      expect(find.text('Track gaps: 1'), findsOneWidget);
      expect(find.text('Direct segments: 1'), findsOneWidget);
      expect(find.text('Bridge view'), findsOneWidget);
      expect(find.textContaining('Slippery after rain'), findsOneWidget);
      // RD-09: no event cards, CTA, Scenario intake, visit mark or report.
      expect(find.textContaining('Date and time'), findsNothing);
      expect(find.textContaining('Report a problem'), findsNothing);
      expect(find.byTooltip('Add to Scenario: Riverside walk'), findsNothing);
      expect(
        renderer.buildStickyAction(tester.element(find.byType(Scaffold))),
        isNull,
      );
      expect(reported, isFalse);
    });

    fullPageTestWidgets('unavailable states read as the spec says', (
      WidgetTester tester,
    ) async {
      Future<String> shown(DetailsScreenUnavailable state) async {
        await tester.pumpWidget(MaterialApp(home: DetailsShell(state: state)));
        return (tester.widget<Text>(
          find.byKey(const Key('details-unavailable-message')),
        )).data!;
      }

      expect(
        await shown(
          detailsUnavailableForError(
            const DiscoverException(
              code: routeRevisionChangedCode,
              message: '',
            ),
            onRetry: () {},
          ),
        ),
        'The route was updated',
      );
      expect(find.text('Refresh'), findsOneWidget);
      expect(
        await shown(
          detailsUnavailableForError(
            const DiscoverException(
              code: 'CATALOG_TRANSPORT_unavailable',
              message: '',
            ),
            onRetry: () {},
          ),
        ),
        'No connection',
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(
        await shown(
          const DetailsScreenUnavailable(
            reason: DetailsUnavailableReason.notFound,
            notice: DetailsUnavailableNotice.routeUnavailable,
          ),
        ),
        'Route unavailable',
      );
      expect(find.byKey(const Key('details-unavailable-retry')), findsNothing);
    });
  });
}
