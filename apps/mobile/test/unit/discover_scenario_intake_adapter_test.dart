import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/adapters/discover_scenario_intake_adapter.dart';
import 'package:recharge/features/create/domain/entities/scenario_item_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_object_intake.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/money.dart';

void main() {
  const adapter = DiscoverScenarioIntakeAdapter();

  test('Details event becomes one fixed dated Scenario candidate', () {
    final intent = adapter.toDetailsIntent(
      item: _item(kind: DiscoverObjectKind.event),
      intentId: 'intent-1',
      requesterId: 'user-1',
      checkedAtUtc: DateTime.utc(2026, 8, 3, 12),
    );

    final candidate = intent.candidates.single;
    final planned =
        candidate.schedule!.planned as ScenarioDatedPlannedTimeDraft;
    expect(intent.sourceSurface, ScenarioIntakeSourceSurface.details);
    expect(candidate.ref.objectId, 'object-1');
    expect(candidate.ref.objectType, ScenarioCatalogObjectType.event);
    expect(candidate.snapshot.title, 'Latgale concert');
    expect(candidate.snapshot.durationMinutes, 90);
    expect(candidate.snapshot.coverMediaId, isNull);
    expect(candidate.location!.disclosure, ScenarioLocationDisclosure.public);
    expect(candidate.location!.timezoneId, 'Europe/Riga');
    expect(planned.fixedStartAtUtc, DateTime.utc(2026, 8, 8, 17));
    expect(planned.fixedEndAtUtc, DateTime.utc(2026, 8, 8, 18, 30));
  });

  test('Details place remains flexible and maps exact catalog type', () {
    final intent = adapter.toDetailsIntent(
      item: _item(kind: DiscoverObjectKind.place),
      intentId: 'intent-2',
      requesterId: 'user-1',
      checkedAtUtc: DateTime.utc(2026, 8, 3),
    );

    final candidate = intent.candidates.single;
    expect(candidate.ref.objectType, ScenarioCatalogObjectType.place);
    expect(candidate.schedule, isNull);
    expect(candidate.location!.address, 'Atbrivosanas aleja 93');
  });

  test('Search batch preserves tap order and copies no search context', () {
    final first = _item(kind: DiscoverObjectKind.place);
    final second = DiscoverItemEntity(
      id: 'object-2',
      title: 'Second stop',
      subtitle: 'Result ranked first later',
      city: 'Riga',
      category: 'food',
      startsAtUtc: DateTime.utc(2026, 8, 8, 19),
      latitude: 56.95,
      longitude: 24.11,
      price: const Money(minorUnits: 500, currency: CurrencyCode.eur),
      distanceKm: 2,
      isFree: false,
      objectKind: DiscoverObjectKind.activity,
    );

    final intent = adapter.toIntent(
      items: <DiscoverItemEntity>[second, first],
      sourceSurface: ScenarioIntakeSourceSurface.search,
      intentId: 'intent-search',
      requesterId: 'user-1',
      checkedAtUtc: DateTime.utc(2026, 8, 3),
    );

    expect(intent.sourceSurface, ScenarioIntakeSourceSurface.search);
    expect(
      intent.candidates.map((candidate) => candidate.ref.objectId),
      <String>['object-2', 'object-1'],
    );
    expect(intent.candidates, hasLength(2));
  });

  test('Map batch rejects duplicates and unusable locations before intent', () {
    final item = _item(kind: DiscoverObjectKind.place);
    expect(
      () => adapter.toIntent(
        items: <DiscoverItemEntity>[item, item],
        sourceSurface: ScenarioIntakeSourceSurface.map,
        intentId: 'intent-map',
        requesterId: 'user-1',
        checkedAtUtc: DateTime.utc(2026, 8, 3),
      ),
      throwsFormatException,
    );
    final invalid = DiscoverItemEntity(
      id: 'invalid',
      title: 'Invalid location',
      subtitle: '',
      city: 'Riga',
      category: 'place',
      startsAtUtc: DateTime.utc(2026, 8, 3),
      latitude: 95,
      longitude: 24.1,
      price: const Money.zero(CurrencyCode.eur),
      distanceKm: 0,
      isFree: true,
      objectKind: DiscoverObjectKind.place,
    );
    expect(adapter.supportIssue(invalid), contains('no usable'));
  });
}

DiscoverItemEntity _item({required DiscoverObjectKind kind}) =>
    DiscoverItemEntity(
      id: 'object-1',
      title: 'Latgale concert',
      subtitle: 'Evening music',
      city: 'Rezekne',
      category: 'music',
      startsAtUtc: DateTime.utc(2026, 8, 8, 17),
      latitude: 56.5099,
      longitude: 27.3332,
      price: const Money(minorUnits: 1200, currency: CurrencyCode.eur),
      distanceKm: 1.2,
      isFree: false,
      objectKind: kind,
      coverImageUrl: 'https://example.test/cover.jpg',
      venueName: 'GORS',
      addressLine: 'Atbrivosanas aleja 93',
      marketCityId: 'rezekne',
      timezoneId: 'Europe/Riga',
      durationMinutes: 90,
    );
