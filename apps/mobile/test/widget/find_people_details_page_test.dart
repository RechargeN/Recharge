import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recharge/app/presentation/find_people_details_page.dart';
import 'package:recharge/app/router/route_names.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/published_find_people_discovery_entity.dart';

import 'widget_test_viewport.dart';

void main() {
  fullPageTestWidgets('Share uses the canonical typed deep link', (
    WidgetTester tester,
  ) async {
    final List<MethodCall> clipboardCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'Clipboard.setData') clipboardCalls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final _SpyAnalytics analytics = _SpyAnalytics();
    await tester.pumpWidget(_app(_projection(), analytics));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.ios_share_rounded));
    await tester.pumpAndSettle();

    expect(clipboardCalls, hasLength(1));
    expect(
      clipboardCalls.single.arguments['text'],
      'recharge://discover/details/find_people/fp-1',
    );
    expect(analytics.events, contains('discover_details_viewed'));
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.text('Откликнуться'), findsNothing);
  });

  fullPageTestWidgets('public point is the only variant that opens Map', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_projection(), _SpyAnalytics()));
    await tester.pumpAndSettle();
    await tester.scrollPageUntilVisible(
      find.text('Показать на карте'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Показать на карте'));
    await tester.pumpAndSettle();
    expect(find.text('item=fp-1;lat=56.950000;lng=24.100000'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        _projection(
          location: const PublishedFindPeopleOnlineLocation(
            providerLabel: 'Meet',
          ),
        ),
        _SpyAnalytics(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Показать на карте'), findsNothing);
  });
}

Widget _app(
  PublishedFindPeopleDiscoveryEntity projection,
  AnalyticsService analytics,
) {
  final GoRouter router = GoRouter(
    initialLocation: '/find-people',
    routes: <RouteBase>[
      GoRoute(
        path: '/find-people',
        builder: (BuildContext context, GoRouterState state) =>
            FindPeopleDetailsPage(
              projection: projection,
              analyticsService: analytics,
              timezoneRepository: TimezoneRepositoryImpl(),
            ),
      ),
      GoRoute(
        path: RouteNames.discoverMap,
        builder: (BuildContext context, GoRouterState state) => Scaffold(
          body: Text(
            'item=${state.uri.queryParameters['itemId']};'
            'lat=${state.uri.queryParameters['itemLat']};'
            'lng=${state.uri.queryParameters['itemLng']}',
          ),
        ),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

PublishedFindPeopleDiscoveryEntity _projection({
  PublishedFindPeoplePublicLocation? location,
}) {
  return PublishedFindPeopleDiscoveryEntity(
    requestId: 'fp-1',
    occurrenceId: 'occ-1',
    publisherId: 'user-1',
    publisherType: 'user',
    publisherName: 'Anna',
    title: 'Morning run',
    category: 'sport_fitness',
    scheduleMode: PublishedFindPeopleScheduleMode.single,
    timeOptions: <PublishedFindPeopleTimeOption>[
      PublishedFindPeopleTimeOption(
        id: 'slot-1',
        startAtUtc: DateTime.utc(2026, 9, 12, 5),
        endAtUtc: DateTime.utc(2026, 9, 12, 6),
        kind: PublishedFindPeopleTimeOptionKind.confirmed,
      ),
    ],
    timezoneId: 'Europe/Riga',
    targetGroupSize: 6,
    recruitmentStatus: PublishedFindPeopleRecruitmentStatus.open,
    costType: PublishedFindPeopleCostType.free,
    publicLocation:
        location ??
        PublishedFindPeoplePointLocation(
          meetingMode: PublishedFindPeopleMeetingMode.inPerson,
          areaLabel: 'Central Riga',
          latitude: 56.95,
          longitude: 24.1,
        ),
    publishedAtUtc: DateTime.utc(2026, 9, 1),
  );
}

class _SpyAnalytics implements AnalyticsService {
  final List<String> events = <String>[];

  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {
    events.add(eventName);
  }
}
