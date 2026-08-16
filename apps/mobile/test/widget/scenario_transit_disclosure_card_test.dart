import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/scenario_transit_disclosure.dart';
import 'package:recharge/features/create/presentation/widgets/scenario/scenario_transit_disclosure_card.dart';

void main() {
  testWidgets('long unavailable disclosure fits narrow large-text layout', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: ScenarioTransitDisclosureCard(
                disclosure: ScenarioTransitDisclosure(
                  kind: ScenarioTransitDisclosureKind.official,
                  freshness: ScenarioTransitDisclosureFreshness.unavailable,
                  title: 'Regional train with a deliberately long label',
                  statusLabel:
                      'Provenance or feed unavailable · saved data retained',
                  providerLabel: 'Official Provider',
                  serviceDateLabel: '2026-08-03',
                  departureLabel: '10:00',
                  arrivalLabel: '11:00',
                  warnings: <String>[
                    'Planned schedule · not live.',
                    'The saved item remains available, but its official provenance or feed cannot be verified.',
                    BuildScenarioTransitDisclosure.limitations,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('saved data retained'), findsOneWidget);
    expect(find.text('Feed SHA-256: unknown'), findsOneWidget);
    expect(find.textContaining('not live'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
