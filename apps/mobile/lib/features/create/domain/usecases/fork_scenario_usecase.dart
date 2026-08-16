import '../../../../core/id/id_generator.dart';
import '../entities/create_draft_entity.dart';
import '../entities/scenario_draft_data.dart';
import '../entities/scenario_item_draft.dart';
import '../entities/scenario_logistics_draft.dart';

class ForkScenarioUseCase {
  const ForkScenarioUseCase(this._idGenerator);

  final IdGenerator _idGenerator;

  CreateDraftEntity call({
    required CreateDraftEntity source,
    required String ownerId,
    required String ownerEmail,
    required String ownerName,
    required DateTime nowUtc,
  }) {
    final scenario = source.scenarioData;
    if (source.objectType != CreateObjectType.scenario || scenario == null) {
      throw const FormatException('Copy source must be a Scenario.');
    }
    if (source.visibility == VisibilityType.private &&
        source.organizerId != ownerId) {
      throw const FormatException('Private Scenario cannot be copied.');
    }

    final dayIds = <String, String>{
      for (final day in scenario.days) day.id: _idGenerator.generate(),
    };
    final locationIds = <String, String>{
      for (final location in scenario.locations)
        location.id: _idGenerator.generate(),
    };
    final itemIds = <String, String>{
      for (final item in scenario.items) item.id: _idGenerator.generate(),
    };
    String? mapped(Map<String, String> ids, String? id) =>
        id == null ? null : ids[id];

    final copiedScenario = scenario.copyWith(
      revision: 0,
      origin: ScenarioOriginDraft(
        type: ScenarioOriginType.publicScenario,
        sourceId: source.id,
        sourceRevision: scenario.revision,
      ),
      days: scenario.days
          .map(
            (day) => ScenarioDayDraft(
              id: dayIds[day.id]!,
              title: day.title,
              dayIndex: day.dayIndex,
              timezoneId: day.timezoneId,
              localDate: day.localDate,
              startLocationId: mapped(locationIds, day.startLocationId),
              endLocationId: mapped(locationIds, day.endLocationId),
              preferredStartTime: day.preferredStartTime,
              preferredEndTime: day.preferredEndTime,
              itemIds: day.itemIds.map((id) => itemIds[id]!).toList(),
            ),
          )
          .toList(),
      locations: scenario.locations
          .map(
            (location) => ScenarioLocationDraft(
              id: locationIds[location.id]!,
              point: location.point,
              title: location.title,
              disclosure: location.disclosure,
              address: location.address,
              marketId: location.marketId,
              regionId: location.regionId,
              timezoneId: location.timezoneId,
              sourceObjectId: location.sourceObjectId,
              sourceObjectType: location.sourceObjectType,
            ),
          )
          .toList(),
      items: scenario.items
          .map(
            (item) => ScenarioItemDraft(
              id: itemIds[item.id]!,
              dayId: mapped(dayIds, item.dayId),
              startLocationId: mapped(locationIds, item.startLocationId),
              endLocationId: mapped(locationIds, item.endLocationId),
              kind: item.kind,
              source: item.source,
              sourceStatus: item.sourceStatus,
              schedule: item.schedule,
              durationMinutes: item.durationMinutes,
              cost: item.cost,
              orderLocked: item.orderLocked,
              timeLocked: item.timeLocked,
              role: item.role,
              alternativeGroupId: item.alternativeGroupId,
              selected: item.selected,
              publicNote: item.publicNote,
            ),
          )
          .toList(),
      unscheduledItemIds: scenario.unscheduledItemIds
          .map((id) => itemIds[id]!)
          .toList(),
      legs: scenario.legs
          .map(
            (leg) => ScenarioLegDraft(
              id: _idGenerator.generate(),
              dayId: dayIds[leg.dayId]!,
              fromItemId: mapped(itemIds, leg.fromItemId),
              toItemId: mapped(itemIds, leg.toItemId),
              fromLocationId: locationIds[leg.fromLocationId]!,
              toLocationId: locationIds[leg.toLocationId]!,
              mode: leg.mode,
              source: leg.source,
              status: leg.status,
              distanceM: leg.distanceM,
              durationMinutes: leg.durationMinutes,
              cost: leg.cost,
              displayPolyline: leg.displayPolyline,
              providerCode: leg.providerCode,
              warningCode: leg.warningCode,
              updatedAtUtc: leg.updatedAtUtc,
              scheduleSnapshot: leg.scheduleSnapshot,
              lockedByUser: leg.lockedByUser,
            ),
          )
          .toList(),
      updatesEnabled: true,
    );
    return source.copyWith(
      id: _idGenerator.generate(),
      basedOnPublishedVersionId: source.id,
      organizerId: ownerId,
      organizerEmail: ownerEmail,
      organizerName: ownerName,
      visibility: VisibilityType.private,
      draftStatus: DraftStatus.draft,
      moderationStatus: ModerationStatus.none,
      publishStatus: PublishStatus.draft,
      scenarioData: copiedScenario,
      createdAtUtc: nowUtc.toUtc(),
      updatedAtUtc: nowUtc.toUtc(),
      clearPublishedAtUtc: true,
    );
  }
}
