import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/published_class_workshop_discovery_entity.dart';
import 'package:recharge/features/discover/presentation/renderers/object_offer_details_renderer.dart';
import 'package:recharge/features/discover/presentation/renderers/object_offer_visual_primitives.dart';
import 'package:recharge/features/discover/presentation/shell/details_shell.dart';
import '../../../../fixtures/class_workshop_details_fixture.dart';
import '../../../../widget/widget_test_viewport.dart';

Widget app(
  PublishedClassWorkshopDiscoveryEntity projection, {
  VoidCallback? onMap,
  Future<void> Function()? onPrimary,
}) => MaterialApp(
  home: DetailsShell(
    state: DetailsScreenAvailable(
      immersiveHero: true,
      renderer: ObjectOfferDetailsRenderer.classWorkshop(
        projection: projection,
        timezoneRepository: TimezoneRepositoryImpl(),
        onShareTap: () {},
        onMap: onMap,
        onPrimaryAction: onPrimary,
      ),
    ),
  ),
);

void main() {
  test('currency precision comes from the source without float rounding', () {
    expect(classWorkshopPriceLabel(ClassWorkshopPriceFixed(amountMinor: 2500, currencyCode: 'JPY',
      minorUnitDigits: 0, scope: ClassWorkshopPriceScope.perPersonPerClass)), '2500 JPY');
    expect(classWorkshopPriceLabel(ClassWorkshopPriceFixed(amountMinor: 12345, currencyCode: 'KWD',
      minorUnitDigits: 3, scope: ClassWorkshopPriceScope.perPersonPerClass)), '12.345 KWD');
    expect(() => ClassWorkshopPriceFixed(amountMinor: 1, currencyCode: 'EUR', minorUnitDigits: -1,
      scope: ClassWorkshopPriceScope.perPersonPerClass), throwsArgumentError);
  });
  fullPageTestWidgets(
    'typed sections keep their order, units and separate publisher',
    (tester) async {
      await tester.pumpWidget(
        app(classWorkshopFixture(), onMap: () {}, onPrimary: () async {}),
      );
      await tester.pumpAndSettle();
      final labels = [
        'Мастер-класс по гончарному делу',
        '25 EUR',
        'Ирина Смирнова',
        'О занятии',
        'Расписание',
        'Материалы и что включено',
        'Требования',
        'Brīvības iela 55, Rīga',
      ];
      double previous = -1;
      for (final text in labels) {
        final y = tester.getTopLeft(find.text(text).first).dy;
        expect(y, greaterThan(previous), reason: text);
        previous = y;
      }
      expect(find.text('Цена за человека / занятие'), findsOneWidget);
      expect(find.text('до 8 чел.'), findsOneWidget);
      expect(find.text('Организатор: Студия «Глина»'), findsOneWidget);
      expect(find.text('Организатор подтверждён'), findsOneWidget);
      expect(find.text('Профиль подтверждён'), findsNothing);
      expect(find.byTooltip('Save'), findsNothing);
      expect(find.byTooltip('Share'), findsOneWidget);
      expect(
        tester.getSize(find.byType(FilledButton)).width,
        tester.view.physicalSize.width / tester.view.devicePixelRatio - 32,
      );
    },
  );
  fullPageTestWidgets(
    'empty optional content and unknown metrics do not fabricate values',
    (tester) async {
      await tester.pumpWidget(
        app(
          classWorkshopFixture(
            price: const ClassWorkshopPriceNotProvided(),
            groupLimit: null,
            durationMinutes: null,
            description: '',
            outcomes: [],
            materials: [],
            requirements: [],
            schedule: const ClassWorkshopDatesNotAnnounced(),
          ),
        ),
      );
      expect(find.byType(ObjectOfferMetricsStrip), findsNothing);
      for (final text in [
        'О занятии',
        'Материалы и что включено',
        'Требования',
        'Бесплатно',
        '0 EUR',
      ]) {
        expect(find.text(text), findsNothing);
      }
      expect(find.text('Даты уточняются'), findsWidgets);
    },
  );
  fullPageTestWidgets(
    'single metric hides strip, free price stays distinct, short description is used',
    (tester) async {
      await tester.pumpWidget(
        app(
          classWorkshopFixture(
            price: const ClassWorkshopPriceFree(),
            groupLimit: null,
            durationMinutes: null,
          ),
        ),
      );
      expect(find.byType(ObjectOfferMetricsStrip), findsNothing);
      await tester.pumpWidget(
        app(
          classWorkshopFixture(
            price: const ClassWorkshopPriceFree(),
            groupLimit: null,
            description: '',
            shortDescription: 'Краткое описание',
            outcomes: [],
          ),
        ),
      );
      expect(find.byType(ObjectOfferMetricsStrip), findsOneWidget);
      expect(find.text('Бесплатно'), findsOneWidget);
      expect(find.text('Краткое описание'), findsOneWidget);
    },
  );
  fullPageTestWidgets(
    'whole-series price and duration show the correct units and every date',
    (tester) async {
      final rows = List.generate(
        20,
        (i) => classOccurrence(
          id: 'occ-$i',
          start: DateTime.utc(2026, 9, 12 + i, 10),
          end: DateTime.utc(2026, 9, 12 + i, 12),
        ),
      );
      await tester.pumpWidget(
        app(
          classWorkshopFixture(
            contextKind: ClassWorkshopContextKind.fixedSeries,
            schedule: ClassWorkshopAnnouncedSchedule(rows),
            durationMinutes: 2400,
            durationScope: ClassWorkshopDurationScope.wholeSeries,
            price: ClassWorkshopPriceFixed(
              amountMinor: 12345,
              currencyCode: 'EUR',
              minorUnitDigits: 2,
              scope: ClassWorkshopPriceScope.perPersonFullSeries,
            ),
          ),
        ),
      );
      expect(find.text('123.45 EUR'), findsOneWidget);
      expect(find.text('Цена за человека / курс'), findsOneWidget);
      expect(find.text('Длительность курса'), findsOneWidget);
      expect(find.text('Практика за гончарным кругом'), findsNWidgets(20));
      final last = find.text(
        classWorkshopOccurrenceLabelRu(rows.last, TimezoneRepositoryImpl()),
      );
      await tester.ensureVisible(last);
      expect(tester.takeException(), isNull);
    },
  );
  fullPageTestWidgets('only a public point with callback exposes Map', (
    tester,
  ) async {
    int calls = 0;
    await tester.pumpWidget(app(classWorkshopFixture(), onMap: () => calls++));
    await tester.tap(find.text('Показать на карте'));
    expect(calls, 1);
    for (final location in <ClassWorkshopPublicLocation>[
      const ClassWorkshopOnlineLocation(providerLabel: 'Meet'),
      ClassWorkshopHiddenLocation(
        delivery: ClassWorkshopDelivery.hybrid,
        safeAreaLabel: 'Рига',
      ),
    ]) {
      await tester.pumpWidget(
        app(classWorkshopFixture(location: location), onMap: () => calls++),
      );
      expect(find.text('Показать на карте'), findsNothing);
    }
    await tester.pumpWidget(app(classWorkshopFixture()));
    expect(find.text('Показать на карте'), findsNothing);
  });
  fullPageTestWidgets(
    'same-as-publisher verification is shown on the shared identity',
    (tester) async {
      await tester.pumpWidget(
        app(
          classWorkshopFixture(
            instructor: const ClassWorkshopInstructorSameAsPublisher(),
          ),
        ),
      );
      expect(find.text('Профиль подтверждён'), findsOneWidget);
      expect(find.textContaining('Организатор:'), findsNothing);
    },
  );
  fullPageTestWidgets(
    'external invokes only callback; info-only never exposes a button',
    (tester) async {
      int calls = 0;
      await tester.pumpWidget(
        app(
          classWorkshopFixture(),
          onPrimary: () async {
            calls++;
          },
        ),
      );
      await tester.tap(find.text('Проверить запись на сайте'));
      expect(calls, 1);
      for (final reason in ClassWorkshopInformationReason.values) {
        await tester.pumpWidget(
          app(
            classWorkshopFixture(
              enrollment: ClassWorkshopInformationOnly(reason),
            ),
            onPrimary: () async {
              calls++;
            },
          ),
        );
        expect(find.byType(FilledButton), findsNothing);
      }
      await tester.pumpWidget(app(classWorkshopFixture()));
      expect(find.byType(FilledButton), findsNothing);
      expect(calls, 1);
    },
  );
  fullPageTestWidgets(
    'hero supports no, one and multiple deduplicated media with error fallback',
    (tester) async {
      await tester.pumpWidget(app(classWorkshopFixture()));
      expect(find.byType(PageView), findsNothing);
      await tester.pumpWidget(
        app(classWorkshopFixture(gallery: ['https://example.test/one.png'])),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      await tester.pumpWidget(
        app(
          classWorkshopFixture(
            cover: 'https://example.test/one.png',
            gallery: [
              'https://example.test/one.png',
              'https://example.test/two.png',
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('overnight dates are explicit and use listing timezone', () {
    expect(
      classWorkshopOccurrenceLabelRu(
        classOccurrence(
          start: DateTime.utc(2026, 9, 12, 20, 30),
          end: DateTime.utc(2026, 9, 12, 22),
        ),
        TimezoneRepositoryImpl(),
      ),
      '12 сентября 2026 · 23:30–13 сентября 2026 · 01:00',
    );
  });
  for (final width in [360.0, 375.0]) {
    testWidgets('long content at ${width}dp / 150% has no overflow', (
      tester,
    ) async {
      tester.view
        ..physicalSize = Size(width, 1800)
        ..devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final projection = classWorkshopFixture(
        title:
            'Большой мастер-класс по ручной керамике с подробной практикой и разбором приёмов',
        publisherName:
            'Образовательная студия прикладного искусства и профессионального развития',
        instructor: ClassWorkshopGuestInstructor(
          name:
              'Ирина Александровна Смирнова — преподаватель прикладного искусства',
        ),
        location: ClassWorkshopPointLocation(
          delivery: ClassWorkshopDelivery.hybrid,
          venueName: 'Центр творческого развития и прикладного искусства',
          areaLabel: 'Центр Риги',
          publicAddress:
              'Brīvības iela 55, корпус Б, дальний вход со двора, Rīga',
          latitude: 56.95,
          longitude: 24.1,
          precisionMeters: 50,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: DetailsShell(
            state: DetailsScreenAvailable(
              immersiveHero: true,
              renderer: ObjectOfferDetailsRenderer.classWorkshop(
                projection: projection,
                timezoneRepository: TimezoneRepositoryImpl(),
                onShareTap: () {},
                onMap: () {},
                onPrimaryAction: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
