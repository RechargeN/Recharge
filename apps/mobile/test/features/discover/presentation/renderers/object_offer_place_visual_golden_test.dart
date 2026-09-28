import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/opening_hours_rule.dart';
import 'package:recharge/features/discover/presentation/renderers/object_offer_details_renderer.dart';
import 'package:recharge/features/discover/presentation/shell/details_shell.dart';

void main() {
  testWidgets('Place Object / Offer Details has a stable 430x932 reference', (
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
        ),
        home: RepaintBoundary(
          key: const ValueKey<String>('object-offer-place-golden-surface'),
          child: DetailsShell(
            state: DetailsScreenAvailable(
              immersiveHero: true,
              renderer: ObjectOfferDetailsRenderer.discoverItem(
                item: _placeFixture(),
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
      find.byKey(const ValueKey<String>('object-offer-place-golden-surface')),
      matchesGoldenFile('goldens/object_offer_place_reference.png'),
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

DiscoverItemEntity _placeFixture() {
  return DiscoverItemEntity(
    id: 'place_visual',
    title: 'Оранжерея Верманского сада',
    subtitle:
        'Тихая городская оранжерея с сезонной экспозицией, редкими '
        'растениями и местом для спокойного отдыха.',
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
    organizerName: 'Riga City Gardens',
    organizerHandle: '@rigagardens',
    venueName: 'Верманский сад',
    addressLine: 'Тербатас iela 2D',
    durationMinutes: 90,
    openingHours: <OpeningHoursRule>[
      OpeningHoursRule(
        dayOfWeek: DayOfWeek.monday,
        isClosedAllDay: false,
        openMinutesSinceLocalMidnight: 600,
        closeMinutesSinceLocalMidnight: 1140,
      ),
    ],
    ctaLabel: 'Открыть сайт',
    highlights: const <String>['Редкие растения', 'Доступная среда'],
  );
}
