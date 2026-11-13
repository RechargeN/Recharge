import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/localization/l10n_context.dart';

import 'l10n_screenshot.dart';

/// L4.6: one screen checked in every UI language at 360 dp, at 100% and
/// 200% text. A pass means the layout holds; it says nothing about the
/// quality of the lv/ru wording.
void l10nSmallScreenTestWidgets(
  String description,
  Future<void> Function(WidgetTester tester, Locale locale, double scale) body,
) {
  for (final String language in const <String>['en', 'lv', 'ru']) {
    for (final double scale in const <double>[1, 2]) {
      testWidgets('$description: $language at ${scale}x 360 dp', (
        WidgetTester tester,
      ) async {
        tester.view
          ..physicalSize = const Size(360, 800)
          ..devicePixelRatio = 1;
        addTearDown(() {
          tester.view
            ..resetPhysicalSize()
            ..resetDevicePixelRatio();
        });
        await body(tester, Locale(language), scale);
        await l10nCaptureIfNone(tester);
        expect(tester.takeException()?.toString(), isNull);
      });
    }
  }
}

/// The localization delegates of the app, so `context.l10n` follows [locale].
const List<LocalizationsDelegate<Object>> l10nTestDelegates =
    <LocalizationsDelegate<Object>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];

/// The app's UI languages.
const List<Locale> l10nTestLocales = AppLocalizations.supportedLocales;

/// Applies the text [scale] under the app's [MaterialApp].
TransitionBuilder l10nTestScaleBuilder(double scale) {
  return (BuildContext context, Widget? child) {
    final MediaQueryData media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    );
  };
}

/// A [MaterialApp] in [locale] at text [scale] showing [home].
Widget l10nTestApp({
  required Locale locale,
  required double scale,
  required Widget home,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: l10nTestLocales,
    localizationsDelegates: l10nTestDelegates,
    builder: l10nTestScaleBuilder(scale),
    home: home,
  );
}

/// Scrolls the first scrollable to its end so lazily built rows are laid
/// out too; any overflow on the way fails the test. With
/// `L10N_SHOTS_DIR` set, each screenful is also saved for the review.
Future<void> l10nScrollThrough(WidgetTester tester, {int pages = 12}) async {
  final Finder scrollable = find.byType(Scrollable).first;
  await l10nCaptureScreen(tester, suffix: 'p0');
  for (int page = 0; page < pages; page++) {
    if (scrollable.evaluate().isEmpty) return;
    final double before = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;
    await tester.drag(scrollable, const Offset(0, -600), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException()?.toString(), isNull);
    final double after = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;
    if (after == before) return;
    await l10nCaptureScreen(tester, suffix: 'p${page + 1}');
  }
}

/// The strings of [locale], for expectations that do not hard-code wording.
AppLocalizations l10nFor(Locale locale) => lookupAppLocalizations(locale);
