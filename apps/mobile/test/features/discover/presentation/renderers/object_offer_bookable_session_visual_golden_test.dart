import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/bookable_session_schedule_evaluation.dart';
import 'package:recharge/features/discover/domain/entities/published_bookable_session_discovery_entity.dart';
import 'package:recharge/features/discover/domain/entities/publisher_verification_display_state.dart';
import 'package:recharge/features/discover/presentation/renderers/object_offer_details_renderer.dart';
import 'package:recharge/features/discover/presentation/shell/details_shell.dart';

void main() {
  testWidgets(
    'Bookable Session Object / Offer Details has a stable 430x932 reference',
    (WidgetTester tester) async {
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
          ),
          home: RepaintBoundary(
            key: const ValueKey<String>(
              'object-offer-bookable-session-golden-surface',
            ),
            child: DetailsShell(
              state: DetailsScreenAvailable(
                immersiveHero: true,
                renderer: ObjectOfferDetailsRenderer.bookableSession(
                  projection: _bookableSessionFixture(),
                  scheduleEvaluation: BookableSessionScheduleEvaluation(
                    state: BookableSessionScheduleState.freshWithOffers,
                    visibleOffers: _bookableSessionFixture().schedule.offers,
                  ),
                  timezoneRepository: TimezoneRepositoryImpl(),
                  onShareTap: () {},
                  onMap: () {},
                  onPrimaryAction: () async {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(
          const ValueKey<String>(
            'object-offer-bookable-session-golden-surface',
          ),
        ),
        matchesGoldenFile(
          'goldens/object_offer_bookable_session_reference.png',
        ),
      );
    },
  );
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

PublishedBookableSessionDiscoveryEntity _bookableSessionFixture() {
  return PublishedBookableSessionDiscoveryEntity(
    sessionId: 'session_golden',
    publisherId: 'page_dmitry_fit',
    publisherType: 'page',
    publisherName: 'Дмитрий Волков',
    publisherHandle: '@dmitry_fit',
    publisherVerification: PublisherVerificationDisplayState.verifiedPage,
    title: 'Индивидуальная тренировка',
    resourceName: 'Зал персональных тренировок',
    category: 'sport_fitness',
    subcategory: 'personal_training',
    serviceCategoryLabel: 'Персональная тренировка',
    durationMinutes: 60,
    maxPartySize: 1,
    priceType: PublishedBookableSessionPriceType.fixed,
    priceAmountMinor: 4000,
    currencyCode: 'EUR',
    fullDescription:
        'Индивидуальная тренировка под ваши цели: разбор техники, план '
        'нагрузки и обратная связь после каждого занятия. Подходит как '
        'новичкам, так и опытным спортсменам.',
    timezoneId: 'Europe/Riga',
    schedule: PublishedBookableSessionScheduleSnapshot(
      scheduleRevision: 1,
      generatedAtUtc: DateTime.utc(2026, 9, 7, 10),
      validUntilUtc: DateTime.utc(2026, 9, 7, 11),
      offers: <PublishedBookableSessionOffer>[
        PublishedBookableSessionOffer(
          slotKey: 'golden_slot_1',
          startAtUtc: DateTime.utc(2026, 9, 12, 15),
          endAtUtc: DateTime.utc(2026, 9, 12, 16),
          timezoneId: 'Europe/Riga',
        ),
        PublishedBookableSessionOffer(
          slotKey: 'golden_slot_2',
          startAtUtc: DateTime.utc(2026, 9, 13, 8),
          endAtUtc: DateTime.utc(2026, 9, 13, 9),
          timezoneId: 'Europe/Riga',
        ),
      ],
    ),
    publicLocation: PublishedBookableSessionPointLocation(
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
