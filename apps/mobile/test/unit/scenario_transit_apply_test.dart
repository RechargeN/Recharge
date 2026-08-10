import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/application/scenario_create_coordinator.dart';
import 'package:recharge/features/create/data/models/scenario_draft_mapper.dart';
import 'package:recharge/features/create/domain/entities/scenario_budget_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_item_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_transit_mutation.dart';
import 'package:recharge/features/create/domain/entities/scenario_transit_schedule.dart';

void main() {
  late _Ids ids;
  late ScenarioCreateCoordinator coordinator;

  setUp(() {
    ids = _Ids();
    coordinator = ScenarioCreateCoordinator(idGenerator: ids);
  });

  test('Apply adds one exact official item with permanent locations', () {
    final draft = coordinator.initial(
      timezoneId: 'Europe/Riga',
      currencyCode: 'EUR',
    );

    final result = coordinator.applyTransitSelection(
      draft,
      expectedRevision: draft.revision,
      option: _option(),
    );

    expect(result.accepted, isTrue);
    expect(result.draft.revision, draft.revision + 1);
    expect(result.draft.items, hasLength(1));
    expect(result.draft.locations, hasLength(2));
    expect(result.draft.days.single.itemIds, <String>[result.itemId!]);
    final item = result.draft.items.single;
    final source = item.source as ScenarioPlannedTransportSourceDraft;
    expect(item.id, startsWith('id-'));
    expect(item.startLocationId, startsWith('id-'));
    expect(item.endLocationId, startsWith('id-'));
    expect(item.timeLocked, isTrue);
    expect(item.durationMinutes, 61);
    expect(source.scheduleSnapshot?.tripId, 'trip-1');
    expect(source.scheduleSnapshot?.providerCode, 'provider-a');
    expect(source.scheduleSnapshot?.departureDayOffset, 0);
    expect(source.scheduleSnapshot?.arrivalDayOffset, 0);
  });

  test('revision conflict is byte-stable and consumes no ids', () {
    final draft = coordinator.initial(
      timezoneId: 'Europe/Riga',
      currencyCode: 'EUR',
    );
    final idCount = ids.count;

    final result = coordinator.applyTransitSelection(
      draft,
      expectedRevision: draft.revision - 1,
      option: _option(),
    );

    expect(result.accepted, isFalse);
    expect(result.failure, ScenarioTransitMutationFailure.revisionConflict);
    expect(identical(result.draft, draft), isTrue);
    expect(ids.count, idCount);
  });

  test('Apply rejects a service without safe stop coordinates', () {
    final draft = coordinator.initial(
      timezoneId: 'Europe/Riga',
      currencyCode: 'EUR',
    );

    final result = coordinator.applyTransitSelection(
      draft,
      expectedRevision: draft.revision,
      option: _option(withCoordinates: false),
    );

    expect(result.accepted, isFalse);
    expect(result.failure, ScenarioTransitMutationFailure.invalidSelection);
    expect(identical(result.draft, draft), isTrue);
  });

  test('Replace preserves author fields, item id, day and order', () {
    var draft = coordinator.initial(
      timezoneId: 'Europe/Riga',
      currencyCode: 'EUR',
    );
    final added = coordinator.applyTransitSelection(
      draft,
      expectedRevision: draft.revision,
      option: _option(),
    );
    draft = added.draft;
    final original = draft.items.single;
    const cost = ScenarioCostDraft(
      components: <ScenarioMoneyEstimateDraft>[
        ScenarioMoneyEstimateDraft(
          componentCode: 'ticket',
          knowledge: ScenarioPriceKnowledge.known,
          source: ScenarioPriceSource.userOverride,
          amount: ScenarioMoneyDraft(minorUnits: 1250, currencyCode: 'EUR'),
          basis: ScenarioPriceBasis.perPerson,
        ),
      ],
    );
    final authored = ScenarioItemDraft(
      id: original.id,
      dayId: original.dayId,
      startLocationId: original.startLocationId,
      endLocationId: original.endLocationId,
      kind: original.kind,
      source: original.source,
      sourceStatus: original.sourceStatus,
      schedule: original.schedule,
      durationMinutes: original.durationMinutes,
      cost: cost,
      orderLocked: true,
      timeLocked: true,
      role: ScenarioItemRole.optional,
      selected: false,
      publicNote: 'Buy a quiet coach ticket',
    );
    draft = draft.copyWith(items: <ScenarioItemDraft>[authored]);
    final orderBefore = <String>[...draft.days.single.itemIds];

    final result = coordinator.applyTransitSelection(
      draft,
      expectedRevision: draft.revision,
      option: _option(
        departure: 11 * 3600,
        arrival: 12 * 3600 + 30 * 60,
        sha: 'b' * 64,
      ),
      replaceItemId: authored.id,
    );

    expect(result.accepted, isTrue);
    final replaced = result.draft.items.single;
    expect(replaced.id, authored.id);
    expect(replaced.dayId, authored.dayId);
    expect(result.draft.days.single.itemIds, orderBefore);
    expect(identical(replaced.cost, cost), isTrue);
    expect(replaced.orderLocked, isTrue);
    expect(replaced.timeLocked, isTrue);
    expect(replaced.role, ScenarioItemRole.optional);
    expect(replaced.selected, isFalse);
    expect(replaced.publicNote, 'Buy a quiet coach ticket');
    expect(replaced.durationMinutes, 90);
  });

  test('persisted Apply restores without schedule repository', () {
    final draft = coordinator.initial(
      timezoneId: 'Europe/Riga',
      currencyCode: 'EUR',
    );
    final applied = coordinator.applyTransitSelection(
      draft,
      expectedRevision: draft.revision,
      option: _option(),
    );

    final restored = ScenarioDraftMapper.fromJson(
      ScenarioDraftMapper.toJson(applied.draft),
    );
    final source =
        restored.items.single.source as ScenarioPlannedTransportSourceDraft;

    expect(source.scheduleSnapshot?.tripId, 'trip-1');
    expect(source.scheduleSnapshot?.feedSha256, 'a' * 64);
    expect(restored.locations, hasLength(2));
    expect(restored.items.single.startLocationId, isNotNull);
  });

  test('cross-midnight schedule preserves GTFS service-day offsets', () {
    final draft = coordinator.initial(
      timezoneId: 'Europe/Riga',
      currencyCode: 'EUR',
    );
    final result = coordinator.applyTransitSelection(
      draft,
      expectedRevision: draft.revision,
      option: _option(departure: 25 * 3600, arrival: 26 * 3600),
    );
    final item = result.draft.items.single;
    final planned = item.schedule.planned as ScenarioTemplatePlannedTimeDraft;
    final snapshot =
        (item.source as ScenarioPlannedTransportSourceDraft).scheduleSnapshot!;

    expect(snapshot.departureDayOffset, 1);
    expect(snapshot.arrivalDayOffset, 1);
    expect(planned.startDayIndex, 1);
    expect(planned.endDayIndex, 1);
    expect(planned.windowEndDayOffset, 0);
    expect(planned.windowStart?.hhmm, '01:00');
    expect(planned.windowEnd?.hhmm, '02:00');
  });
}

