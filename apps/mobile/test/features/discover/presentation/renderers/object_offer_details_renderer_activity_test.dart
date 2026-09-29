import 'package:recharge/shared/primitives/money/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/time_slot.dart';
import 'package:recharge/features/discover/presentation/renderers/object_offer_details_renderer.dart';
import 'package:recharge/features/discover/presentation/renderers/object_offer_visual_primitives.dart';
import 'package:recharge/features/discover/presentation/shell/details_shell.dart';

import '../../../../widget/widget_test_viewport.dart';

void main() {
  DiscoverItemEntity fixture({
    String subtitle =
        'Мягкая утренняя практика, которая помогает настроиться на день.',
    String organizerName = 'Recharge Studio',
    int? participantsCount = 8,
    List<String> highlights = const <String>[
      'Подходит начинающим',
      'Спокойный темп группы',
    ],
    List<TimeSlot>? scheduleSlots,
  }) {
    return DiscoverItemEntity(
      id: 'activity_1',
      title: 'Утренняя йога в парке',
      subtitle: subtitle,
      city: 'Рига',
      category: 'Wellness',
      subcategory: 'Йога',
      startsAtUtc: DateTime.utc(2026, 9, 12, 7),
      latitude: 56.956,
      longitude: 24.112,
      priceAmount: const Money(minorUnits: 0, currencyCode: 'EUR'),
      distanceKm: 1.2,
      isFree: true,
      objectKind: DiscoverObjectKind.activity,
      organizerName: organizerName,
      organizerHandle: '@recharge',
      venueName: 'Верманский парк',
      addressLine: 'Тербатас iela 2D',
      participantsCount: participantsCount,
      capacity: 12,
      durationMinutes: 60,
      scheduleSlots:
          scheduleSlots ??
          <TimeSlot>[
            TimeSlot(
              slotId: 'slot_1',
              startAtUtc: DateTime.utc(2026, 9, 12, 7),
              endAtUtc: DateTime.utc(2026, 9, 12, 8),
            ),
          ],
      ctaLabel: 'Присоединиться',
      highlights: highlights,
    );
  }

  Widget app(
    DiscoverItemEntity item, {
    VoidCallback? onFavoriteTap,
    VoidCallback? onShareTap,
    VoidCallback? onMap,
    VoidCallback? onCtaTap,
  }) {
    return MaterialApp(
      home: DetailsShell(
        state: DetailsScreenAvailable(
          immersiveHero: true,
          renderer: ObjectOfferDetailsRenderer.discoverItem(
            item: item,
            isFavorite: false,
            ctaSubmitted: false,
            onFavoriteTap: onFavoriteTap ?? () {},
            onShareTap: onShareTap ?? () {},
            onMap: onMap ?? () {},
            onRouteMap: () {},
            onAddToScenario: () {},
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

  fullPageTestWidgets('Activity uses the shared Object / Offer grammar', (
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
    expect(find.text('ACTIVITY'), findsOneWidget);
  });

  fullPageTestWidgets('Activity renders only data-backed content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app(fixture()));
    await tester.pumpAndSettle();

    expect(find.text('Утренняя йога в парке'), findsOneWidget);
    expect(find.text('Йога'), findsOneWidget);
    expect(find.text('Бесплатно'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('1 ч'), findsOneWidget);
    expect(find.text('Recharge Studio'), findsOneWidget);
    expect(find.text('О занятии'), findsOneWidget);
    expect(find.text('Подходит начинающим'), findsOneWidget);
    expect(find.text('Расписание'), findsOneWidget);
    expect(find.text('Показать на карте'), findsOneWidget);
  });

  fullPageTestWidgets('missing optional Activity data hides whole sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        fixture(
          subtitle: '',
          organizerName: '',
          highlights: const <String>[],
          scheduleSlots: const <TimeSlot>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Организатор'), findsNothing);
    expect(find.text('О занятии'), findsNothing);
    expect(find.text('Расписание'), findsNothing);
    expect(find.text('Показать на карте'), findsOneWidget);
  });

  fullPageTestWidgets('unknown participant count is an honest dash', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app(fixture(participantsCount: null)));
    await tester.pumpAndSettle();

    expect(find.text('—'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Semantics &&
            widget.properties.label ==
                'Количество участников неизвестно, Участники',
      ),
      findsOneWidget,
    );
  });

  fullPageTestWidgets('Activity keeps existing action callbacks', (
    WidgetTester tester,
  ) async {
    bool saved = false;
    bool shared = false;
    bool mapOpened = false;
    bool joined = false;
    await tester.pumpWidget(
      app(
        fixture(),
        onFavoriteTap: () => saved = true,
        onShareTap: () => shared = true,
        onMap: () => mapOpened = true,
        onCtaTap: () => joined = true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save'));
    await tester.pump();
    expect(saved, isTrue);

    await tester.tap(find.byTooltip('Поделиться и другие действия'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Поделиться'));
    await tester.pumpAndSettle();
    expect(shared, isTrue);

    await tester.tap(find.text('Показать на карте'));
    await tester.pump();
    expect(mapOpened, isTrue);

    await tester.tap(find.text('Присоединиться'));
    await tester.pump();
    expect(joined, isTrue);
  });

  testWidgets('Activity has no overflow at 360dp and 150% text scale', (
    WidgetTester tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 1900)
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
