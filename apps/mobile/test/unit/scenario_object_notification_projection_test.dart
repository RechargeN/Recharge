import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/application/project_scenario_object_notifications.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/scenario_budget_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_draft_data.dart';
import 'package:recharge/features/create/domain/entities/scenario_item_draft.dart';
import 'package:recharge/features/notifications/domain/entities/notification_item_entity.dart';

void main() {
  const project = ProjectScenarioObjectNotifications();
  final update = ScenarioObjectUpdate(
    updateId: 'hours-v2',
    subjectRef: NotificationSubjectRef(
      kind: NotificationSubjectKind.place,
      id: 'place-1',
    ),
    title: 'Hours changed',
    body: 'Check this stop',
    createdAtUtc: _now,
  );

  test('same object in morning and evening produces two notifications', () {
    final notifications = project(scenarioDraft: _draft(), update: update);
    expect(notifications, hasLength(2));
    expect(
      notifications.map((item) => item.scenarioContext!.scenarioItemId),
      <String>['morning', 'evening'],
    );
    expect(notifications.map((item) => item.subjectRef!.id).toSet(), {
      'place-1',
    });
  });

  test('updates-off is independent from lifecycle and emits nothing', () {
    final disabled = _draft().copyWith(
      scenarioData: _draft().scenarioData!.copyWith(updatesEnabled: false),
    );
    expect(project(scenarioDraft: disabled, update: update), isEmpty);
  });
}

final _now = DateTime.utc(2026, 8, 10);

CreateDraftEntity _draft() {
  final source = ScenarioCatalogObjectSourceDraft(
    objectId: 'place-1',
    objectType: ScenarioCatalogObjectType.place,
    snapshot: ScenarioObjectSnapshotDraft(title: 'Cafe', checkedAtUtc: _now),
  );
  ScenarioItemDraft item(String id) => ScenarioItemDraft(
    id: id,
    dayId: 'day-1',
    kind: ScenarioItemKind.visit,
    source: source,
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
    organizerId: 'owner-1',
    organizerEmail: 'owner@example.test',
    organizerName: 'Owner',
    marketCityId: 'latvia',
    timezone: 'Europe/Riga',
    country: 'LV',
    city: 'Riga',
    currency: 'EUR',
  ).copyWith(
    id: 'scenario-1',
    objectType: CreateObjectType.scenario,
    clearEventData: true,
    scenarioData: ScenarioDraftData.defaults().copyWith(
      days: const <ScenarioDayDraft>[
        ScenarioDayDraft(
          id: 'day-1',
          title: 'Day 1',
          dayIndex: 0,
          itemIds: <String>['morning', 'evening'],
        ),
      ],
      items: <ScenarioItemDraft>[item('morning'), item('evening')],
    ),
  );
}
