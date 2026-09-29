import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/event_occurrence.dart';
import 'package:recharge/features/discover/domain/entities/published_event_discovery_entity.dart';
import 'package:recharge/features/discover/domain/entities/published_event_program_item.dart';
import 'package:recharge/features/discover/domain/entities/publisher_verification_display_state.dart';
import 'package:recharge/features/discover/domain/repositories/timezone_repository.dart';
import 'package:recharge/features/discover/presentation/renderers/object_offer_details_renderer.dart';
import 'package:recharge/features/discover/presentation/renderers/object_offer_visual_primitives.dart';
import 'package:recharge/features/discover/presentation/shell/details_shell.dart';

import '../../../../widget/widget_test_viewport.dart';

/// `docs/product/discover/DTL_EVT_01_EVENT_DETAILS_SLICE_SPEC.md` §5 — order,
/// honest metrics, verified badge, empty-section hiding, honest CTA.
void main() {
  final TimezoneRepository timezoneRepository = TimezoneRepositoryImpl();

  PublishedEventDiscoveryEntity fixture({
    bool isFree = true,
    String? externalBookingUrl,
    int? participantsCount = 32,
    PublisherVerificationDisplayState verification =
        PublisherVerificationDisplayState.verifiedPage,
    EventOccurrenceStatus occurrenceStatus = EventOccurrenceStatus.scheduled,
    String coverImageUrl = '',
    List<String> galleryImageUrls = const <String>[],
    String fullDescription =
        'Дружеская встреча для любителей тенниса любого уровня.',
    List<PublishedEventProgramItem> programItems =
        const <PublishedEventProgramItem>[],
  }) {
    const String occurrenceId = 'occ_1';
    return PublishedEventDiscoveryEntity(
      eventId: 'evt_1',
      publisherId: 'pub_1',
      publisherType: 'page',
      publisherName: 'Marine Tennis Club',
      publisherHandle: '@marinetennis',
      publisherVerification: verification,
      title: 'Sunset Tennis Meetup',
      subtitle: 'Friendly tennis at sunset',
      fullDescription: fullDescription,
      category: 'sport_fitness',
      city: 'Дубай',
      coverImageUrl: coverImageUrl,
      galleryImageUrls: galleryImageUrls,
      venueName: 'Marine Tennis Club',
      addressLine: 'Marine Tennis Club, Дубай, ОАЭ',
      latitude: 25.0805,
      longitude: 55.1403,
      distanceKm: 3.2,
      priceAmount: 12,
      isFree: isFree,
      currencyCode: 'EUR',
      externalBookingUrl: externalBookingUrl,
      participantsCount: participantsCount,
      durationMinutes: 150,
      scheduleMode: EventScheduleMode.oneTime,
      occurrences: <EventOccurrence>[
        EventOccurrence(
          id: occurrenceId,
          startAtUtc: DateTime.utc(2026, 6, 21, 14),
          endAtUtc: DateTime.utc(2026, 6, 21, 16, 30),
          status: occurrenceStatus,
        ),
      ],
      displayOccurrenceId: occurrenceId,
      timezoneId: 'Asia/Dubai',
      programItems: programItems,
      publishedAtUtc: DateTime.utc(2026, 5, 1),
    );
  }

  Widget app(
    PublishedEventDiscoveryEntity projection, {
    VoidCallback? onFavoriteTap,
    VoidCallback? onShareTap,
    VoidCallback? onMap,
    Future<void> Function()? onAddToScenario,
    VoidCallback? onOrganizerTap,
    Future<void> Function()? onAddToCalendar,
    Future<void> Function()? onPrimaryAction,
  }) {
    return MaterialApp(
      home: DetailsShell(
        state: DetailsScreenAvailable(
          immersiveHero: true,
          renderer: ObjectOfferDetailsRenderer.event(
            projection: projection,
            timezoneRepository: timezoneRepository,
            isFavorite: false,
            onFavoriteTap: onFavoriteTap ?? () {},
            onShareTap: onShareTap ?? () {},
            onMap: onMap ?? () {},
            onAddToScenario: onAddToScenario ?? () async {},
            onOrganizerTap: onOrganizerTap,
            onAddToCalendar: onAddToCalendar ?? () async {},
            onPrimaryAction: onPrimaryAction ?? () async {},
          ),
        ),
      ),
    );
  }

  fullPageTestWidgets('renders title, occurrence-resolved date/time in the '
      "Event's own timezone, venue and honest metrics", (tester) async {
    await tester.pumpWidget(app(fixture()));
    await tester.pumpAndSettle();

    expect(find.text('Sunset Tennis Meetup'), findsOneWidget);
    // 18:00 Dubai local (UTC+4) for a 14:00 UTC start — never the test
    // runner's own local timezone.
    expect(find.textContaining('18:00–20:30'), findsOneWidget);
    expect(find.text('Marine Tennis Club, Дубай, ОАЭ'), findsOneWidget);
    expect(find.text('32'), findsOneWidget);
    expect(find.text('2.5 ч'), findsOneWidget);
  });

  fullPageTestWidgets('composes Event through the shared Object / Offer visual '
      'primitives', (tester) async {
    await tester.pumpWidget(app(fixture()));
    await tester.pumpAndSettle();

    expect(find.byType(ObjectOfferContentSheet), findsOneWidget);
    expect(find.byType(ObjectOfferMetricsStrip), findsOneWidget);
    expect(find.byType(ObjectOfferCard), findsWidgets);
    expect(find.byType(ObjectOfferStickyActionShell), findsOneWidget);
    expect(find.byType(ObjectOfferHeroActionButton), findsOneWidget);
  });

  fullPageTestWidgets('isFree renders "Бесплатно", never a price/₽0', (
    tester,
  ) async {
    await tester.pumpWidget(app(fixture(isFree: true)));
    await tester.pumpAndSettle();
    expect(find.text('Бесплатно'), findsOneWidget);
  });

  fullPageTestWidgets('unknown participants shows an honest dash with an '
      'accessibility label, never a fake 0', (tester) async {
    await tester.pumpWidget(app(fixture(participantsCount: null)));
    await tester.pumpAndSettle();
    expect(find.text('—'), findsOneWidget);
    // Checked against the `Semantics` widget's own configuration, not the
    // live semantics tree — robust regardless of whether the test binding
    // has a semantics tree attached.
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

  fullPageTestWidgets('verified badge renders only when verification is not '
      'none', (tester) async {
    await tester.pumpWidget(
      app(fixture(verification: PublisherVerificationDisplayState.none)),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.verified), findsNothing);

    await tester.pumpWidget(
      app(
        fixture(verification: PublisherVerificationDisplayState.verifiedPage),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.verified), findsOneWidget);
  });

  fullPageTestWidgets('empty About body hides the whole section, not an '
      'empty card', (tester) async {
    await tester.pumpWidget(app(fixture(fullDescription: '')));
    await tester.pumpAndSettle();
    expect(find.text('О событии'), findsNothing);
  });

  fullPageTestWidgets('"Читать далее" really expands and collapses inline', (
    tester,
  ) async {
    await tester.pumpWidget(app(fixture()));
    await tester.pumpAndSettle();

    expect(find.text('Читать далее'), findsOneWidget);
    await tester.tap(find.text('Читать далее'));
    await tester.pumpAndSettle();
    expect(find.text('Свернуть'), findsOneWidget);
  });

  fullPageTestWidgets('empty programItems hides the Program/Schedule '
      'section entirely', (tester) async {
    await tester.pumpWidget(
      app(fixture(programItems: const <PublishedEventProgramItem>[])),
    );
    await tester.pumpAndSettle();
    expect(find.text('Расписание'), findsNothing);
  });

  fullPageTestWidgets('non-empty programItems render the timeline and the '
      'data-backed Calendar action', (tester) async {
    await tester.pumpWidget(
      app(
        fixture(
          programItems: <PublishedEventProgramItem>[
            PublishedEventProgramItem(
              id: 'p1',
              title: 'Сбор участников и разминка',
              kind: EventProgramItemKind.activity,
              startAtUtc: DateTime.utc(2026, 6, 21, 14),
              endAtUtc: DateTime.utc(2026, 6, 21, 14, 20),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Расписание'), findsOneWidget);
    expect(find.text('Сбор участников и разминка'), findsOneWidget);
    expect(find.text('Добавить в календарь'), findsOneWidget);
  });

  fullPageTestWidgets('Calendar action invokes the provided exporter', (
    tester,
  ) async {
    bool exported = false;
    await tester.pumpWidget(
      app(
        fixture(
          programItems: <PublishedEventProgramItem>[
            PublishedEventProgramItem(
              id: 'p1',
              title: 'Разминка',
              kind: EventProgramItemKind.activity,
              startAtUtc: DateTime.utc(2026, 6, 21, 14),
              endAtUtc: DateTime.utc(2026, 6, 21, 14, 20),
            ),
          ],
        ),
        onAddToCalendar: () async => exported = true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить в календарь'));
    await tester.pump();
    expect(exported, isTrue);
  });

  fullPageTestWidgets('"Показать на карте" invokes the kept Open map action', (
    tester,
  ) async {
    bool mapOpened = false;
    await tester.pumpWidget(app(fixture(), onMap: () => mapOpened = true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Показать на карте'));
    await tester.pump();
    expect(mapOpened, isTrue);
  });

  group('sticky CTA honesty (§0.7)', () {
    fullPageTestWidgets('isFree shows an active "Записаться" CTA', (
      tester,
    ) async {
      await tester.pumpWidget(app(fixture(isFree: true)));
      await tester.pumpAndSettle();
      expect(find.text('Записаться'), findsOneWidget);
    });

    fullPageTestWidgets('priced with a valid externalBookingUrl shows the '
        'CTA', (tester) async {
      await tester.pumpWidget(
        app(
          fixture(
            isFree: false,
            externalBookingUrl: 'https://example.com/book',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Записаться'), findsOneWidget);
    });

    fullPageTestWidgets('priced with no externalBookingUrl hides the CTA '
        'entirely — never a disabled placeholder', (tester) async {
      await tester.pumpWidget(
        app(fixture(isFree: false, externalBookingUrl: null)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Записаться'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    fullPageTestWidgets('tapping the CTA invokes onPrimaryAction', (
      tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        app(
          fixture(isFree: true),
          onPrimaryAction: () async {
            tapped = true;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Записаться'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    fullPageTestWidgets('priced with a non-web URL hides the CTA', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(fixture(isFree: false, externalBookingUrl: 'javascript:alert(1)')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Записаться'), findsNothing);
    });

    fullPageTestWidgets('cancelled occurrence hides Join and Calendar', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          fixture(
            occurrenceStatus: EventOccurrenceStatus.cancelled,
            programItems: <PublishedEventProgramItem>[
              PublishedEventProgramItem(
                id: 'p1',
                title: 'Разминка',
                kind: EventProgramItemKind.activity,
                startAtUtc: DateTime.utc(2026, 6, 21, 14),
                endAtUtc: DateTime.utc(2026, 6, 21, 14, 20),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Отменено'), findsOneWidget);
      expect(find.text('Записаться'), findsNothing);
      expect(find.text('Добавить в календарь'), findsNothing);
    });
  });

  fullPageTestWidgets('Add to Scenario app-bar action invokes the kept '
      'coordinator action', (tester) async {
    bool added = false;
    await tester.pumpWidget(
      app(
        fixture(),
        onAddToScenario: () async {
          added = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.ios_share_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить в сценарий'));
    await tester.pumpAndSettle();
    expect(added, isTrue);
  });

  fullPageTestWidgets('hero counter follows PageView swipes', (tester) async {
    // Exercise the normative 430dp canvas (§7.1). The shared full-page test
    // helper uses an 800dp-wide surface, where a 320dp gesture is correctly
    // below PageView's page-change threshold and therefore tests nothing
    // about the production-sized interaction.
    tester.view.physicalSize = const Size(430, 932);
    await tester.pumpWidget(
      app(
        fixture(
          coverImageUrl: 'https://example.com/cover.jpg',
          galleryImageUrls: const <String>[
            'https://example.com/cover.jpg',
            'https://example.com/second.jpg',
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('1/2'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-320, 0));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
  });

  fullPageTestWidgets('legacy Find similar / Create similar / Mark as '
      'visited never appear for Event', (tester) async {
    await tester.pumpWidget(app(fixture()));
    await tester.pumpAndSettle();
    expect(find.text('Find similar'), findsNothing);
    expect(find.text('Create similar'), findsNothing);
    expect(find.text('Mark as visited'), findsNothing);
    expect(find.text('Plan this recharge'), findsNothing);
  });

  group('at 360dp / 150% text scale (EVT-D-AC-11)', () {
    Future<void> pumpAtNarrowWidthAndLargeTextScale(
      WidgetTester tester,
      Widget home,
    ) async {
      tester.view
        ..physicalSize = const Size(360, 1400)
        ..devicePixelRatio = 1;
      addTearDown(() {
        tester.view
          ..resetPhysicalSize()
          ..resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            );
          },
          home: home,
        ),
      );
    }

    testWidgets('a long title/venue/organizer name renders without '
        'overflow', (tester) async {
      await pumpAtNarrowWidthAndLargeTextScale(
        tester,
        app(
          PublishedEventDiscoveryEntity(
            eventId: 'evt_long',
            publisherId: 'pub_1',
            publisherType: 'page',
            publisherName:
                'Marine Tennis and Padel Club of the Greater Dubai Marina Area',
            publisherHandle: '@marinetennisandpadelclubgreaterdubaimarina',
            publisherVerification:
                PublisherVerificationDisplayState.verifiedPage,
            title:
                'Sunset Tennis and Padel Meetup for Beginners and Advanced Players',
            subtitle: 'Friendly tennis at sunset',
            fullDescription:
                'Дружеская встреча для любителей тенниса любого уровня. '
                'Новые знакомства, игра и отличная атмосфера на закате.',
            category: 'sport_fitness',
            city: 'Дубай',
            venueName:
                'Marine Tennis and Padel Club, West Wing, Dubai Marina Promenade',
            addressLine:
                'Marine Tennis and Padel Club, West Wing, Dubai Marina '
                'Promenade, Дубай, ОАЭ',
            latitude: 25.0805,
            longitude: 55.1403,
            distanceKm: 3.2,
            priceAmount: 12,
            isFree: false,
            currencyCode: 'EUR',
            externalBookingUrl: 'https://example.com/book',
            participantsCount: 32,
            durationMinutes: 150,
            scheduleMode: EventScheduleMode.oneTime,
            occurrences: <EventOccurrence>[
              EventOccurrence(
                id: 'occ_1',
                startAtUtc: DateTime.utc(2026, 6, 21, 14),
                endAtUtc: DateTime.utc(2026, 6, 21, 16, 30),
                status: EventOccurrenceStatus.scheduled,
              ),
            ],
            displayOccurrenceId: 'occ_1',
            timezoneId: 'Asia/Dubai',
            programItems: <PublishedEventProgramItem>[
              PublishedEventProgramItem(
                id: 'p1',
                title:
                    'Сбор участников, разминка и подробный инструктаж по '
                    'технике безопасности на корте',
                kind: EventProgramItemKind.activity,
                startAtUtc: DateTime.utc(2026, 6, 21, 14),
                endAtUtc: DateTime.utc(2026, 6, 21, 14, 20),
              ),
            ],
            publishedAtUtc: DateTime.utc(2026, 5, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('the standard fixture also renders without overflow', (
      tester,
    ) async {
      await pumpAtNarrowWidthAndLargeTextScale(tester, app(fixture()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
