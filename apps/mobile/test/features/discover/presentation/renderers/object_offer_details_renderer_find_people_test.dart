import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/published_find_people_discovery_entity.dart';
import 'package:recharge/features/discover/domain/entities/publisher_verification_display_state.dart';
import 'package:recharge/features/discover/domain/repositories/timezone_repository.dart';
import 'package:recharge/features/discover/presentation/renderers/object_offer_details_renderer.dart';
import 'package:recharge/features/discover/presentation/shell/details_shell.dart';

import '../../../../widget/widget_test_viewport.dart';

void main() {
  final TimezoneRepository timezoneRepository = TimezoneRepositoryImpl();

  PublishedFindPeopleDiscoveryEntity fixture({
    String publisherName = 'Анна К.',
    String fullDescription =
        'Ищу компанию для регулярных утренних пробежек по парку. Темп '
        'спокойный, для новичков подходит.',
    int? currentGroupSize = 3,
    int? durationMinutes = 60,
    List<String> requirements = const <String>['Базовый уровень бега'],
    String equipmentNote = 'Своя обувь для бега',
    String accessibilityNote = '',
    PublishedFindPeoplePublicLocation? location,
    PublishedFindPeopleScheduleMode scheduleMode =
        PublishedFindPeopleScheduleMode.single,
    List<PublishedFindPeopleTimeOption>? timeOptions,
    PublishedFindPeopleCostType costType = PublishedFindPeopleCostType.free,
    double? expectedSpendAmount,
    String currencyCode = 'EUR',
    String costNote = '',
    String title = 'Утренняя пробежка в парке',
  }) {
    return PublishedFindPeopleDiscoveryEntity(
      requestId: 'fp_1',
      occurrenceId: 'fp_occ_1',
      publisherId: 'user_1',
      publisherType: 'user',
      publisherName: publisherName,
      publisherHandle: '@anna_runs',
      publisherVerification: PublisherVerificationDisplayState.verifiedCreator,
      title: title,
      purposeLabel: 'Найти партнёров для утренней пробежки',
      fullDescription: fullDescription,
      category: 'sport_fitness',
      subcategory: 'running',
      scheduleMode: scheduleMode,
      timeOptions:
          timeOptions ??
          <PublishedFindPeopleTimeOption>[
            PublishedFindPeopleTimeOption(
              id: 'slot_1',
              startAtUtc: DateTime.utc(2026, 9, 12, 5),
              endAtUtc: DateTime.utc(2026, 9, 12, 6),
              kind: PublishedFindPeopleTimeOptionKind.confirmed,
            ),
          ],
      timezoneId: 'Europe/Riga',
      durationMinutes: durationMinutes,
      currentGroupSize: currentGroupSize,
      targetGroupSize: 6,
      remainingSeats: 3,
      recruitmentStatus: PublishedFindPeopleRecruitmentStatus.open,
      skillLevelLabel: 'Новички и продолжающие',
      paceLabel: 'Спокойный темп',
      languageLabels: const <String>['Русский', 'English'],
      publicRequirements: requirements,
      equipmentNote: equipmentNote,
      accessibilityNote: accessibilityNote,
      costType: costType,
      expectedSpendAmount: expectedSpendAmount,
      currencyCode: currencyCode,
      costNote: costNote,
      publicLocation:
          location ??
          PublishedFindPeoplePointLocation(
            meetingMode: PublishedFindPeopleMeetingMode.inPerson,
            areaLabel: 'Верманский парк, Рига',
            latitude: 56.9537,
            longitude: 24.1138,
          ),
      publishedAtUtc: DateTime.utc(2026, 9, 1),
    );
  }

  Widget app(
    PublishedFindPeopleDiscoveryEntity projection, {
    VoidCallback? onMap,
    VoidCallback? onShare,
  }) {
    return MaterialApp(
      home: DetailsShell(
        state: DetailsScreenAvailable(
          immersiveHero: true,
          renderer: ObjectOfferDetailsRenderer.findPeople(
            projection: projection,
            timezoneRepository: timezoneRepository,
            onShareTap: onShare ?? () {},
            onMap: onMap,
          ),
        ),
      ),
    );
  }

  fullPageTestWidgets('renders typed blocks in the Find People matrix order', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app(fixture()));
    await tester.pumpAndSettle();

    final List<Finder> inOrder = <Finder>[
      find.text('Утренняя пробежка в парке'),
      find.text('Найти партнёров для утренней пробежки'),
      find.text('3'),
      find.text('Анна К.'),
      find.text('О встрече'),
      find.text('Время встречи'),
      find.text('Формат встречи'),
      find.text('Требования к участникам'),
      find.text('Ожидаемые расходы'),
      find.text('Верманский парк, Рига').last,
    ];
    double lastY = -1;
    for (int index = 0; index < inOrder.length; index++) {
      final Finder finder = inOrder[index];
      expect(finder, findsOneWidget, reason: 'section #$index missing');
      final double y = tester.getTopLeft(finder).dy;
      expect(y, greaterThan(lastY), reason: 'section #$index out of order');
      lastY = y;
    }
  });

  fullPageTestWidgets(
    'hides metrics when only the required target size is known',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        app(fixture(currentGroupSize: null, durationMinutes: null)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Сейчас в группе'), findsNothing);
      expect(find.text('Желаемый размер'), findsNothing);
    },
  );

  fullPageTestWidgets('empty optional content sections are absent', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        fixture(
          publisherName: '',
          fullDescription: '',
          requirements: const <String>[],
          equipmentNote: '',
          accessibilityNote: '',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Организатор'), findsNothing);
    expect(find.text('О встрече'), findsNothing);
    expect(find.text('Требования к участникам'), findsNothing);
  });

  fullPageTestWidgets('point location invokes the real Map callback', (
    WidgetTester tester,
  ) async {
    bool tapped = false;
    await tester.pumpWidget(app(fixture(), onMap: () => tapped = true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Показать на карте'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  fullPageTestWidgets('online and hidden locations expose no Map affordance', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        fixture(
          location: const PublishedFindPeopleOnlineLocation(
            providerLabel: 'Google Meet',
          ),
        ),
        onMap: () {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Показать на карте'), findsNothing);
    expect(find.text('Google Meet'), findsWidgets);

    await tester.pumpWidget(
      app(
        fixture(
          location: PublishedFindPeopleHiddenLocation(
            meetingMode: PublishedFindPeopleMeetingMode.inPerson,
            safeAreaLabel: 'Центр Риги',
          ),
        ),
        onMap: () {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Показать на карте'), findsNothing);
    expect(find.text('Координаты недоступны публично'), findsOneWidget);
  });

  fullPageTestWidgets('Share exists while Save and Join are absent', (
    WidgetTester tester,
  ) async {
    bool shared = false;
    await tester.pumpWidget(app(fixture(), onShare: () => shared = true));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.text('Откликнуться'), findsNothing);
    await tester.tap(find.byIcon(Icons.ios_share_rounded));
    await tester.pump();
    expect(shared, isTrue);
  });

  fullPageTestWidgets(
    'time poll labels candidates without presenting them as confirmed',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        app(
          fixture(
            scheduleMode: PublishedFindPeopleScheduleMode.timePoll,
            timeOptions: <PublishedFindPeopleTimeOption>[
              PublishedFindPeopleTimeOption(
                id: 'candidate_1',
                startAtUtc: DateTime.utc(2026, 9, 12, 5),
                endAtUtc: DateTime.utc(2026, 9, 12, 6),
                kind: PublishedFindPeopleTimeOptionKind.candidate,
              ),
              PublishedFindPeopleTimeOption(
                id: 'candidate_2',
                startAtUtc: DateTime.utc(2026, 9, 13, 6),
                endAtUtc: DateTime.utc(2026, 9, 13, 7),
                kind: PublishedFindPeopleTimeOptionKind.candidate,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 варианта времени'), findsOneWidget);
      expect(find.text('Варианты времени'), findsOneWidget);
      expect(find.textContaining('Вариант · '), findsNWidgets(2));
    },
  );

  fullPageTestWidgets('estimated and unknown costs stay distinct', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        fixture(
          costType: PublishedFindPeopleCostType.estimated,
          expectedSpendAmount: 7.5,
          costNote: 'Кофе после пробежки',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('€7.50'), findsOneWidget);

    await tester.pumpWidget(
      app(fixture(costType: PublishedFindPeopleCostType.unknown)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Расходы не указаны'), findsOneWidget);
    expect(find.text('Без обязательных расходов'), findsNothing);
  });

  group('at 360dp / 150% text scale', () {
    testWidgets('long typed content renders without overflow', (
      WidgetTester tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360, 1700)
        ..devicePixelRatio = 1;
      addTearDown(() {
        tester.view
          ..resetPhysicalSize()
          ..resetDevicePixelRatio();
      });
      final PublishedFindPeopleDiscoveryEntity projection = fixture(
        title:
            'Ищу компанию для длинной велопрогулки по побережью в эти '
            'выходные, готов подстроиться под темп новичков',
        publisherName:
            'Марина Александровна Петровская-Иванова, велоклуб Балтика',
        accessibilityNote:
            'Маршрут можно сократить и согласовать спокойный темп заранее',
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
              renderer: ObjectOfferDetailsRenderer.findPeople(
                projection: projection,
                timezoneRepository: timezoneRepository,
                onShareTap: () {},
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
