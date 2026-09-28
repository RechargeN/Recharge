import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/opening_hours_rule.dart';
import 'package:recharge/features/discover/presentation/renderers/object_offer_details_renderer.dart';
import 'package:recharge/features/discover/presentation/renderers/object_offer_visual_primitives.dart';
import 'package:recharge/features/discover/presentation/shell/details_shell.dart';

import '../../../../widget/widget_test_viewport.dart';

void main() {
  DiscoverItemEntity fixture({
    String subtitle =
        'Тихая городская оранжерея с сезонной экспозицией и местом для отдыха.',
    String organizerName = 'Riga City Gardens',
    List<String> highlights = const <String>[
      'Зимний сад и редкие растения',
      'Доступная среда',
    ],
    List<OpeningHoursRule>? openingHours,
  }) {
    return DiscoverItemEntity(
      id: 'place_1',
      title: 'Оранжерея Верманского сада',
      subtitle: subtitle,
      city: 'Рига',
      category: 'Природа и прогулки',
      subcategory: 'Ботанический сад',
      startsAtUtc: DateTime.utc(2026, 9, 5, 9),
      latitude: 56.954,
      longitude: 24.113,
      priceAmount: 7,
      distanceKm: 1.8,
      isFree: false,
      objectKind: DiscoverObjectKind.place,
      organizerName: organizerName,
      organizerHandle: '@rigagardens',
      venueName: 'Верманский сад',
      addressLine: 'Тербатас iela 2D',
      durationMinutes: 90,
      openingHours:
          openingHours ??
          <OpeningHoursRule>[
            OpeningHoursRule(
              dayOfWeek: DayOfWeek.monday,
              isClosedAllDay: false,
              openMinutesSinceLocalMidnight: 600,
              closeMinutesSinceLocalMidnight: 1140,
            ),
            OpeningHoursRule(dayOfWeek: DayOfWeek.sunday, isClosedAllDay: true),
          ],
      ctaLabel: 'Открыть сайт',
      highlights: highlights,
    );
  }

  Widget app(
    DiscoverItemEntity item, {
    bool isFavorite = false,
    bool ctaSubmitted = false,
    VoidCallback? onFavoriteTap,
    VoidCallback? onShareTap,
    VoidCallback? onMap,
    VoidCallback? onAddToScenario,
    VoidCallback? onCtaTap,
  }) {
    return MaterialApp(
      home: DetailsShell(
        state: DetailsScreenAvailable(
          immersiveHero: true,
          renderer: ObjectOfferDetailsRenderer.discoverItem(
            item: item,
            isFavorite: isFavorite,
            ctaSubmitted: ctaSubmitted,
            onFavoriteTap: onFavoriteTap ?? () {},
            onShareTap: onShareTap ?? () {},
            onMap: onMap ?? () {},
            onRouteMap: () {},
            onAddToScenario: onAddToScenario,
            onSearch: () {},
            onCreateSimilar: () {},
            onCreateRoute: () {},
            onMarkVisited: () {},
            onCtaTap: onCtaTap ?? () {},
            onReportRoute: () {},
          ),
        ),
      ),
    );
  }

  fullPageTestWidgets('Place uses the shared Object / Offer visual grammar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app(fixture()));
    await tester.pumpAndSettle();

    expect(find.byType(ObjectOfferSingleImageHero), findsOneWidget);
    expect(find.byType(ObjectOfferTypeBadge), findsOneWidget);
    expect(find.byType(ObjectOfferContentSheet), findsOneWidget);
    expect(find.byType(ObjectOfferMetricsStrip), findsOneWidget);
    expect(find.byType(ObjectOfferCard), findsNWidgets(4));
    expect(find.byType(ObjectOfferStickyActionShell), findsOneWidget);
    expect(find.text('PLACE'), findsOneWidget);
  });

  fullPageTestWidgets(
    'Place renders data-backed sections in the agreed order',
    (WidgetTester tester) async {
      await tester.pumpWidget(app(fixture()));
      await tester.pumpAndSettle();

      expect(find.text('Оранжерея Верманского сада'), findsOneWidget);
      expect(find.text('7 €'), findsOneWidget);
      expect(find.text('1.8 км'), findsOneWidget);
      expect(find.text('1 ч 30 мин'), findsOneWidget);
      expect(find.text('Riga City Gardens'), findsOneWidget);
      expect(find.text('О месте'), findsOneWidget);
      expect(find.text('Часы работы'), findsOneWidget);
      expect(find.text('Понедельник'), findsOneWidget);
      expect(find.text('10:00–19:00'), findsOneWidget);
      expect(find.text('Показать на карте'), findsOneWidget);
    },
  );

  fullPageTestWidgets(
    'optional Place cards disappear when their data is absent',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        app(
          fixture(
            subtitle: '',
            organizerName: '',
            highlights: const <String>[],
            openingHours: const <OpeningHoursRule>[],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Публикатор'), findsNothing);
      expect(find.text('О месте'), findsNothing);
      expect(find.text('Часы работы'), findsNothing);
      expect(find.text('Показать на карте'), findsOneWidget);
    },
  );

  fullPageTestWidgets('kept Place actions invoke their existing callbacks', (
    WidgetTester tester,
  ) async {
    bool shared = false;
    bool added = false;
    bool mapOpened = false;
    bool ctaTapped = false;
    await tester.pumpWidget(
      app(
        fixture(),
        onShareTap: () => shared = true,
        onAddToScenario: () => added = true,
        onMap: () => mapOpened = true,
        onCtaTap: () => ctaTapped = true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Поделиться и другие действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Поделиться'));
    await tester.pumpAndSettle();
    expect(shared, isTrue);

    await tester.tap(find.byTooltip('Поделиться и другие действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить в сценарий'));
    await tester.pumpAndSettle();
    expect(added, isTrue);

    await tester.tap(find.text('Показать на карте'));
    await tester.pump();
    expect(mapOpened, isTrue);

    await tester.tap(find.text('Открыть сайт'));
    await tester.pump();
    expect(ctaTapped, isTrue);
  });

  testWidgets('Place has no overflow at 360dp and 150% text scale', (
    WidgetTester tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 1800)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: app(fixture()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
