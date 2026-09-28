import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recharge/app/presentation/bookable_session_details_page.dart';
import 'package:recharge/app/router/route_names.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/published_bookable_session_discovery_entity.dart';

import 'widget_test_viewport.dart' as viewport;

void main() {
  fullPageTestWidgets('open page expires without a user interaction', (
    WidgetTester tester,
  ) async {
    DateTime now = DateTime.utc(2026, 9, 7, 10, 59, 59);
    await tester.pumpWidget(_app(_projection(), clock: () => now));
    expect(find.text('Проверить и забронировать'), findsOneWidget);
    now = DateTime.utc(2026, 9, 7, 11);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Проверить время на сайте'), findsOneWidget);
  });

  fullPageTestWidgets('resume re-evaluates an expired snapshot', (
    WidgetTester tester,
  ) async {
    DateTime now = DateTime.utc(2026, 9, 7, 10, 30);
    await tester.pumpWidget(_app(_projection(), clock: () => now));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime.utc(2026, 9, 7, 12);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Проверить время на сайте'), findsOneWidget);
  });

  fullPageTestWidgets('platform launch exception has explicit feedback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _projection(),
        launcher: (_) async {
          throw PlatformException(code: 'launch_failed');
        },
      ),
    );
    await tester.tap(find.text('Проверить и забронировать'));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось открыть сайт бронирования'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
    await tester.pumpWidget(_app(_projection(), analytics: analytics));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.ios_share_rounded));
    await tester.pumpAndSettle();

    expect(clipboardCalls, hasLength(1));
    expect(
      clipboardCalls.single.arguments['text'],
      'recharge://discover/details/session/session-1',
    );
    expect(find.byTooltip('Save'), findsNothing);
    expect(analytics.names, contains('discover_details_viewed'));
    expect(
      analytics.params.expand((item) => item.keys),
      isNot(contains(anyOf('url', 'slotKey', 'address', 'coordinates'))),
    );
  });

  fullPageTestWidgets('only a public point opens Map', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_projection()));
    await tester.pumpAndSettle();
    await tester.scrollPageUntilVisible(
      find.text('Показать на карте'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Показать на карте'));
    await tester.pumpAndSettle();
    expect(
      find.text('item=session-1;lat=56.950000;lng=24.100000'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _app(
        _projection(
          location: const PublishedBookableSessionOnlineLocation(
            providerLabel: 'Meet',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Показать на карте'), findsNothing);
  });

  fullPageTestWidgets(
    'external CTA forwards the exact URI even when the snapshot is stale',
    (WidgetTester tester) async {
      Uri? launchedUri;
      final _SpyAnalytics analytics = _SpyAnalytics();
      await tester.pumpWidget(
        _app(
          _projection(),
          analytics: analytics,
          clock: () => DateTime.utc(2026, 9, 8),
          launcher: (Uri uri) async {
            launchedUri = uri;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Проверить время на сайте'), findsOneWidget);
      await tester.tap(find.text('Проверить время на сайте'));
      await tester.pump();
      expect(
        launchedUri,
        Uri.parse('https://booking.example/service?source=provider'),
      );
      expect(analytics.names, contains('discover_details_external_cta_tapped'));
    },
  );

  fullPageTestWidgets('launch failure is explicit', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_projection(), launcher: (Uri uri) async => false),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Проверить и забронировать'));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось открыть сайт бронирования'), findsOneWidget);
  });
}

void fullPageTestWidgets(String description, WidgetTesterCallback callback) {
  viewport.fullPageTestWidgets(description, (tester) async {
    try {
      await callback(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

Widget _app(
  PublishedBookableSessionDiscoveryEntity projection, {
  AnalyticsService? analytics,
  BookableSessionDetailsClock? clock,
  BookableSessionExternalLauncher? launcher,
}) {
  final GoRouter router = GoRouter(
    initialLocation: '/session',
    routes: <RouteBase>[
      GoRoute(
        path: '/session',
        builder: (BuildContext context, GoRouterState state) =>
            BookableSessionDetailsPage(
              projection: projection,
              analyticsService: analytics ?? _SpyAnalytics(),
              timezoneRepository: TimezoneRepositoryImpl(),
              clock: clock ?? () => DateTime.utc(2026, 9, 7, 10, 30),
              externalLauncher: launcher ?? (Uri uri) async => true,
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

PublishedBookableSessionDiscoveryEntity _projection({
  PublishedBookableSessionPublicLocation? location,
}) {
  return PublishedBookableSessionDiscoveryEntity(
    sessionId: 'session-1',
    publisherId: 'page-1',
    publisherType: 'page',
    publisherName: 'Studio',
    title: 'Personal training',
    resourceName: 'Room 1',
    category: 'sport_fitness',
    serviceCategoryLabel: 'Personal training',
    durationMinutes: 60,
    maxPartySize: 1,
    priceType: PublishedBookableSessionPriceType.fixed,
    priceAmountMinor: 4000,
    currencyCode: 'EUR',
    timezoneId: 'Europe/Riga',
    schedule: PublishedBookableSessionScheduleSnapshot(
      scheduleRevision: 1,
      generatedAtUtc: DateTime.utc(2026, 9, 7, 10),
      validUntilUtc: DateTime.utc(2026, 9, 7, 11),
      offers: <PublishedBookableSessionOffer>[
        PublishedBookableSessionOffer(
          slotKey: 'slot-1',
          startAtUtc: DateTime.utc(2026, 9, 12, 15),
          endAtUtc: DateTime.utc(2026, 9, 12, 16),
          timezoneId: 'Europe/Riga',
        ),
      ],
    ),
    publicLocation:
        location ??
        PublishedBookableSessionPointLocation(
          meetingMode: PublishedBookableSessionMeetingMode.inPerson,
          venueName: 'Studio',
          areaLabel: 'Riga',
          latitude: 56.95,
          longitude: 24.1,
          publicGeoPrecisionMeters: 50,
        ),
    externalBookingUri: Uri.parse(
      'https://booking.example/service?source=provider',
    ),
    publishedAtUtc: DateTime.utc(2026, 9, 1),
  );
}

class _SpyAnalytics implements AnalyticsService {
  final List<String> names = <String>[];
  final List<Map<String, Object?>> params = <Map<String, Object?>>[];

  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {
    names.add(eventName);
    this.params.add(params);
  }
}
