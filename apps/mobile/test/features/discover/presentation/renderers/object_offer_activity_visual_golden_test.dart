import 'package:recharge/shared/primitives/money/money.dart';
import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/time_slot.dart';
import 'package:recharge/features/discover/presentation/renderers/object_offer_details_renderer.dart';
import 'package:recharge/features/discover/presentation/shell/details_shell.dart';

void main() {
  testWidgets(
    'Activity Object / Offer Details has a stable 430x932 reference',
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
            key: const ValueKey<String>('object-offer-activity-golden-surface'),
            child: DetailsShell(
              state: DetailsScreenAvailable(
                immersiveHero: true,
                renderer: ObjectOfferDetailsRenderer.discoverItem(
                  item: _activityFixture(),
                  isFavorite: false,
                  ctaSubmitted: false,
                  onFavoriteTap: () {},
                  onShareTap: () {},
                  onMap: () {},
                  onRouteMap: () {},
                  onAddToScenario: () {},
                  onSearch: () {},
                  onCreateSimilar: () {},
                  onCreateRoute: () {},
                  onMarkVisited: () {},
                  onCtaTap: () {},
                  onReportRoute: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(
          const ValueKey<String>('object-offer-activity-golden-surface'),
        ),
        matchesGoldenFile('goldens/object_offer_activity_reference.png'),
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

DiscoverItemEntity _activityFixture() {
  return DiscoverItemEntity(
    id: 'activity_visual',
    title: 'Утренняя йога в парке',
    subtitle:
        'Мягкая практика, которая помогает проснуться, настроиться на день '
        'и спокойно зарядиться энергией.',
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
    organizerName: 'Recharge Studio',
    organizerHandle: '@recharge',
    venueName: 'Верманский парк',
    addressLine: 'Тербатас iela 2D',
    participantsCount: 8,
    capacity: 12,
    durationMinutes: 60,
    scheduleSlots: <TimeSlot>[
      TimeSlot(
        slotId: 'slot_visual',
        startAtUtc: DateTime.utc(2026, 9, 12, 7),
        endAtUtc: DateTime.utc(2026, 9, 12, 8),
      ),
    ],
    ctaLabel: 'Присоединиться',
    highlights: const <String>['Подходит начинающим', 'Спокойный темп группы'],
  );
}
