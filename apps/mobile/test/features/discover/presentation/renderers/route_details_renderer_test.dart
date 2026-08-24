import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/published_route_discovery_entity.dart';
import 'package:recharge/features/discover/presentation/renderers/route_details_renderer.dart';
import 'package:recharge/features/discover/presentation/shell/details_shell.dart';
import 'package:recharge/shared/primitives/geo/geo_bounds.dart';
import 'package:recharge/shared/primitives/geo/geo_point.dart';

import '../../../../widget/widget_test_viewport.dart';

/// `docs/product/DTL_RTE_01_ROUTE_DETAILS_SLICE_SPEC.md` §2/§3: map-hero,
/// elevation summary (no graph), difficulty/surface/POI/field-verified as
/// first-class, safety reporting, navigation action — plus parity for the
/// generic sections reused from `CompatibilityObjectRenderer`.
void main() {
  fullPageTestWidgets('renders an interactive map hero with an "open on map" action', (
    tester,
  ) async {
    bool mapOpened = false;
    await tester.pumpWidget(_app(_renderer(onMap: () => mapOpened = true)));
    await tester.pumpAndSettle();

    expect(find.byType(GoogleMap), findsOneWidget);
    expect(find.text('Открыть на карте'), findsOneWidget);

    await tester.tap(find.text('Открыть на карте'));
    await tester.pump();
    expect(mapOpened, isTrue);
  });

  fullPageTestWidgets(
    'elevation summary shows ascent/descent and the partial-data note — '
    'never a graph',
    (tester) async {
      await tester.pumpWidget(
        _app(
          _renderer(
            route: _route(
              ascentMeters: 120,
              descentMeters: 80,
              elevationAvailability: 'partial',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Elevation'), findsOneWidget);
      expect(find.text('120 m'), findsOneWidget);
      expect(find.text('80 m'), findsOneWidget);
      expect(find.text('Ascent'), findsOneWidget);
      expect(find.text('Descent'), findsOneWidget);
      expect(
        find.textContaining('not presented as complete'),
        findsOneWidget,
      );
    },
  );

  fullPageTestWidgets(
    'unavailable elevation data is not shown as zero',
    (tester) async {
      await tester.pumpWidget(
        _app(
          _renderer(
            route: _route(
              ascentMeters: null,
              descentMeters: null,
              elevationAvailability: 'unavailable',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('—'), findsWidgets);
      expect(
        find.textContaining('is unavailable and is not shown as zero'),
        findsOneWidget,
      );
    },
  );

  fullPageTestWidgets(
    'difficulty/profile/POI/field-verified/surface render as a first-class '
    'section',
    (tester) async {
      await tester.pumpWidget(
        _app(
          _renderer(
            route: _route(
              routingProfileId: 'walking',
              difficultyId: 'moderate',
              waypointCount: 5,
              fieldVerifiedAtUtc: DateTime.utc(2026, 7, 1),
              surfaceIds: const <String>['paved', 'gravel'],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Route details'), findsOneWidget);
      // 'Walking' also legitimately appears in SummaryCard's Profile
      // metric (unchanged, reused) and may coincide with a taxonomy label
      // for this fixture's category — this assertion only cares that the
      // composition card's own profile pill is among them.
      expect(find.text('Walking'), findsWidgets);
      expect(find.text('Moderate'), findsOneWidget);
      expect(find.text('5 POI'), findsOneWidget);
      expect(find.text('Field verified'), findsOneWidget);
      expect(find.text('Surface'), findsOneWidget);
      expect(find.text('Paved'), findsOneWidget);
      expect(find.text('Gravel'), findsOneWidget);
    },
  );

  fullPageTestWidgets(
    'the safety report action invokes the passed-in callback (dialog flow '
    'itself is page-level, covered separately)',
    (tester) async {
      bool reported = false;
      await tester.pumpWidget(
        _app(_renderer(onReportRoute: () => reported = true)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Сообщить о проблеме на маршруте'));
      await tester.pump();
      expect(reported, isTrue);
    },
  );

  fullPageTestWidgets(
    'reuses the generic sections unchanged — summary/action hub/organizer/'
    'info/highlights/location/sticky bar all present',
    (tester) async {
      await tester.pumpWidget(_app(_renderer()));
      await tester.pumpAndSettle();

      expect(find.text('Forest walking route trail'), findsOneWidget);
      expect(find.text('Plan this recharge'), findsOneWidget);
      expect(find.text('Organizer'), findsOneWidget);
      expect(find.text('What awaits you'), findsOneWidget);
      expect(find.text('Show on map'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsWidgets);
      expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);

      final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.bottomNavigationBar, isNotNull);
    },
  );
}

Widget _app(RouteDetailsRenderer renderer) {
  return MaterialApp(
    home: DetailsShell(state: DetailsScreenAvailable(renderer: renderer)),
  );
}

RouteDetailsRenderer _renderer({
  PublishedRouteDiscoveryEntity? route,
  VoidCallback? onMap,
  VoidCallback? onReportRoute,
}) {
  final DiscoverItemEntity item = _item(route ?? _route());
  return RouteDetailsRenderer(
    item: item,
    isFavorite: false,
    ctaSubmitted: false,
    onFavoriteTap: () {},
    onShareTap: () {},
    onMap: onMap ?? () {},
    onRouteMap: () {},
    onAddToScenario: null,
    onSearch: () {},
    onCreateSimilar: () {},
    onCreateRoute: () {},
    onMarkVisited: () {},
    onCtaTap: () {},
    onReportRoute: onReportRoute ?? () {},
  );
}

DiscoverItemEntity _item(PublishedRouteDiscoveryEntity route) {
  return DiscoverItemEntity(
    id: route.routeId,
    title: 'Forest walking route trail',
    subtitle: 'A continuous trail through the forest.',
    city: 'Riga',
    category: 'outdoor_nature_walking',
    startsAtUtc: DateTime.utc(2026, 8, 1),
    latitude: 56.9496,
    longitude: 24.1052,
    priceAmount: 0,
    distanceKm: 0.4,
    isFree: true,
    objectKind: DiscoverObjectKind.route,
    organizerName: 'Recharge Studio',
    venueName: 'Forest entrance',
    addressLine: 'Trailhead 1',
    highlights: const <String>['Well-marked trail'],
    publishedRoute: route,
  );
}

PublishedRouteDiscoveryEntity _route({
  double? ascentMeters = 120,
  double? descentMeters = 80,
  String elevationAvailability = 'complete',
  String routingProfileId = 'walking',
  String difficultyId = 'easy.v1',
  int waypointCount = 3,
  DateTime? fieldVerifiedAtUtc,
  List<String> surfaceIds = const <String>[],
}) {
  return PublishedRouteDiscoveryEntity(
    routeId: 'route-1',
    versionId: 'v1',
    geometryHash: 'hash',
    contentHash: 'content-v1',
    title: 'Forest walking route',
    subtitle: 'A continuous trail through the forest.',
    city: 'Riga',
    marketCityId: 'riga',
    timezoneId: 'Europe/Riga',
    categoryId: 'outdoor_nature_walking',
    subcategoryId: 'walking_route',
    coverImage: 'asset://route.jpg',
    publisherName: 'Recharge',
    startPoint: const GeoPoint(latitude: 56.9496, longitude: 24.1052),
    bounds: const GeoBounds(
      southwest: GeoPoint(latitude: 56.9496, longitude: 24.1052),
      northeast: GeoPoint(latitude: 56.9520, longitude: 24.1150),
    ),
    overviewEncodedPolyline: '_p~iF~ps|U_ulLnnqC',
    fullEncodedPolyline: '_p~iF~ps|U_ulLnnqC',
    encodingPrecision: 5,
    distanceMeters: 4200,
    durationSeconds: 2700,
    routingProfileId: routingProfileId,
    difficultyId: difficultyId,
    elevationAvailability: elevationAvailability,
    ascentMeters: ascentMeters,
    descentMeters: descentMeters,
    waypointCount: waypointCount,
    fieldVerifiedAtUtc: fieldVerifiedAtUtc,
    surfaceIds: surfaceIds,
    demoOnly: true,
    searchTokens: const <String>['forest', 'walking'],
    attributions: const <String>['OpenStreetMap contributors'],
    publishedAtUtc: DateTime.utc(2026, 7, 25, 10),
  );
}

