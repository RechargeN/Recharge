import '../../features/create/domain/entities/scenario_item_draft.dart';
import '../../features/create/domain/entities/scenario_object_intake.dart';
import '../../features/discover/domain/entities/discover_item_entity.dart';

class DiscoverScenarioIntakeAdapter {
  const DiscoverScenarioIntakeAdapter();

  String? supportIssue(DiscoverItemEntity item) {
    if (item.id.trim().isEmpty ||
        item.id.trim() != item.id ||
        item.title.trim().isEmpty) {
      return 'This result is missing a stable catalog identity.';
    }
    if (!item.latitude.isFinite ||
        !item.longitude.isFinite ||
        item.latitude < -90 ||
        item.latitude > 90 ||
        item.longitude < -180 ||
        item.longitude > 180) {
      return 'This result has no usable catalog location.';
    }
    return null;
  }

  ScenarioObjectIntakeIntent toIntent({
    required List<DiscoverItemEntity> items,
    required ScenarioIntakeSourceSurface sourceSurface,
    required String intentId,
    required String requesterId,
    required DateTime checkedAtUtc,
  }) {
    if (items.isEmpty || items.length > 20) {
      throw const FormatException('Scenario intake requires 1 to 20 items.');
    }
    final refs = <ScenarioObjectRef>{};
    final candidates = <ScenarioIntakeCandidate>[];
    for (final item in items) {
      final issue = supportIssue(item);
      if (issue != null) throw FormatException(issue);
      final candidate = _toCandidate(item, checkedAtUtc.toUtc());
      if (!refs.add(candidate.ref)) {
        throw const FormatException('Duplicate Scenario intake object.');
      }
      candidates.add(candidate);
    }
    return ScenarioObjectIntakeIntent(
      contractVersion: ScenarioObjectIntakeIntent.currentContractVersion,
      intentId: intentId,
      requesterId: requesterId,
      sourceSurface: sourceSurface,
      candidates: candidates,
    );
  }

  ScenarioObjectIntakeIntent toDetailsIntent({
    required DiscoverItemEntity item,
    required String intentId,
    required String requesterId,
    required DateTime checkedAtUtc,
  }) {
    return toIntent(
      items: <DiscoverItemEntity>[item],
      sourceSurface: ScenarioIntakeSourceSurface.details,
      intentId: intentId,
      requesterId: requesterId,
      checkedAtUtc: checkedAtUtc,
    );
  }

  ScenarioIntakeCandidate _toCandidate(
    DiscoverItemEntity item,
    DateTime checkedAtUtc,
  ) {
    final objectType = switch (item.objectKind) {
      DiscoverObjectKind.place => ScenarioCatalogObjectType.place,
      DiscoverObjectKind.event => ScenarioCatalogObjectType.event,
      DiscoverObjectKind.route => ScenarioCatalogObjectType.route,
      DiscoverObjectKind.activity => ScenarioCatalogObjectType.activity,
    };
    final duration = item.durationMinutes;
    final fixedEnd = duration == null
        ? null
        : item.startsAtUtc.toUtc().add(Duration(minutes: duration));
    final schedule = item.objectKind == DiscoverObjectKind.event
        ? ScenarioScheduleDraft(
            mode: ScenarioTimeMode.fixed,
            planned: ScenarioDatedPlannedTimeDraft(
              fixedStartAtUtc: item.startsAtUtc.toUtc(),
              fixedEndAtUtc: fixedEnd,
              startTimezoneId: _nullable(item.timezoneId),
              endTimezoneId: _nullable(item.timezoneId),
            ),
          )
        : null;
    return ScenarioIntakeCandidate(
      ref: ScenarioObjectRef(objectId: item.id, objectType: objectType),
      snapshot: ScenarioObjectSnapshotDraft(
        title: item.title,
        durationMinutes: duration,
        distanceM: item.publishedRoute?.distanceMeters,
        checkedAtUtc: checkedAtUtc,
      ),
      sourceStatus: ScenarioSourceStatus.ready,
      location: ScenarioIntakeLocationSnapshot(
        title: item.venueName.trim().isEmpty ? item.title : item.venueName,
        point: ScenarioGeoPointDraft(
          latitude: item.latitude,
          longitude: item.longitude,
        ),
        address: _nullable(item.addressLine),
        marketId: _nullable(item.marketCityId),
        timezoneId: _nullable(item.timezoneId),
        disclosure: ScenarioLocationDisclosure.public,
      ),
      schedule: schedule,
    );
  }

  static String? _nullable(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
