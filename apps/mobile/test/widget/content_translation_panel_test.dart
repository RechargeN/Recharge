import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/domain/repositories/content_translation_port.dart';
import 'package:recharge/features/discover/presentation/widgets/content_translation_panel.dart';
import 'package:recharge/generated/l10n/app_localizations.dart';

const String _longTitle =
    'A very long machine translated title that has to wrap on a narrow screen';

final class _FakePort implements ContentTranslationPort {
  _FakePort({this.offered = const ContentTranslationAvailable(), this.failure});

  final ContentTranslationOffer offered;
  final String? failure;
  int translateCalls = 0;
  Completer<void>? gate;
  final List<String> targets = <String>[];

  @override
  Future<ContentTranslationOffer> offer({
    required String contentId,
    required String publishedRevisionId,
    required String targetLocale,
  }) async => offered;

  @override
  Future<ContentTranslation> translate({
    required String contentId,
    required String publishedRevisionId,
    required String targetLocale,
  }) async {
    translateCalls += 1;
    targets.add(targetLocale);
    await gate?.future;
    final String? code = failure;
    if (code != null) throw ContentTranslationFailure(code);
    return ContentTranslation(
      sourceLocale: 'lv',
      targetLocale: targetLocale,
      title: _longTitle,
      shortDescription: '<b>not markup</b> short',
      fullDescription: 'Full text',
    );
  }
}

Widget _host(
  ContentTranslationPort port, {
  String locale = 'en',
  double textScale = 1,
  double width = 360,
}) {
  return MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: width,
            child: Column(
              children: <Widget>[
                const Text('Original text'),
                ContentTranslationPanel(
                  port: port,
                  contentId: 'content-1',
                  publishedRevisionId: 'revision-1',
                  targetLocale: locale,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  const Key action = Key('content-translation-action');
  const Key label = Key('content-translation-label');
  const Key showOriginal = Key('content-translation-show-original');
  const Key failureText = Key('content-translation-failure');

  testWidgets('nothing to offer: no button and no space', (tester) async {
    await tester.pumpWidget(
      _host(_FakePort(offered: const ContentTranslationUnavailable())),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(action), findsNothing);
    expect(tester.getSize(find.byType(ContentTranslationPanel)).height, 0);
    expect(find.text('Original text'), findsOneWidget);
  });

  for (final (String locale, String button, String labelText, String original)
      in <(String, String, String, String)>[
        ('en', 'Translate', 'Translated automatically', 'Show original'),
        ('lv', 'Tulkot', 'Tulkots automātiski', 'Rādīt oriģinālu'),
        ('ru', 'Перевести', 'Переведено автоматически', 'Показать оригинал'),
      ]) {
    testWidgets('$locale: offer, loading, labeled result, back to original', (
      tester,
    ) async {
      final _FakePort port = _FakePort()..gate = Completer<void>();
      await tester.pumpWidget(_host(port, locale: locale));
      await tester.pumpAndSettle();
      expect(find.text(button), findsOneWidget);

      await tester.tap(find.byKey(action));
      await tester.pump();
      expect(
        find.byKey(const Key('content-translation-loading')),
        findsOneWidget,
      );
      expect(find.text('Original text'), findsOneWidget);

      port.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text(labelText), findsOneWidget);
      expect(find.text(original), findsOneWidget);
      expect(find.text('Original text'), findsOneWidget);
      expect(port.targets, <String>[locale]);

      await tester.tap(find.byKey(showOriginal));
      await tester.pumpAndSettle();
      expect(find.byKey(label), findsNothing);
      expect(find.text('Original text'), findsOneWidget);

      // The translation stays in this screen's memory: no second request.
      await tester.tap(find.byKey(action));
      await tester.pumpAndSettle();
      expect(find.byKey(label), findsOneWidget);
      expect(port.translateCalls, 1);
    });
  }

  testWidgets('a kept publication translation shows at once, labeled', (
    tester,
  ) async {
    final _FakePort port = _FakePort(
      offered: const ContentTranslationReady(
        ContentTranslation(
          sourceLocale: 'lv',
          targetLocale: 'en',
          title: 'Kept translation',
        ),
      ),
    );
    await tester.pumpWidget(_host(port));
    await tester.pumpAndSettle();
    expect(find.text('Kept translation'), findsOneWidget);
    expect(find.byKey(label), findsOneWidget);
    expect(find.text('Original text'), findsOneWidget);
    expect(port.translateCalls, 0);
    await tester.tap(find.byKey(showOriginal));
    await tester.pumpAndSettle();
    expect(find.byKey(label), findsNothing);
    await tester.tap(find.byKey(action));
    await tester.pumpAndSettle();
    expect(find.text('Kept translation'), findsOneWidget);
    expect(port.translateCalls, 0);
  });

  testWidgets('the result is plain text, with no active markup', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_FakePort()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(action));
    await tester.pumpAndSettle();
    expect(find.text('<b>not markup</b> short'), findsOneWidget);
  });

  for (final (String code, String message) in <(String, String)>[
    (
      'quota_exceeded',
      'Translation limit reached for today. Try again tomorrow.',
    ),
    ('budget_exhausted', 'Translation is temporarily unavailable.'),
    ('provider_unavailable', 'Could not translate. The original is shown.'),
    (
      'revision_changed',
      'This publication has been updated. Refresh the page.',
    ),
    ('translation_disabled', 'Translation is not available right now.'),
  ]) {
    testWidgets('$code leaves the original and a localized message', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_FakePort(failure: code)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(action));
      await tester.pumpAndSettle();
      expect(find.byKey(failureText), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(find.text('Original text'), findsOneWidget);
      expect(find.byKey(label), findsNothing);
      expect(find.byKey(action), findsOneWidget);
    });
  }

  for (final String locale in <String>['en', 'lv', 'ru']) {
    testWidgets('$locale at 360 dp and text ×2 does not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(_FakePort(), locale: locale, textScale: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(action));
      await tester.pumpAndSettle();
      expect(find.byKey(label), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
