import '../../features/create/domain/entities/scenario_item_draft.dart';
import '../../features/create/domain/entities/scenario_object_intake.dart';
import '../../features/discover/application/state/scenario_intake_selection_state.dart';
import '../../features/discover/domain/entities/discover_item_entity.dart';
import '../../features/discover/domain/entities/event_occurrence.dart';
import '../../features/discover/domain/entities/published_event_discovery_entity.dart';

class DiscoverScenarioIntakeAdapter {
  const DiscoverScenarioIntakeAdapter();

  ScenarioIntakeIssue? supportIssue(DiscoverItemEntity item) {
    // A Find People request is not a stop: its point is only an approximate area.
    if (item.objectKind == DiscoverObjectKind.findPeople) {
      return ScenarioIntakeIssue.findPeopleNotSupported;
    }
    if (item.id.trim().isEmpty ||
        item.id.trim() != item.id ||
        item.title.trim().isEmpty) {
      return ScenarioIntakeIssue.missingIdentity;
    }
    if (!item.latitude.isFinite ||
        !item.longitude.isFinite ||
        item.latitude < -90 ||
        item.latitude > 90 ||
        item.longitude < -180 ||
        item.longitude > 180) {
      return ScenarioIntakeIssue.noLocation;
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
      throw const FormatException(
        'Scenario intake requires 1 to 20 items.', // l10n-ignore: developer error; the UI receives a code
      ); // l10n-ignore: developer exception
    }
    final refs = <ScenarioObjectRef>{};
    final candidates = <ScenarioIntakeCandidate>[];
    for (final item in items) {
      final issue = supportIssue(item);
      if (issue != null) throw FormatException(issue.name);
      final candidate = _toCandidate(item, checkedAtUtc.toUtc());
      if (!refs.add(candidate.ref)) {
        throw const FormatException(
          'Duplicate Scenario intake object.', // l10n-ignore: developer error; the UI receives a code
        ); // l10n-ignore: developer exception
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

  /// `DTL_EVT_01_EVENT_DETAILS_SLICE_SPEC.md` §4.3 — Event's own typed
  /// Scenario-intake mapping, built directly from
  /// [PublishedEventDiscoveryEntity], never by converting back to
  /// [DiscoverItemEntity]. Always single-item/`details` surface: Event
  /// Details has no multi-select tray, unlike Search/Map's
  /// [toIntent]/[items] path above.
  ScenarioObjectIntakeIntent toEventIntent({
    required PublishedEventDiscoveryEntity event,
    required String intentId,
    required String requesterId,
    required DateTime checkedAtUtc,
  }) {
    final ScenarioIntakeIssue? locationIssue = _eventLocationIssue(event);
    if (locationIssue != null) throw FormatException(locationIssue.name);
    return ScenarioObjectIntakeIntent(
      contractVersion: ScenarioObjectIntakeIntent.currentContractVersion,
      intentId: intentId,
      requesterId: requesterId,
      sourceSurface: ScenarioIntakeSourceSurface.details,
      candidates: <ScenarioIntakeCandidate>[
        _toEventCandidate(event, checkedAtUtc.toUtc()),
      ],
    );
  }

  ScenarioIntakeIssue? _eventLocationIssue(
    PublishedEventDiscoveryEntity event,
  ) {
    if (event.eventId.trim().isEmpty || event.title.trim().isEmpty) {
      return ScenarioIntakeIssue.missingIdentity;
    }
    if (!event.latitude.isFinite ||
        !event.longitude.isFinite ||
        event.latitude < -90 ||
        event.latitude > 90 ||
        event.longitude < -180 ||
        event.longitude > 180) {
      return ScenarioIntakeIssue.noLocation;
    }
    return null;
  }

  ScenarioIntakeCandidate _toEventCandidate(
    PublishedEventDiscoveryEntity event,
    DateTime checkedAtUtc,
  ) {
    // Occurrence-resolved start/end (`DTL-EVT-01` §2.2), never a bare
    // start/end pair — `PublishedEventDiscoveryEntity` has no such pair to
    // fall back to by construction.
    final EventOccurrence? occurrence = event.displayOccurrence;
    final DateTime? fixedStart = occurrence?.startAtUtc;
    final DateTime? fixedEnd = occurrence?.endAtUtc;
    return ScenarioIntakeCandidate(
      ref: ScenarioObjectRef(
        objectId: event.eventId,
        objectType: ScenarioCatalogObjectType.event,
      ),
      snapshot: ScenarioObjectSnapshotDraft(
        title: event.title,
        durationMinutes: event.durationMinutes,
        distanceM: null,
        checkedAtUtc: checkedAtUtc,
      ),
      sourceStatus: occurrence?.status == EventOccurrenceStatus.cancelled
          ? ScenarioSourceStatus.unavailable
          : ScenarioSourceStatus.ready,
      location: ScenarioIntakeLocationSnapshot(
        title: event.venueName.trim().isEmpty ? event.title : event.venueName,
        point: ScenarioGeoPointDraft(
          latitude: event.latitude,
          longitude: event.longitude,
        ),
        address: _nullable(event.addressLine),
        marketId: _nullable(event.marketCityId),
        timezoneId: _nullable(event.timezoneId),
        disclosure: ScenarioLocationDisclosure.public,
      ),
      schedule: fixedStart == null
          ? null
          : ScenarioScheduleDraft(
              mode: ScenarioTimeMode.fixed,
              planned: ScenarioDatedPlannedTimeDraft(
                fixedStartAtUtc: fixedStart,
                fixedEndAtUtc: fixedEnd,
                startTimezoneId: _nullable(event.timezoneId),
                endTimezoneId: _nullable(event.timezoneId),
              ),
            ),
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
      DiscoverObjectKind.findPeople => throw const FormatException(
        'A Find People request cannot be added to a Scenario.', // l10n-ignore: developer error
      ),
    };
    final duration = item.durationMinutes;
    final fixedEnd = duration == null
        ? null
        : item.startsAtUtc?.toUtc().add(Duration(minutes: duration));
    final schedule = item.objectKind == DiscoverObjectKind.event
        ? ScenarioScheduleDraft(
            mode: ScenarioTimeMode.fixed,
            planned: ScenarioDatedPlannedTimeDraft(
              fixedStartAtUtc: item.startsAtUtc!.toUtc(),
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