ScenarioTransitServiceOption _option({
  int departure = 10 * 3600,
  int arrival = 11 * 3600 + 60,
  String? sha,
  bool withCoordinates = true,
}) {
  final origin = ScenarioTransitStop(
    providerCode: 'provider-a',
    id: 'origin',
    name: 'Riga Central',
    latitude: withCoordinates ? 56.9463 : null,
    longitude: withCoordinates ? 24.1204 : null,
  );
  final destination = ScenarioTransitStop(
    providerCode: 'provider-a',
    id: 'destination',
    name: 'Sigulda',
    latitude: withCoordinates ? 57.1537 : null,
    longitude: withCoordinates ? 24.8538 : null,
  );
  return ScenarioTransitServiceOption(
    providerCode: 'provider-a',
    serviceDate: const ScenarioTransitLocalDate(2026, 8, 3),
    tripId: 'trip-1',
    routeId: 'route-1',
    serviceId: 'weekday',
    mode: ScenarioTransitMode.train,
    origin: origin,
    destination: destination,
    departure: ScenarioTransitTime(departure),
    arrival: ScenarioTransitTime(arrival),
    manifest: ScenarioTransitFeedManifest(
      providerCode: 'provider-a',
      providerDisplayName: 'Provider A',
      licenseName: 'CC0 1.0',
      sourceUrl: 'https://example.test/a.zip',
      retrievedAtUtc: DateTime.utc(2026, 8, 3, 8),
      sha256: sha ?? 'a' * 64,
      freshness: ScenarioTransitFreshness.current,
    ),
    agencyName: 'Vivi',
    routeLabel: 'Riga–Sigulda',
  );
}

class _Ids implements IdGenerator {
  int count = 0;

  @override
  String generate() => 'id-${count++}';
}
