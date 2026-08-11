import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/scenario_transit_disclosure.dart';
import 'package:recharge/features/create/domain/entities/scenario_item_draft.dart';

void main() {
  const build = BuildScenarioTransitDisclosure();

  test('current official snapshot is transparent and never implies live data', () {
    final disclosure = build(_official());

    expect(disclosure.kind, ScenarioTransitDisclosureKind.official);
    expect(disclosure.freshness, ScenarioTransitDisclosureFreshness.current);
    expect(disclosure.providerLabel, 'Official Provider');
    expect(disclosure.licenseLabel, 'CC BY 4.0');
    expect(disclosure.serviceDateLabel, '2026-08-03');
    expect(disclosure.retrievedAtLabel, '2026-08-03T08:00:00.000Z');
    expect(disclosure.digestLabel, 'a' * 64);
    expect(disclosure.statusLabel, contains('not live'));
    expect(disclosure.warnings.join(' '), contains('confirms neither'));
    expect(disclosure.warnings.join(' '), contains('delays nor punctuality'));
  });

  test('stale, unknown and incomplete provenance remain distinct', () {
    expect(
      build(_official(freshness: ScenarioScheduleFreshness.stale)).freshness,
      ScenarioTransitDisclosureFreshness.stale,
    );
    expect(
      build(_official(freshness: ScenarioScheduleFreshness.unknown)).freshness,
      ScenarioTransitDisclosureFreshness.unknown,
    );
    final incomplete = build(
      _official(
        snapshot: const ScenarioScheduleSnapshotDraft(
          freshness: ScenarioScheduleFreshness.current,
          providerCode: 'provider-a',
          providerDisplayName: 'Official Provider',
        ),
      ),
    );
    expect(
      incomplete.freshness,
      ScenarioTransitDisclosureFreshness.unavailable,
    );
    expect(incomplete.statusLabel, contains('saved data retained'));
  });

  test('manual entry is visibly unverified and invents no fare or provenance', () {
    final disclosure = build(
      const ScenarioPlannedTransportSourceDraft(
        publicServiceLabel: 'Bus 12',
        scheduleSnapshot: ScenarioScheduleSnapshotDraft(
          freshness: ScenarioScheduleFreshness.notApplicable,
          providerCode: 'manual',
          plannedDeparture: ScenarioLocalTimeDraft(hour: 9, minute: 30),
        ),
      ),
    );

    expect(disclosure.kind, ScenarioTransitDisclosureKind.manual);
    expect(
      disclosure.freshness,
      ScenarioTransitDisclosureFreshness.notApplicable,
    );
    expect(disclosure.statusLabel, 'Entered manually · not verified');
    expect(disclosure.providerLabel, isNull);
    expect(disclosure.licenseLabel, isNull);
    expect(disclosure.digestLabel, isNull);
    final rendered = <String>[disclosure.statusLabel, ...disclosure.warnings]
        .join(' ')
        .toLowerCase();
    expect(rendered, contains('fare'));
    expect(rendered, contains('unknown'));
    expect(rendered, isNot(contains('€0')));
    expect(rendered, isNot(contains('free fare')));
  });
}

ScenarioPlannedTransportSourceDraft _official({
  ScenarioScheduleFreshness freshness = ScenarioScheduleFreshness.current,
  ScenarioScheduleSnapshotDraft? snapshot,
}) => ScenarioPlannedTransportSourceDraft(
  kind: ScenarioPlannedTransportKind.train,
  publicServiceLabel: 'Riga–Sigulda',
  scheduleSnapshot:
      snapshot ??
      ScenarioScheduleSnapshotDraft(
        freshness: freshness,
        providerCode: 'provider-a',
        providerDisplayName: 'Official Provider',
        licenseName: 'CC BY 4.0',
        tripId: 'trip-1',
        serviceDate: const ScenarioLocalDateDraft(
          year: 2026,
          month: 8,
          day: 3,
        ),
        retrievedAtUtc: DateTime.utc(2026, 8, 3, 8),
        feedSha256: 'a' * 64,
        originLabel: 'Riga Central',
        destinationLabel: 'Sigulda',
        plannedDeparture: const ScenarioLocalTimeDraft(hour: 10, minute: 0),
        plannedArrival: const ScenarioLocalTimeDraft(hour: 11, minute: 0),
      ),
);
