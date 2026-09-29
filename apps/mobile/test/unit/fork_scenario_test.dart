import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/scenario_budget_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_draft_data.dart';
import 'package:recharge/features/create/domain/entities/scenario_item_draft.dart';
import 'package:recharge/features/create/domain/usecases/fork_scenario_usecase.dart';

void main() {
  test('public Scenario becomes a private independent copy with new IDs', () {
    final useCase = ForkScenarioUseCase(
      _Ids(<String>['day-copy', 'item-copy-1', 'item-copy-2', 'scenario-copy']),
    );
    final source = _source();

    final copied = useCase(
      source: source,
      ownerId: 'viewer-1',
      ownerEmail: 'viewer@example.test',
      ownerName: 'Viewer',
      nowUtc: DateTime.utc(2026, 8, 10),
    );

    expect(copied.id, 'scenario-copy');
    expect(copied.visibility, VisibilityType.private);
    expect(copied.organizerId, 'viewer-1');
    expect(copied.basedOnPublishedVersionId, source.id);
    expect(copied.scenarioData!.origin!.sourceId, source.id);
    expect(copied.scenarioData!.items.map((item) => item.id), <String>[
      'item-copy-1',
      'item-copy-2',
    ]);
    expect(copied.scenarioData!.days.single.itemIds, <String>[
      'item-copy-1',
      'item-copy-2',
    ]);
    expect(
      copied.scenarioData!.items.map(
        (item) => (item.source as ScenarioCatalogObjectSourceDraft).objectId,
      ),
      everyElement('place-1'),
    );
  });
}

CreateDraftEntity _source() {
  final sourceRef = ScenarioCatalogObjectSourceDraft(
    objectId: 'place-1',
    objectType: ScenarioCatalogObjectType.place,
    snapshot: ScenarioObjectSnapshotDraft(
      title: 'Cafe',
      checkedAtUtc: DateTime.utc(2026, 8, 10),
    ),
  );
  ScenarioItemDraft occurrence(String id) => ScenarioItemDraft(
    id: id,
    dayId: 'day-source',
    kind: ScenarioItemKind.visit,
    source: sourceRef,
    sourceStatus: ScenarioSourceStatus.ready,
    schedule: const ScenarioScheduleDraft(
      mode: ScenarioTimeMode.flexible,
      planned: ScenarioTemplatePlannedTimeDraft(startDayIndex: 0),
    ),
    cost: const ScenarioCostDraft(),
    orderLocked: false,
    timeLocked: false,
    role: ScenarioItemRole.mandatory,
    selected: true,
    publicNote: '',
  );
  return CreateDraftEntity.defaults(
    organizerId: 'publisher-1',
    organizerEmail: 'publisher@example.test',
    organizerName: 'Publisher',
    marketCityId: 'latvia',
    timezone: 'Europe/Riga',
    country: 'LV',
    city: 'Riga',
    currency: 'EUR',
  ).copyWith(
    id: 'scenario-public',
    objectType: CreateObjectType.scenario,
    title: 'Cafe day',
    clearEventData: true,
    visibility: VisibilityType.public,
    scenarioData: ScenarioDraftData.defaults().copyWith(
      revision: 7,
      days: const <ScenarioDayDraft>[
        ScenarioDayDraft(
          id: 'day-source',
          title: 'Day 1',
          dayIndex: 0,
          itemIds: <String>['item-source-1', 'item-source-2'],
        ),
      ],
      items: <ScenarioItemDraft>[
        occurrence('item-source-1'),
        occurrence('item-source-2'),
      ],
    ),
  );
}

class _Ids implements IdGenerator {
  _Ids(this.values);
  final List<String> values;

  @override
  String generate() => values.removeAt(0);
}
