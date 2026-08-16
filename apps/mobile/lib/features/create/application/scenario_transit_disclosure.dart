import '../domain/entities/scenario_item_draft.dart';

enum ScenarioTransitDisclosureKind { manual, official }

enum ScenarioTransitDisclosureFreshness {
  current,
  stale,
  unknown,
  unavailable,
  notApplicable,
}

class ScenarioTransitDisclosure {
  const ScenarioTransitDisclosure({
    required this.kind,
    required this.freshness,
    required this.title,
    required this.statusLabel,
    required this.warnings,
    this.providerLabel,
    this.licenseLabel,
    this.serviceDateLabel,
    this.retrievedAtLabel,
    this.digestLabel,
    this.originLabel,
    this.destinationLabel,
    this.departureLabel,
    this.arrivalLabel,
  });

  final ScenarioTransitDisclosureKind kind;
  final ScenarioTransitDisclosureFreshness freshness;
  final String title;
  final String statusLabel;
  final String? providerLabel;
  final String? licenseLabel;
  final String? serviceDateLabel;
  final String? retrievedAtLabel;
  final String? digestLabel;
  final String? originLabel;
  final String? destinationLabel;
  final String? departureLabel;
  final String? arrivalLabel;
  final List<String> warnings;

  bool get isOfficial => kind == ScenarioTransitDisclosureKind.official;
}

class BuildScenarioTransitDisclosure {
  const BuildScenarioTransitDisclosure();

  static const String limitations =
      'Fare, tickets, seats, availability, delays and cancellations are '
      'unknown. Recheck with the operator before travel.';

  ScenarioTransitDisclosure call(ScenarioPlannedTransportSourceDraft source) {
    final snapshot = source.scheduleSnapshot;
    final providerCode = snapshot?.providerCode?.trim();
    final isManual = snapshot == null ||
        providerCode == null ||
        providerCode.isEmpty ||
        providerCode == 'manual';
    final title = _nonEmpty(source.publicServiceLabel) ??
        _nonEmpty(source.carrierName) ??
        _nonEmpty(snapshot?.serviceLabel) ??
        'Planned transport';
    if (isManual) {
      return ScenarioTransitDisclosure(
        kind: ScenarioTransitDisclosureKind.manual,
        freshness: ScenarioTransitDisclosureFreshness.notApplicable,
        title: title,
        statusLabel: 'Entered manually · not verified',
        serviceDateLabel: snapshot?.serviceDate?.iso8601,
        retrievedAtLabel: _utc(snapshot?.retrievedAtUtc),
        originLabel: _nonEmpty(snapshot?.originLabel),
        destinationLabel: _nonEmpty(snapshot?.destinationLabel),
        departureLabel: snapshot?.plannedDeparture?.hhmm,
        arrivalLabel: snapshot?.plannedArrival?.hhmm,
        warnings: const <String>[
          'Planned schedule · not live. Manual values are not verified '
              'against an operator timetable.',
          limitations,
        ],
      );
    }

    final providerLabel = _nonEmpty(snapshot.providerDisplayName) ??
        providerCode;
    final completeProvenance =
        _nonEmpty(snapshot.providerDisplayName) != null &&
        _nonEmpty(snapshot.licenseName) != null &&
        snapshot.serviceDate?.isValid == true &&
        snapshot.retrievedAtUtc != null &&
        RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(snapshot.feedSha256 ?? '');
    final freshness = completeProvenance
        ? _freshness(snapshot.freshness)
        : ScenarioTransitDisclosureFreshness.unavailable;
    return ScenarioTransitDisclosure(
      kind: ScenarioTransitDisclosureKind.official,
      freshness: freshness,
      title: title,
      statusLabel: _statusLabel(freshness),
      providerLabel: providerLabel,
      licenseLabel: _nonEmpty(snapshot.licenseName),
      serviceDateLabel: snapshot.serviceDate?.iso8601,
      retrievedAtLabel: _utc(snapshot.retrievedAtUtc),
      digestLabel: _nonEmpty(snapshot.feedSha256)?.toLowerCase(),
      originLabel: _nonEmpty(snapshot.originLabel),
      destinationLabel: _nonEmpty(snapshot.destinationLabel),
      departureLabel: snapshot.plannedDeparture?.hhmm,
      arrivalLabel: snapshot.plannedArrival?.hhmm,
      warnings: <String>[
        'Planned schedule · not live.',
        _freshnessWarning(freshness),
        limitations,
      ],
    );
  }

  ScenarioTransitDisclosureFreshness _freshness(
    ScenarioScheduleFreshness freshness,
  ) => switch (freshness) {
    ScenarioScheduleFreshness.current =>
      ScenarioTransitDisclosureFreshness.current,
    ScenarioScheduleFreshness.stale =>
      ScenarioTransitDisclosureFreshness.stale,
    ScenarioScheduleFreshness.unknown =>
      ScenarioTransitDisclosureFreshness.unknown,
    ScenarioScheduleFreshness.notApplicable =>
      ScenarioTransitDisclosureFreshness.unavailable,
  };

  String _statusLabel(ScenarioTransitDisclosureFreshness freshness) =>
      switch (freshness) {
        ScenarioTransitDisclosureFreshness.current =>
          'Feed snapshot was current when saved · not live',
        ScenarioTransitDisclosureFreshness.stale =>
          'Stale feed snapshot · recheck required',
        ScenarioTransitDisclosureFreshness.unknown =>
          'Feed freshness unknown · recheck required',
        ScenarioTransitDisclosureFreshness.unavailable =>
          'Provenance or feed unavailable · saved data retained',
        ScenarioTransitDisclosureFreshness.notApplicable =>
          'Entered manually · not verified',
      };

  String _freshnessWarning(ScenarioTransitDisclosureFreshness freshness) =>
      switch (freshness) {
        ScenarioTransitDisclosureFreshness.current =>
          'Current describes feed freshness when saved. It confirms neither '
              'service operation, delays nor punctuality.',
        ScenarioTransitDisclosureFreshness.stale =>
          'The saved feed snapshot is stale. Recheck the service before '
              'travel.',
        ScenarioTransitDisclosureFreshness.unknown =>
          'Feed freshness is unknown. Do not treat the saved times as '
              'confirmed.',
        ScenarioTransitDisclosureFreshness.unavailable =>
          'The saved item remains available, but its official provenance or '
              'feed cannot be verified.',
        ScenarioTransitDisclosureFreshness.notApplicable =>
          'Manual values have no official feed freshness.',
      };

  String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  String? _utc(DateTime? value) => value?.toUtc().toIso8601String();
}
