import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/saved_search_entity.dart';
import 'package:recharge/features/discover/presentation/pages/discover_map_page.dart';
import 'package:recharge/generated/l10n/app_localizations.dart';

// A34 (2026-11-24, stage build): on the Map screen every "Сохранено на карте"
// card showed "BOTTOM OVERFLOWED BY 19 PIXELS": the Russian "Применить" wrapped
// to two lines inside the fixed-height card. The card must fit in every app
// language and at enlarged system font sizes.
void main() {
  final search = SavedSearchEntity(
    id: 'saved_001',
    title: 'N4bstagingN4bN4bstagingstaging',
    subtitle: '5 km',
    query: DiscoverQuery.defaults(),
    createdAtUtc: DateTime.utc(2026, 11, 24),
  );

  for (final locale in const ['ru', 'lv', 'en']) {
    for (final scale in const [1.0, 1.15, 1.3]) {
      testWidgets('saved card fits: $locale, text x$scale', (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 2.625;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery.withClampedTextScaling(
              minScaleFactor: scale,
              maxScaleFactor: scale,
              child: Scaffold(
                body: MapSavedIntentShelf(
                  savedSearches: [search],
                  smartSearchHistory: const [],
                  onApplySavedSearch: (_) {},
                  onCreateSavedSearch: (_) {},
                  onRouteSavedSearch: (_) {},
                  onApplySmartSearch: (_) {},
                  onCreateSmartSearch: (_) {},
                  onRouteSmartSearch: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
