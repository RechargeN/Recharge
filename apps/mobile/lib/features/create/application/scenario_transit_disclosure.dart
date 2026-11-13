import '../domain/entities/scenario_item_draft.dart';

enum ScenarioTransitDisclosureKind { manual, official }

enum ScenarioTransitDisclosureFreshness {
  current,
  stale,
  unknown,
  unavailable,
  notApplicable,
}

/// L4: a caution shown with a planned transport item; the UI turns it into
/// text. Planned/not-live wording follows Scenario spec v1.7.
enum ScenarioTransitWarning {
  manualNotVerified,
  plannedNotLive,
  freshnessCurrent,
  freshnessStale,
  freshnessUnknown,
  freshnessUnavailable,
  manualNoFreshness,
  limitations,
}

class ScenarioTransitDisclosure {
  const ScenarioTransitDisclosure({
    required this.kind,
    required this.freshness,
    required this.title,
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

  /// The service label from the source; null shows the localized fallback.
  final String? title;
  final String? providerLabel;
  final String? licenseLabel;
  final String? serviceDateLabel;
  final String? retrievedAtLabel;
  final String? digestLabel;
  final String? originLabel;
  final String? destinationLabel;
  final String? departureLabel;
  final String? arrivalLabel;
  final List<ScenarioTransitWarning> warnings;

  bool get isOfficial => kind == ScenarioTransitDisclosureKind.official;
}

class BuildScenarioTransitDisclosure {
  const BuildScenarioTransitDisclosure();

  ScenarioTransitDisclosure call(ScenarioPlannedTransportSourceDraft source) {
    final snapshot = source.scheduleSnapshot;
    final providerCode = snapshot?.providerCode?.trim();
    final isManual =
        snapshot == null ||
        providerCode == null ||
        providerCode.isEmpty ||
        providerCode == 'manual';
    final title =
        _nonEmpty(source.publicServiceLabel) ??
        _nonEmpty(source.carrierName) ??
        _nonEmpty(snapshot?.serviceLabel);
    if (isManual) {
      return ScenarioTransitDisclosure(
        kind: ScenarioTransitDisclosureKind.manual,
        freshness: ScenarioTransitDisclosureFreshness.notApplicable,
        title: title,
        serviceDateLabel: snapshot?.serviceDate?.iso8601,
        retrievedAtLabel: _utc(snapshot?.retrievedAtUtc),
        originLabel: _nonEmpty(snapshot?.originLabel),
        destinationLabel: _nonEmpty(snapshot?.destinationLabel),
        departureLabel: snapshot?.plannedDeparture?.hhmm,
        arrivalLabel: snapshot?.plannedArrival?.hhmm,
        warnings: const <ScenarioTransitWarning>[
          ScenarioTransitWarning.manualNotVerified,
          ScenarioTransitWarning.limitations,
        ],
      );
    }

    final providerLabel =
        _nonEmpty(snapshot.providerDisplayName) ?? providerCode;
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
      providerLabel: providerLabel,
      licenseLabel: _nonEmpty(snapshot.licenseName),
      serviceDateLabel: snapshot.serviceDate?.iso8601,
      retrievedAtLabel: _utc(snapshot.retrievedAtUtc),
      digestLabel: _nonEmpty(snapshot.feedSha256)?.toLowerCase(),
      originLabel: _nonEmpty(snapshot.originLabel),
      destinationLabel: _nonEmpty(snapshot.destinationLabel),
      departureLabel: snapshot.plannedDeparture?.hhmm,
      arrivalLabel: snapshot.plannedArrival?.hhmm,
      warnings: <ScenarioTransitWarning>[
        ScenarioTransitWarning.plannedNotLive,
        _freshnessWarning(freshness),
        ScenarioTransitWarning.limitations,
      ],
    );
  }

  ScenarioTransitDisclosureFreshness _freshness(
    ScenarioScheduleFreshness freshness,
  ) => switch (freshness) {
    ScenarioScheduleFreshness.current =>
      ScenarioTransitDisclosureFreshness.current,
    ScenarioScheduleFreshness.stale => ScenarioTransitDisclosureFreshness.stale,
    ScenarioScheduleFreshness.unknown =>
      ScenarioTransitDisclosureFreshness.unknown,
    ScenarioScheduleFreshness.notApplicable =>
      ScenarioTransitDisclosureFreshness.unavailable,
  };

  ScenarioTransitWarning _freshnessWarning(
    ScenarioTransitDisclosureFreshness freshness,
  ) => switch (freshness) {
    ScenarioTransitDisclosureFreshness.current =>
      ScenarioTransitWarning.freshnessCurrent,
    ScenarioTransitDisclosureFreshness.stale =>
      ScenarioTransitWarning.freshnessStale,
    ScenarioTransitDisclosureFreshness.unknown =>
      ScenarioTransitWarning.freshnessUnknown,
    ScenarioTransitDisclosureFreshness.unavailable =>
      ScenarioTransitWarning.freshnessUnavailable,
    ScenarioTransitDisclosureFreshness.notApplicable =>
      ScenarioTransitWarning.manualNoFreshness,
  };

  String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  String? _utc(DateTime? value) => value?.toUtc().toIso8601String();
}
