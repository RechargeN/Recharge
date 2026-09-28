import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/presentation/renderers/object_offer_details_renderer.dart';
import 'package:recharge/features/discover/domain/entities/published_class_workshop_discovery_entity.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import '../../../../fixtures/class_workshop_details_fixture.dart';
import 'package:recharge/features/discover/presentation/shell/details_shell.dart';

void main() {
  for (final infoOnly in [false, true]) {
    testWidgets('Class / Workshop 430x932 reference (info-only: $infoOnly)', (
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
            key: const ValueKey<String>(
              'object-offer-class-workshop-golden-surface',
            ),
            child: DetailsShell(
              state: DetailsScreenAvailable(
                immersiveHero: true,
                renderer: ObjectOfferDetailsRenderer.classWorkshop(
                  projection: classWorkshopFixture(
                    enrollment: infoOnly
                        ? const ClassWorkshopInformationOnly(
                            ClassWorkshopInformationReason.notProvided,
                          )
                        : null,
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
          const ValueKey<String>('object-offer-class-workshop-golden-surface'),
        ),
        matchesGoldenFile(
          infoOnly
              ? 'goldens/object_offer_class_workshop_info_reference.png'
              : 'goldens/object_offer_class_workshop_reference.png',
        ),
      );
    });
  }
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
