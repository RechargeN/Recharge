import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/bookable_session_schedule_evaluation.dart';
import 'package:recharge/features/discover/domain/entities/published_bookable_session_discovery_entity.dart';
import 'package:recharge/features/discover/domain/entities/publisher_verification_display_state.dart';
import 'package:recharge/features/discover/domain/repositories/timezone_repository.dart';
import 'package:recharge/features/discover/domain/usecases/evaluate_bookable_session_schedule_usecase.dart';
import 'package:recharge/features/discover/presentation/renderers/object_offer_details_renderer.dart';
import 'package:recharge/features/discover/presentation/shell/details_shell.dart';

import '../../../../widget/widget_test_viewport.dart';

void main() {
  final TimezoneRepository timezoneRepository = TimezoneRepositoryImpl();
  const EvaluateBookableSessionScheduleUseCase evaluate =
      EvaluateBookableSessionScheduleUseCase();
  final DateTime nowUtc = DateTime.utc(2026, 9, 7, 10, 30);

  PublishedBookableSessionDiscoveryEntity fixture({
    String title = 'Индивидуальная тренировка',
    String publisherName = 'Recharge Studio',
    String description =
        'Индивидуальная тренировка под ваши цели: разбор техники, план '
        'нагрузки и обратная связь после каждого занятия.',
    PublishedBookableSessionPriceType priceType =
        PublishedBookableSessionPriceType.fixed,
    int? amountMinor = 4000,
    String currencyCode = 'EUR',
    PublishedBookableSessionPublicLocation? location,
    PublishedBookableSessionScheduleSnapshot? schedule,
    String coverImageUrl = '',
    List<String> galleryImageUrls = const <String>[],
  }) {
    return PublishedBookableSessionDiscoveryEntity(
      sessionId: 'session_1',
      publisherId: 'page_1',
      publisherType: 'page',
      publisherName: publisherName,
      publisherHandle: '@recharge.studio',
      publisherVerification: PublisherVerificationDisplayState.verifiedPage,
      title: title,
      coverImageUrl: coverImageUrl,
      galleryImageUrls: galleryImageUrls,
      resourceName: 'Зал персональных тренировок',
      fullDescription: description,
      category: 'sport_fitness',
      subcategory: 'personal_training',
      serviceCategoryLabel: 'Персональная тренировка',
      durationMinutes: 60,
      maxPartySize: 1,
      priceType: priceType,
      priceAmountMinor: amountMinor,
      currencyCode: currencyCode,
      timezoneId: 'Europe/Riga',
      schedule:
          schedule ??
          PublishedBookableSessionScheduleSnapshot(
            scheduleRevision: 1,
            generatedAtUtc: DateTime.utc(2026, 9, 7, 10),
            validUntilUtc: DateTime.utc(2026, 9, 7, 11),
            offers: <PublishedBookableSessionOffer>[
              PublishedBookableSessionOffer(
                slotKey: 'slot_1',
                startAtUtc: DateTime.utc(2026, 9, 12, 15),
                endAtUtc: DateTime.utc(2026, 9, 12, 16),
                timezoneId: 'Europe/Riga',
              ),
              PublishedBookableSessionOffer(
                slotKey: 'slot_2',
                startAtUtc: DateTime.utc(2026, 9, 13, 8),
                endAtUtc: DateTime.utc(2026, 9, 13, 9),
                timezoneId: 'Europe/Riga',
              ),
            ],
          ),
      publicLocation:
          location ??
          PublishedBookableSessionPointLocation(
            meetingMode: PublishedBookableSessionMeetingMode.inPerson,
            venueName: 'Фитнес-студия «Форма»',
            areaLabel: 'Центр Риги',
            publicAddress: 'Brīvības iela 55, Rīga',
            latitude: 56.953,
            longitude: 24.113,
            publicGeoPrecisionMeters: 50,
          ),
      externalBookingUri: Uri.parse(
        'https://booking.example/sessions/personal-training',
      ),
      publishedAtUtc: DateTime.utc(2026, 9, 1),
    );
  }

  BookableSessionScheduleEvaluation evaluation(
    PublishedBookableSessionDiscoveryEntity projection, {
    DateTime? at,
  }) {
    return evaluate(snapshot: projection.schedule, nowUtc: at ?? nowUtc);
  }

  Widget app(
    PublishedBookableSessionDiscoveryEntity projection, {
    BookableSessionScheduleEvaluation? scheduleEvaluation,
    VoidCallback? onMap,
    VoidCallback? onShare,
    Future<void> Function()? onPrimaryAction,
  }) {
    return MaterialApp(
      home: DetailsShell(
        state: DetailsScreenAvailable(
          immersiveHero: true,
          renderer: ObjectOfferDetailsRenderer.bookableSession(
            projection: projection,
            scheduleEvaluation: scheduleEvaluation ?? evaluation(projection),
            timezoneRepository: timezoneRepository,
            onShareTap: onShare ?? () {},
            onMap: onMap,
            onPrimaryAction: onPrimaryAction ?? () async {},
          ),
        ),
      ),
    );
  }

  fullPageTestWidgets(
    'renders typed header, metrics, provider, about, schedule, location and CTA in order',
    (WidgetTester tester) async {
      final PublishedBookableSessionDiscoveryEntity projection = fixture();
      await tester.pumpWidget(app(projection));
      await tester.pumpAndSettle();

      final List<Finder> inOrder = <Finder>[
        find.text('Индивидуальная тренировка'),
        find.text('40 EUR'),
        find.text('Recharge Studio'),
        find.text('Об услуге'),
        find.text('Время для записи'),
        find.text('Фитнес-студия «Форма»'),
        find.text('Проверить и забронировать'),
      ];
      double lastY = -1;
      for (int index = 0; index < inOrder.length; index++) {
        final Finder finder = inOrder[index];
        expect(finder, findsOneWidget, reason: 'section #$index missing');
        final double y = tester.getTopLeft(finder).dy;
        expect(y, greaterThan(lastY), reason: 'section #$index out of order');
        lastY = y;
      }
      expect(
        find.textContaining('Фактическое время и условия'),
        findsOneWidget,
      );
    },
  );

  fullPageTestWidgets('Share is real while legacy Save is absent', (
    WidgetTester tester,
  ) async {
    bool shared = false;
    await tester.pumpWidget(app(fixture(), onShare: () => shared = true));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Save'), findsNothing);
    await tester.tap(find.byTooltip('Share'));
    expect(shared, isTrue);
  });

  fullPageTestWidgets('public point is the only location with a Map action', (
    WidgetTester tester,
  ) async {
    bool mapped = false;
    await tester.pumpWidget(app(fixture(), onMap: () => mapped = true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Показать на карте'));
    expect(mapped, isTrue);

    await tester.pumpWidget(
      app(
        fixture(
          location: const PublishedBookableSessionOnlineLocation(
            providerLabel: 'Google Meet',
          ),
        ),
        onMap: () => mapped = false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Показать на карте'), findsNothing);
    expect(find.text('Google Meet'), findsOneWidget);

    await tester.pumpWidget(
      app(
        fixture(
          location: PublishedBookableSessionHiddenLocation(
            meetingMode: PublishedBookableSessionMeetingMode.inPerson,
            safeAreaLabel: 'Рига',
          ),
        ),
        onMap: () => mapped = false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Показать на карте'), findsNothing);
    expect(find.text('Точный адрес не опубликован'), findsOneWidget);
  });

  fullPageTestWidgets('fresh empty and stale schedules stay honest', (
    WidgetTester tester,
  ) async {
    final PublishedBookableSessionDiscoveryEntity projection = fixture();
    await tester.pumpWidget(
      app(
        projection,
        scheduleEvaluation: BookableSessionScheduleEvaluation(
          state: BookableSessionScheduleState.freshEmpty,
          visibleOffers: const <PublishedBookableSessionOffer>[],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('В текущем окне время не указано.'), findsOneWidget);
    expect(find.text('Проверить время на сайте'), findsOneWidget);

    await tester.pumpWidget(
      app(
        projection,
        scheduleEvaluation: BookableSessionScheduleEvaluation(
          state: BookableSessionScheduleState.stale,
          visibleOffers: const <PublishedBookableSessionOffer>[],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Расписание требует обновления'),
      findsOneWidget,
    );
    expect(find.textContaining('12 сентября'), findsNothing);
    expect(find.text('Проверить время на сайте'), findsOneWidget);
  });

  fullPageTestWidgets('external CTA invokes only the supplied callback', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    await tester.pumpWidget(
      app(fixture(), onPrimaryAction: () async => calls++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Проверить и забронировать'));
    await tester.pump();
    expect(calls, 1);
  });

  fullPageTestWidgets('free and fixed price semantics are distinct', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app(fixture()));
    await tester.pumpAndSettle();
    expect(find.text('40 EUR'), findsOneWidget);

    await tester.pumpWidget(
      app(
        fixture(
          priceType: PublishedBookableSessionPriceType.free,
          amountMinor: null,
          currencyCode: '',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Бесплатно'), findsOneWidget);
    expect(find.text('0 EUR'), findsNothing);
  });

  fullPageTestWidgets(
    'hero handles absent, single and deduplicated gallery media',
    (tester) async {
      await tester.pumpWidget(app(fixture()));
      expect(find.byType(PageView), findsNothing);
      await tester.pumpWidget(
        app(fixture(galleryImageUrls: ['https://example.test/one.png'])),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      await tester.pumpWidget(
        app(
          fixture(
            coverImageUrl: 'https://example.test/one.png',
            galleryImageUrls: [
              'https://example.test/one.png',
              ' ',
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

  test('offer crossing local midnight includes the end date', () {
    expect(
      bookableSessionOfferLabelRu(
        PublishedBookableSessionOffer(
          slotKey: 'overnight',
          startAtUtc: DateTime.utc(2026, 9, 12, 20, 30),
          endAtUtc: DateTime.utc(2026, 9, 12, 22),
          timezoneId: 'Europe/Riga',
        ),
        timezoneRepository,
      ),
      '12 сентября, сб · 23:30–13 сентября · 01:00',
    );
  });

  for (final double width in <double>[360, 375]) {
    group('at ${width}dp / 150% text scale', () {
      testWidgets('long typed content renders without overflow', (
        WidgetTester tester,
      ) async {
        tester.view
          ..physicalSize = Size(width, 1800)
          ..devicePixelRatio = 1;
        addTearDown(() {
          tester.view
            ..resetPhysicalSize()
            ..resetDevicePixelRatio();
        });
        final PublishedBookableSessionDiscoveryEntity projection = fixture(
          title:
              'Индивидуальная консультация и тренировка по восстановлению '
              'после травмы с полным разбором техники движений',
          publisherName:
              'Дмитрий Александрович Волков, мастер спорта по лёгкой атлетике',
          description:
              'Индивидуальная тренировка под ваши цели: разбор техники, '
              'подробный план нагрузки и обратная связь после занятия.',
          location: PublishedBookableSessionPointLocation(
            meetingMode: PublishedBookableSessionMeetingMode.hybrid,
            venueName: 'Фитнес-студия «Форма», отдельный кабинет реабилитации',
            areaLabel: 'Центр Риги',
            publicAddress: 'Brīvības iela 55, корпус Б, Рига, LV-1039',
            latitude: 56.953,
            longitude: 24.113,
            publicGeoPrecisionMeters: 50,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            builder: (BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: DetailsShell(
              state: DetailsScreenAvailable(
                immersiveHero: true,
                renderer: ObjectOfferDetailsRenderer.bookableSession(
                  projection: projection,
                  scheduleEvaluation: evaluation(projection),
                  timezoneRepository: timezoneRepository,
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
      });
    });
  }
}
