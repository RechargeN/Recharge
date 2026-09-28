import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recharge/app/presentation/class_workshop_details_page.dart';
import 'package:recharge/app/router/route_names.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/published_class_workshop_discovery_entity.dart';
import '../fixtures/class_workshop_details_fixture.dart';
import 'widget_test_viewport.dart';

Widget app(
  PublishedClassWorkshopDiscoveryEntity projection, {
  ClassWorkshopExternalLauncher? launcher,
  AnalyticsService? analytics,
}) {
  final router = GoRouter(
    initialLocation: '/class',
    routes: [
      GoRoute(
        path: '/class',
        builder: (_, __) => ClassWorkshopDetailsPage(
          projection: projection,
          timezoneRepository: TimezoneRepositoryImpl(),
          analyticsService: analytics ?? _Analytics(),
          externalLauncher: launcher ?? (_) async => true,
        ),
      ),
      GoRoute(
        path: RouteNames.discoverMap,
        builder: (_, state) => Scaffold(
          body: Text(
            'map:${state.uri.queryParameters['itemId']}:${state.uri.queryParameters['itemLat']}',
          ),
        ),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  fullPageTestWidgets('Share is canonical and Save is absent', (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(app(classWorkshopFixture()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    expect(
      calls.single.arguments['text'],
      'recharge://discover/details/class_workshop/class-1',
    );
    expect(find.byTooltip('Save'), findsNothing);
  });
  fullPageTestWidgets(
    'public point navigates, online and hidden have no map target',
    (tester) async {
      await tester.pumpWidget(app(classWorkshopFixture()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Показать на карте'));
      await tester.pumpAndSettle();
      expect(find.text('map:class-1:56.950000'), findsOneWidget);
      for (final location in <ClassWorkshopPublicLocation>[
        const ClassWorkshopOnlineLocation(),
        ClassWorkshopHiddenLocation(
          delivery: ClassWorkshopDelivery.offline,
          safeAreaLabel: 'Рига',
        ),
      ]) {
        await tester.pumpWidget(app(classWorkshopFixture(location: location)));
        await tester.pumpAndSettle();
        expect(find.text('Показать на карте'), findsNothing);
      }
    },
  );
  fullPageTestWidgets(
    'external sends exact URI even for past dates, telemetry is allowlisted',
    (tester) async {
      Uri? launched;
      final analytics = _Analytics();
      final uri = Uri.parse(
        'https://booking.example/class?source=organizer#details',
      );
      await tester.pumpWidget(
        app(
          classWorkshopFixture(
            enrollment: ClassWorkshopExternalEnrollment(uri),
            schedule: ClassWorkshopAnnouncedSchedule([
              classOccurrence(
                start: DateTime.utc(2020, 1, 1, 10),
                end: DateTime.utc(2020, 1, 1, 12),
              ),
            ]),
          ),
          analytics: analytics,
          launcher: (value) async {
            launched = value;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Проверить запись на сайте'));
      await tester.pump();
      expect(launched, uri);
      expect(analytics.names, contains('discover_details_external_cta_tapped'));
      for (final params in analytics.params) {
        expect(
          params.keys.toSet().difference({
            'item_id',
            'object_type',
            'category',
            'enrollment_state',
          }),
          isEmpty,
        );
      }
    },
  );
  fullPageTestWidgets('each info-only state has disclosure and cannot launch', (
    tester,
  ) async {
    final labels = [
      'Запись закрыта',
      'Условия участия уточняются на месте',
      'Способ записи пока не указан',
      'Запись через приложение пока не подключена',
    ];
    int calls = 0;
    for (final reason in ClassWorkshopInformationReason.values) {
      await tester.pumpWidget(
        app(
          classWorkshopFixture(
            enrollment: ClassWorkshopInformationOnly(reason),
          ),
          launcher: (_) async {
            calls++;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(labels[reason.index]), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    }
    expect(calls, 0);
  });
  for (final throws in [false, true]) {
    fullPageTestWidgets(
      'launch failure (throws: $throws) is explicit and retryable',
      (tester) async {
        int calls = 0;
        await tester.pumpWidget(
          app(
            classWorkshopFixture(),
            launcher: (_) async {
              calls++;
              if (throws) throw PlatformException(code: 'failed');
              return false;
            },
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Проверить запись на сайте'));
        await tester.pumpAndSettle();
        expect(find.text('Не удалось открыть сайт записи'), findsOneWidget);
        await tester.tap(find.text('Проверить запись на сайте'));
        await tester.pump();
        expect(calls, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }
  fullPageTestWidgets('view event is once per identity, not once per rebuild', (
    tester,
  ) async {
    final analytics = _Analytics();
    Widget page(String id) => MaterialApp(
      home: ClassWorkshopDetailsPage(
        projection: classWorkshopFixture(id: id),
        analyticsService: analytics,
        timezoneRepository: TimezoneRepositoryImpl(),
        externalLauncher: (_) async => true,
      ),
    );
    await tester.pumpWidget(page('class-1'));
    await tester.pumpWidget(page('class-1'));
    expect(
      analytics.names.where((s) => s == 'discover_details_viewed'),
      hasLength(1),
    );
    await tester.pumpWidget(page('class-2'));
    expect(
      analytics.names.where((s) => s == 'discover_details_viewed'),
      hasLength(2),
    );
  });
}

class _Analytics implements AnalyticsService {
  final names = <String>[];
  final params = <Map<String, Object?>>[];
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {
    names.add(eventName);
    this.params.add(params);
  }
}
