import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/event_occurrence.dart';
import 'package:recharge/features/discover/domain/entities/published_event_discovery_entity.dart';
import 'package:recharge/features/discover/domain/entities/published_event_program_item.dart';
import 'package:recharge/features/discover/domain/entities/publisher_verification_display_state.dart';
import 'package:recharge/features/discover/presentation/renderers/object_offer_details_renderer.dart';
import 'package:recharge/features/discover/presentation/shell/details_shell.dart';

void main() {
  testWidgets('Event Object / Offer Details has a stable 430x932 reference', (
    WidgetTester tester,
  ) async {
    await tester.runAsync<void>(_loadGoldenFonts);
    tester.view
      ..physicalSize = const Size(430, 932)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    final ThemeData baseTheme = RechargeTheme.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: baseTheme.copyWith(
          textTheme: baseTheme.textTheme.apply(fontFamily: 'Roboto'),
          primaryTextTheme: baseTheme.primaryTextTheme.apply(
            fontFamily: 'Roboto',
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: _buttonStyleWithFont(baseTheme.filledButtonTheme.style),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: _buttonStyleWithFont(baseTheme.outlinedButtonTheme.style),
          ),
          textButtonTheme: TextButtonThemeData(
            style: _buttonStyleWithFont(baseTheme.textButtonTheme.style),
          ),
        ),
        home: RepaintBoundary(
          key: const ValueKey<String>('object-offer-event-golden-surface'),
          child: DetailsShell(
            state: DetailsScreenAvailable(
              immersiveHero: true,
              renderer: ObjectOfferDetailsRenderer.event(
                projection: _eventFixture(),
                timezoneRepository: TimezoneRepositoryImpl(),
                isFavorite: false,
                onFavoriteTap: () {},
                onShareTap: () {},
                onMap: () {},
                onAddToScenario: () async {},
                onOrganizerTap: () {},
                onAddToCalendar: () async {},
                onPrimaryAction: () async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey<String>('object-offer-event-golden-surface')),
      matchesGoldenFile('goldens/object_offer_event_reference.png'),
    );
  });
}

Future<void> _loadGoldenFonts() async {
  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null || flutterRoot.isEmpty) {
    throw StateError('FLUTTER_ROOT is required for the visual golden test.');
  }
  final String fontRoot = '$flutterRoot/bin/cache/artifacts/material_fonts';
  await (FontLoader('Roboto')
        ..addFont(_fontData('$fontRoot/roboto-regular.ttf'))
        ..addFont(_fontData('$fontRoot/roboto-medium.ttf'))
        ..addFont(_fontData('$fontRoot/roboto-bold.ttf')))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(_fontData('$fontRoot/materialicons-regular.otf'))).load();
}

Future<ByteData> _fontData(String path) async {
  final Uint8List bytes = await File(path).readAsBytes();
  return ByteData.sublistView(bytes);
}

ButtonStyle _buttonStyleWithFont(ButtonStyle? style) {
  final ButtonStyle baseStyle = style ?? const ButtonStyle();
  return baseStyle.copyWith(
    textStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
      return (baseStyle.textStyle?.resolve(states) ?? const TextStyle())
          .copyWith(fontFamily: 'Roboto');
    }),
  );
}

PublishedEventDiscoveryEntity _eventFixture() {
  const String occurrenceId = 'occ_event_visual';
  return PublishedEventDiscoveryEntity(
    eventId: 'evt_visual',
    publisherId: 'publisher_visual',
    publisherType: 'page',
    publisherName: 'Marine Tennis Club',
    publisherHandle: '@marinetennis',
    publisherVerification: PublisherVerificationDisplayState.verifiedPage,
    title: 'Sunset Tennis Meetup',
    subtitle: 'Friendly tennis at sunset',
    fullDescription:
        'Дружеская встреча для любителей тенниса любого уровня. Новые '
        'знакомства, игра и отличная атмосфера на закате. Ракетки доступны '
        'на месте.',
    category: 'sport_fitness',
    city: 'Дубай',
    coverImageUrl: '',
    venueName: 'Marine Tennis Club',
    addressLine: 'Marine Tennis Club, Дубай, ОАЭ',
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
        id: occurrenceId,
        startAtUtc: DateTime.utc(2026, 6, 21, 14),
        endAtUtc: DateTime.utc(2026, 6, 21, 16, 30),
        status: EventOccurrenceStatus.scheduled,
      ),
    ],
    displayOccurrenceId: occurrenceId,
    timezoneId: 'Asia/Dubai',
    programItems: <PublishedEventProgramItem>[
      PublishedEventProgramItem(
        id: 'program_1',
        title: 'Сбор участников и разминка',
        kind: EventProgramItemKind.activity,
        startAtUtc: DateTime.utc(2026, 6, 21, 14),
        endAtUtc: DateTime.utc(2026, 6, 21, 14, 20),
      ),
      PublishedEventProgramItem(
        id: 'program_2',
        title: 'Парные игры и мини-турниры',
        kind: EventProgramItemKind.activity,
        startAtUtc: DateTime.utc(2026, 6, 21, 14, 20),
        endAtUtc: DateTime.utc(2026, 6, 21, 16, 30),
      ),
    ],
    publishedAtUtc: DateTime.utc(2026, 5, 1),
  );
}
