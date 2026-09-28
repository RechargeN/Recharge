import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/published_find_people_discovery_entity.dart';
import 'package:recharge/features/discover/domain/entities/publisher_verification_display_state.dart';
import 'package:recharge/features/discover/presentation/renderers/object_offer_details_renderer.dart';
import 'package:recharge/features/discover/presentation/shell/details_shell.dart';

void main() {
  testWidgets(
    'Find People Object / Offer Details has a stable 430x932 reference',
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
              'object-offer-find-people-golden-surface',
            ),
            child: DetailsShell(
              state: DetailsScreenAvailable(
                immersiveHero: true,
                renderer: ObjectOfferDetailsRenderer.findPeople(
                  projection: _findPeopleFixture(),
                  timezoneRepository: TimezoneRepositoryImpl(),
                  onShareTap: () {},
                  onMap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(
          const ValueKey<String>('object-offer-find-people-golden-surface'),
        ),
        matchesGoldenFile('goldens/object_offer_find_people_reference.png'),
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

PublishedFindPeopleDiscoveryEntity _findPeopleFixture() {
  return PublishedFindPeopleDiscoveryEntity(
    requestId: 'fp_1',
    occurrenceId: 'fp_occ_1',
    publisherId: 'user_anna_runs',
    publisherType: 'user',
    publisherName: 'Анна К.',
    publisherHandle: '@anna_runs',
    publisherVerification: PublisherVerificationDisplayState.verifiedCreator,
    title: 'Утренняя пробежка в парке',
    purposeLabel: 'Найти партнёров для утренней пробежки',
    fullDescription:
        'Ищу компанию для регулярных утренних пробежек по парку. Темп '
        'спокойный, для новичков подходит. Встречаемся у фонтана и бежим '
        'вдоль канала.',
    category: 'sport_fitness',
    subcategory: 'running',
    scheduleMode: PublishedFindPeopleScheduleMode.single,
    timeOptions: <PublishedFindPeopleTimeOption>[
      PublishedFindPeopleTimeOption(
        id: 'slot_1',
        startAtUtc: DateTime.utc(2026, 9, 12, 5),
        endAtUtc: DateTime.utc(2026, 9, 12, 6),
        kind: PublishedFindPeopleTimeOptionKind.confirmed,
      ),
    ],
    timezoneId: 'Europe/Riga',
    durationMinutes: 60,
    currentGroupSize: 3,
    targetGroupSize: 6,
    remainingSeats: 3,
    recruitmentStatus: PublishedFindPeopleRecruitmentStatus.open,
    skillLevelLabel: 'Новички и продолжающие',
    paceLabel: 'Спокойный темп',
    languageLabels: const <String>['Русский', 'English'],
    publicRequirements: const <String>['Базовый уровень бега'],
    equipmentNote: 'Своя обувь для бега',
    costType: PublishedFindPeopleCostType.free,
    costNote: 'Участие и ожидаемые обязательные расходы — 0',
    publicLocation: PublishedFindPeoplePointLocation(
      meetingMode: PublishedFindPeopleMeetingMode.inPerson,
      areaLabel: 'Верманский парк, Рига',
      latitude: 56.9537,
      longitude: 24.1138,
    ),
    publishedAtUtc: DateTime.utc(2026, 9, 1),
  );
}
